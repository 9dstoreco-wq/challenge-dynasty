-- Membresia de Club y Plan de Organizador de Torneos: cobro real por Wompi (COP) + bloqueo
-- de herramientas de club (canchas/academia/finanzas) y de creacion de torneos sin plan activo.
--
-- Precios de lista (USD, solo informativos, mostrados en /business) confirmados por Luis:
--   Membresia de Club:        29.99 USD/mes   | 341.89 USD/anio (5% descuento anual)
--   Organizador de Torneos:   19.99 USD/mes   | 227.89 USD/anio (5% descuento anual)
-- Wompi (unico proveedor de pago vivo) solo liquida en COP para esta cuenta de comercio
-- (ver lib/dynasty/wompi.ts, UNSUPPORTED_CURRENCY) -- por eso cada plan ademas lleva un monto
-- FIJO en COP (charge_amount_cop), confirmado por Luis, que es lo que realmente se cobra (no
-- se usa conversion de FX en vivo):
--   club_membership_monthly:      99.900 COP
--   club_membership_yearly:    1.138.860 COP
--   tournament_organizer_monthly: 66.900 COP
--   tournament_organizer_yearly:  762.660 COP

-- 1) billing_plans: monto fijo de cobro en COP + familia de plan (agrupa mensual/anual del
--    mismo producto para que compartan un solo ciclo de suscripcion al renovar/cambiar).
alter table public.billing_plans
  add column if not exists charge_amount_cop numeric check (charge_amount_cop >= 0),
  add column if not exists plan_family text;

update public.billing_plans set charge_amount_cop = 99900, plan_family = 'club_membership'
  where code = 'club_membership_monthly';
update public.billing_plans set charge_amount_cop = 1138860, plan_family = 'club_membership'
  where code = 'club_membership_yearly';
update public.billing_plans set charge_amount_cop = 66900, plan_family = 'tournament_organizer'
  where code = 'tournament_organizer_monthly';
update public.billing_plans set charge_amount_cop = 762660, plan_family = 'tournament_organizer'
  where code = 'tournament_organizer_yearly';

-- 2) Verificacion de acceso: hay membresia de club / plan de organizador activo.
create or replace function public.organization_has_active_club_membership(p_organization_id uuid)
 returns boolean
 language sql
 stable security definer
 set search_path to 'public', 'pg_temp'
as $function$
  select exists (
    select 1 from public.billing_subscriptions bs
    join public.billing_plans bp on bp.id = bs.plan_id
    where bp.plan_family = 'club_membership'
      and bs.organization_id = p_organization_id
      and bs.status = 'active'
      and bs.current_period_end >= now()
  );
$function$;

create or replace function public.profile_or_org_has_active_organizer_plan(p_profile_id uuid, p_organization_id uuid DEFAULT NULL::uuid)
 returns boolean
 language sql
 stable security definer
 set search_path to 'public', 'pg_temp'
as $function$
  select exists (
    select 1 from public.billing_subscriptions bs
    join public.billing_plans bp on bp.id = bs.plan_id
    where bp.plan_family = 'tournament_organizer'
      and bs.status = 'active'
      and bs.current_period_end >= now()
      and (
        (p_profile_id is not null and bs.profile_id = p_profile_id)
        or (p_organization_id is not null and bs.organization_id = p_organization_id)
      )
  );
$function$;

-- 3) Creacion de la factura de suscripcion. Idempotente contra reintentos: anula cualquier
--    factura 'open' previa del mismo sujeto/familia de plan antes de crear la nueva.
create or replace function public.create_subscription_invoice(p_plan_code text, p_organization_id uuid DEFAULT NULL::uuid)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_plan public.billing_plans%rowtype;
  v_profile_id uuid;
  v_org_id uuid;
  v_invoice_id uuid;
  v_redirect text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;

  select * into v_plan from public.billing_plans where code = p_plan_code and is_active = true;
  if not found then raise exception 'PLAN_NOT_FOUND'; end if;
  if v_plan.charge_amount_cop is null then raise exception 'PLAN_NOT_CHARGEABLE'; end if;

  if v_plan.audience_type = 'organization' then
    if p_organization_id is null then raise exception 'ORGANIZATION_REQUIRED'; end if;
    if not exists (select 1 from public.organizations where id = p_organization_id and owner_id = auth.uid()) then
      raise exception 'FORBIDDEN';
    end if;
    v_org_id := p_organization_id;
    v_profile_id := null;
  elsif p_organization_id is not null then
    if not exists (select 1 from public.organizations where id = p_organization_id and owner_id = auth.uid()) then
      raise exception 'FORBIDDEN';
    end if;
    v_org_id := p_organization_id;
    v_profile_id := null;
  else
    v_org_id := null;
    v_profile_id := auth.uid();
  end if;

  update public.billing_invoices bi
    set status = 'void', updated_at = now()
    where bi.status = 'open'
      and (bi.metadata->>'plan_family') = v_plan.plan_family
      and (
        (v_org_id is not null and bi.organization_id = v_org_id)
        or (v_profile_id is not null and bi.profile_id = v_profile_id)
      );

  v_redirect := case
    when v_org_id is not null and v_plan.plan_family = 'club_membership' then '/clubs/manage/' || v_org_id::text
    else '/competitions/organize'
  end;

  insert into public.billing_invoices(profile_id, organization_id, amount_due, currency_code, status, due_at, metadata)
  values (
    v_profile_id, v_org_id, v_plan.charge_amount_cop, 'COP', 'open', now(),
    jsonb_build_object(
      'plan_id', v_plan.id, 'plan_code', v_plan.code, 'plan_family', v_plan.plan_family,
      'billing_interval', v_plan.billing_interval, 'redirect_path', v_redirect
    )
  ) returning id into v_invoice_id;

  return v_invoice_id;
end;
$function$;

grant execute on function public.create_subscription_invoice(text, uuid) to authenticated;
grant execute on function public.organization_has_active_club_membership(uuid) to authenticated;
grant execute on function public.profile_or_org_has_active_organizer_plan(uuid, uuid) to authenticated;

-- 4) Activar/extender la suscripcion cuando una factura queda 'paid' (el webhook de Wompi solo
--    marca la factura pagada via confirm_billing_invoice_payment; este trigger es lo que de
--    verdad activa el acceso). Si ya hay una suscripcion activa y vigente, EXTIENDE desde su
--    current_period_end actual (no desde "ahora") para no perder tiempo ya pagado al renovar
--    o cambiar de mensual a anual a mitad de ciclo.
create or replace function public.activate_subscription_from_paid_invoice()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_plan_id uuid;
  v_plan_family text;
  v_billing_interval text;
  v_period interval;
  v_sub public.billing_subscriptions%rowtype;
  v_found boolean := false;
  v_new_start timestamptz;
  v_new_end timestamptz;
  v_sub_id uuid;
begin
  if NEW.status <> 'paid' or OLD.status = 'paid' then
    return NEW;
  end if;
  if NEW.metadata is null or not (NEW.metadata ? 'plan_id') then
    return NEW;
  end if;

  v_plan_id := (NEW.metadata->>'plan_id')::uuid;
  v_plan_family := NEW.metadata->>'plan_family';
  v_billing_interval := NEW.metadata->>'billing_interval';
  v_period := case v_billing_interval when 'yearly' then interval '1 year' else interval '1 month' end;

  select bs.* into v_sub
  from public.billing_subscriptions bs
  join public.billing_plans bp on bp.id = bs.plan_id
  where bp.plan_family = v_plan_family
    and (
      (NEW.organization_id is not null and bs.organization_id = NEW.organization_id)
      or (NEW.profile_id is not null and bs.profile_id = NEW.profile_id)
    )
  order by bs.created_at desc
  limit 1
  for update;
  v_found := FOUND;

  if v_found and v_sub.status = 'active' and v_sub.current_period_end > now() then
    v_new_start := v_sub.current_period_start;
    v_new_end := v_sub.current_period_end + v_period;
  else
    v_new_start := now();
    v_new_end := now() + v_period;
  end if;

  if v_found then
    update public.billing_subscriptions
      set plan_id = v_plan_id, status = 'active', current_period_start = v_new_start,
          current_period_end = v_new_end, cancel_at_period_end = false, provider_name = 'wompi',
          updated_at = now()
      where id = v_sub.id
      returning id into v_sub_id;
  else
    insert into public.billing_subscriptions(plan_id, profile_id, organization_id, status, current_period_start, current_period_end, provider_name)
    values (v_plan_id, NEW.profile_id, NEW.organization_id, 'active', v_new_start, v_new_end, 'wompi')
    returning id into v_sub_id;
  end if;

  update public.billing_invoices set subscription_id = v_sub_id where id = NEW.id;

  return NEW;
end;
$function$;

drop trigger if exists trg_activate_subscription_from_paid_invoice on public.billing_invoices;
create trigger trg_activate_subscription_from_paid_invoice
  after update of status on public.billing_invoices
  for each row execute function public.activate_subscription_from_paid_invoice();

-- 5) Bloquear la creacion de canchas/recursos y academia (coach/clases) sin membresia de club
--    activa. Deliberado: solo se bloquea CREAR, no ver/activar-desactivar lo que ya existia.
create or replace function public.create_organization_resource(p_organization_id uuid, p_location_id uuid, p_sport_id uuid, p_name text, p_resource_type text, p_capacity integer DEFAULT 1, p_metadata jsonb DEFAULT '{}'::jsonb)
 returns organization_resources
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare v_resource public.organization_resources;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  perform public.require_organization_permission(p_organization_id,'manage_resources');
  if not public.organization_has_active_club_membership(p_organization_id) then raise exception 'CLUB_MEMBERSHIP_REQUIRED'; end if;
  if not exists (select 1 from public.organizations where id=p_organization_id) then raise exception 'ORGANIZATION_NOT_FOUND'; end if;
  if p_location_id is not null and not exists (select 1 from public.organization_locations where id=p_location_id and organization_id=p_organization_id) then raise exception 'LOCATION_NOT_IN_ORGANIZATION'; end if;
  if p_sport_id is not null and not exists (select 1 from public.sports where id=p_sport_id) then raise exception 'SPORT_NOT_FOUND'; end if;
  if trim(coalesce(p_name,''))='' or length(trim(p_name))>160 then raise exception 'INVALID_RESOURCE_NAME'; end if;
  if trim(coalesce(p_resource_type,''))='' or length(trim(p_resource_type))>64 then raise exception 'INVALID_RESOURCE_TYPE'; end if;
  if p_capacity<=0 or p_capacity>10000 then raise exception 'INVALID_CAPACITY'; end if;
  insert into public.organization_resources(organization_id,location_id,sport_id,name,resource_type,capacity,metadata)
  values(p_organization_id,p_location_id,p_sport_id,trim(p_name),trim(p_resource_type),p_capacity,coalesce(p_metadata,'{}'::jsonb))
  returning * into v_resource;
  return v_resource;
end;
$function$;

create or replace function public.add_coach_to_academy(p_organization_id uuid, p_provider_id uuid, p_relationship_type text DEFAULT 'employee'::text, p_can_create_own_services boolean DEFAULT false)
 returns uuid
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
  if not public.organization_has_active_club_membership(p_organization_id) then raise exception 'CLUB_MEMBERSHIP_REQUIRED'; end if;

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

create or replace function public.create_academy_class(p_organization_id uuid, p_provider_id uuid, p_title text, p_description text, p_service_mode text, p_duration_minutes integer, p_capacity integer, p_price numeric, p_currency_code text DEFAULT 'COP'::text)
 returns table(service_id uuid, bookable_id uuid)
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
  if not public.organization_has_active_club_membership(p_organization_id) then raise exception 'CLUB_MEMBERSHIP_REQUIRED'; end if;

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

-- 6) Bloquear la creacion de torneos sin plan de organizador activo. TournamentCreateForm.tsx
--    inserta directo en `tournaments` desde el cliente, sin RPC -- esta politica RLS es el
--    unico punto de control posible para esa via.
alter policy "tournament organizer insert" on public.tournaments
  with check (
    (
      organizer_profile_id = (select auth.uid())
      or organization_id in (select organizations.id from public.organizations where organizations.owner_id = (select auth.uid()))
    )
    and public.profile_or_org_has_active_organizer_plan((select auth.uid()), organization_id)
  );
