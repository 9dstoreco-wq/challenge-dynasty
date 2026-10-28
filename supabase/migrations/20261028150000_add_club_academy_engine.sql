-- Academia del club: permite que un club tenga sus propios profesores (coaches ya
-- registrados en la plataforma) y sus propias clases, con el cobro y la contabilidad
-- centralizados en el club (no en el profesor individual).
--
-- Tested via BEGIN...ROLLBACK against production (happy path, idempotent re-add,
-- permission denial for non-owners, "coach not in academy" guard, and finance
-- attribution of a simulated paid booking) before being applied for real.

-- Pre-existing bug fix (found while building this feature, which it blocks entirely):
-- provider_can_operate_service compared p_provider_id (provider_profiles.id, a surrogate
-- key) directly against auth.uid() -- different id spaces, so the check was never true for
-- any authenticated caller (confirmed live: provider_profiles had 0 rows in production, so
-- this path was never exercised). Fixed to compare the PROVIDER'S OWN profile_id (joined
-- from provider_profiles) against auth.uid(), and additionally allow the organization's
-- owner to act on behalf of a coach they manage (needed here: the club, not the coach,
-- creates the academy class).
create or replace function public.provider_can_operate_service(p_provider_id uuid, p_organization_id uuid)
 returns boolean
 language sql
 stable
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
  select exists (
    select 1
    from public.provider_organization_relationships r
    join public.provider_profiles pp on pp.id = r.provider_id
    left join public.organizations o on o.id = r.organization_id
    where r.provider_id = p_provider_id
      and r.organization_id = p_organization_id
      and r.status = 'active'
      and (r.ends_on is null or r.ends_on >= current_date)
      and (
        auth.role() = 'service_role'
        or pp.profile_id = auth.uid()
        or o.owner_id = auth.uid()
      )
  );
$function$;

create or replace function public.search_academy_coaches(p_query text default null)
 returns table (provider_id uuid, profile_id uuid, display_name text, username text, headline text)
 language sql
 stable
 set search_path to 'public', 'pg_temp'
as $function$
  select pp.id, pp.profile_id, p.display_name, p.username, pp.headline
  from public.provider_profiles pp
  join public.profiles p on p.id = pp.profile_id
  where pp.status = 'active' and pp.provider_type = 'coach'
    and (
      p_query is null or trim(p_query) = ''
      or p.display_name ilike '%'||trim(p_query)||'%'
      or p.username ilike '%'||trim(p_query)||'%'
    )
  order by p.display_name
  limit 20;
$function$;
grant execute on function public.search_academy_coaches(text) to authenticated;

create or replace function public.add_coach_to_academy(
  p_organization_id uuid,
  p_provider_id uuid,
  p_relationship_type text default 'employee',
  p_can_create_own_services boolean default false
) returns uuid
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_org public.organizations%rowtype;
  v_provider public.provider_profiles%rowtype;
  v_membership_id uuid;
  v_rel_id uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_relationship_type not in ('employee','contractor','partner','guest') then
    raise exception 'invalid_relationship_type';
  end if;

  select * into v_org from public.organizations where id = p_organization_id;
  if not found then raise exception 'organization_not_found'; end if;
  perform public.require_organization_permission(p_organization_id, 'manage_staff');

  select * into v_provider from public.provider_profiles
   where id = p_provider_id and status = 'active' and provider_type = 'coach';
  if not found then raise exception 'coach_not_found'; end if;

  if v_provider.profile_id = v_org.owner_id then raise exception 'cannot_add_owner_as_coach'; end if;

  select id into v_membership_id from public.organization_memberships
   where organization_id = p_organization_id and profile_id = v_provider.profile_id;
  if v_membership_id is null then
    insert into public.organization_memberships(organization_id, profile_id, membership_type, status, joined_at)
    values (p_organization_id, v_provider.profile_id, 'coach', 'active', now())
    returning id into v_membership_id;
  else
    update public.organization_memberships
      set membership_type = 'coach', status = 'active'
      where id = v_membership_id;
  end if;

  select id into v_rel_id from public.provider_organization_relationships
   where organization_id = p_organization_id and provider_id = p_provider_id;
  if v_rel_id is null then
    insert into public.provider_organization_relationships(
      provider_id, organization_id, membership_id, relationship_type, status,
      can_manage_own_schedule, can_create_own_services, can_view_own_students, can_manage_own_bookings
    ) values (
      p_provider_id, p_organization_id, v_membership_id, p_relationship_type, 'active',
      true, coalesce(p_can_create_own_services,false), true, true
    ) returning id into v_rel_id;
  else
    update public.provider_organization_relationships
      set status = 'active', relationship_type = p_relationship_type,
          can_create_own_services = coalesce(p_can_create_own_services,false),
          membership_id = v_membership_id
      where id = v_rel_id;
  end if;

  return v_rel_id;
end;
$function$;
grant execute on function public.add_coach_to_academy(uuid, uuid, text, boolean) to authenticated;

create or replace function public.create_academy_class(
  p_organization_id uuid,
  p_provider_id uuid,
  p_title text,
  p_description text,
  p_service_mode text,
  p_duration_minutes int,
  p_capacity int,
  p_price numeric,
  p_currency_code text default 'COP'
) returns table (service_id uuid, bookable_id uuid)
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_org public.organizations%rowtype;
  v_service_id uuid;
  v_resource_id uuid;
  v_bookable_id uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into v_org from public.organizations where id = p_organization_id;
  if not found then raise exception 'organization_not_found'; end if;
  perform public.require_organization_permission(p_organization_id, 'manage_resources');

  if not exists (
    select 1 from public.provider_organization_relationships
    where organization_id = p_organization_id and provider_id = p_provider_id and status = 'active'
  ) then
    raise exception 'coach_not_in_academy';
  end if;

  if trim(coalesce(p_title,'')) = '' or length(trim(p_title)) > 160 then raise exception 'invalid_title'; end if;
  if p_service_mode not in ('in_person','online','hybrid') then raise exception 'invalid_service_mode'; end if;
  if coalesce(p_capacity,0) <= 0 then raise exception 'invalid_capacity'; end if;
  if p_duration_minutes is not null and p_duration_minutes <= 0 then raise exception 'invalid_duration'; end if;
  if coalesce(p_price,-1) < 0 then raise exception 'invalid_price'; end if;

  insert into public.provider_services(
    provider_id, organization_id, title, description, service_mode,
    ownership_type, operational_owner_type, payment_owner_type,
    duration_minutes, capacity, price, currency_code, status
  ) values (
    p_provider_id, p_organization_id, trim(p_title), p_description, p_service_mode,
    'organization', 'provider', 'organization',
    p_duration_minutes, p_capacity, p_price, coalesce(p_currency_code,'COP'), 'active'
  ) returning id into v_service_id;

  insert into public.organization_resources(organization_id, name, resource_type, capacity, metadata)
  values (p_organization_id, trim(p_title), 'clase', p_capacity, '{}'::jsonb)
  returning id into v_resource_id;

  insert into public.bookable_entities(
    owner_id, entity_type, entity_id, organization_resource_id, title,
    duration_minutes, capacity, price, currency_code, booking_mode, status
  ) values (
    v_org.owner_id, 'class', v_service_id, v_resource_id, trim(p_title),
    p_duration_minutes, p_capacity, p_price, coalesce(p_currency_code,'COP'), 'instant', 'active'
  ) returning id into v_bookable_id;

  insert into public.provider_service_booking_links(provider_service_id, bookable_id, provider_id, organization_id)
  values (v_service_id, v_bookable_id, p_provider_id, p_organization_id);

  return query select v_service_id, v_bookable_id;
end;
$function$;
grant execute on function public.create_academy_class(uuid, uuid, text, text, text, int, int, numeric, text) to authenticated;

create or replace function public.set_academy_class_status(p_service_id uuid, p_status text)
 returns void
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_service public.provider_services%rowtype;
  v_bookable_status text;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_status not in ('active','paused','archived') then raise exception 'invalid_status'; end if;

  select * into v_service from public.provider_services where id = p_service_id;
  if not found then raise exception 'class_not_found'; end if;
  if v_service.organization_id is null then raise exception 'not_an_academy_class'; end if;
  perform public.require_organization_permission(v_service.organization_id, 'manage_resources');

  update public.provider_services set status = p_status, updated_at = now() where id = p_service_id;

  v_bookable_status := case when p_status = 'active' then 'active' else 'paused' end;
  update public.bookable_entities be
    set status = v_bookable_status, updated_at = now()
    from public.provider_service_booking_links l
    where l.provider_service_id = p_service_id and be.id = l.bookable_id;

  update public.organization_resources r
    set status = case when p_status = 'active' then 'active' else 'inactive' end, updated_at = now()
    from public.provider_service_booking_links l, public.bookable_entities be
    where l.provider_service_id = p_service_id and be.id = l.bookable_id and r.id = be.organization_resource_id;
end;
$function$;
grant execute on function public.set_academy_class_status(uuid, text) to authenticated;
