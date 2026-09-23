-- Shop staff management: lets a shop owner/manager see and manage who has staff
-- access to a location (add by email, change role, suspend/revoke), and lets the
-- first person to reach an ownerless location claim it as owner. shop_staff itself
-- has no insert/update policy for regular users -- these SECURITY DEFINER
-- functions are the only path to change it, each gated by has_shop_permission()
-- (or, for the very first claim, by the location having zero active staff).

create or replace function public.list_claimable_shop_locations()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', sl.id, 'name', sl.name, 'location_type', sl.location_type
  ) order by sl.created_at), '[]'::jsonb)
  from public.shop_locations sl
  where sl.status = 'active'
    and not exists (
      select 1 from public.shop_staff ss
      where ss.location_id = sl.id and ss.status = 'active'
    );
$$;

revoke all on function public.list_claimable_shop_locations() from public;
grant execute on function public.list_claimable_shop_locations() to authenticated;

create or replace function public.get_my_shop_staff_locations()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'location_id', ss.location_id,
    'location_name', sl.name,
    'location_type', sl.location_type,
    'my_role', ss.role
  ) order by sl.created_at), '[]'::jsonb)
  from public.shop_staff ss
  join public.shop_locations sl on sl.id = ss.location_id
  where ss.profile_id = auth.uid()
    and ss.status = 'active';
$$;

revoke all on function public.get_my_shop_staff_locations() from public;
grant execute on function public.get_my_shop_staff_locations() to authenticated;

create or replace function public.list_shop_staff(p_location_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_result jsonb;
begin
  if not public.has_shop_permission(p_location_id, 'manage_staff') then
    raise exception 'SHOP_PERMISSION_DENIED';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'profile_id', ss.profile_id,
    'role', ss.role,
    'status', ss.status,
    'display_name', p.display_name,
    'username', p.username,
    'created_at', ss.created_at
  ) order by ss.created_at), '[]'::jsonb)
  into v_result
  from public.shop_staff ss
  join public.profiles p on p.id = ss.profile_id
  where ss.location_id = p_location_id;

  return v_result;
end;
$$;

revoke all on function public.list_shop_staff(uuid) from public;
grant execute on function public.list_shop_staff(uuid) to authenticated;

create or replace function public.invite_shop_staff(p_location_id uuid, p_email text, p_role text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_target uuid;
  v_active_count int;
  v_final_role text;
begin
  if v_caller is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if p_role not in ('owner','manager','cashier','inventory') then
    raise exception 'INVALID_ROLE';
  end if;

  select id into v_target from auth.users where lower(email) = lower(p_email) limit 1;
  if v_target is null then
    raise exception 'PROFILE_NOT_FOUND';
  end if;

  select count(*) into v_active_count
  from public.shop_staff
  where location_id = p_location_id and status = 'active';

  if v_active_count = 0 then
    if v_target <> v_caller then
      raise exception 'SHOP_PERMISSION_DENIED';
    end if;
    v_final_role := 'owner';
  else
    if not public.has_shop_permission(p_location_id, 'manage_staff', v_caller) then
      raise exception 'SHOP_PERMISSION_DENIED';
    end if;
    v_final_role := p_role;

    if v_final_role <> 'owner' and exists (
      select 1 from public.shop_staff
      where location_id = p_location_id and profile_id = v_target and role = 'owner' and status = 'active'
    ) and (
      select count(*) from public.shop_staff
      where location_id = p_location_id and role = 'owner' and status = 'active'
    ) <= 1 then
      raise exception 'CANNOT_REMOVE_LAST_OWNER';
    end if;
  end if;

  insert into public.shop_staff (location_id, profile_id, role, status)
  values (p_location_id, v_target, v_final_role, 'active')
  on conflict (location_id, profile_id)
  do update set role = excluded.role, status = 'active', updated_at = now();

  return jsonb_build_object('profile_id', v_target, 'role', v_final_role);
end;
$$;

revoke all on function public.invite_shop_staff(uuid, text, text) from public;
grant execute on function public.invite_shop_staff(uuid, text, text) to authenticated;

create or replace function public.set_shop_staff_status(p_location_id uuid, p_profile_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_status not in ('active','suspended','revoked') then
    raise exception 'INVALID_STATUS';
  end if;
  if not public.has_shop_permission(p_location_id, 'manage_staff', auth.uid()) then
    raise exception 'SHOP_PERMISSION_DENIED';
  end if;
  if p_profile_id = auth.uid() and p_status <> 'active' then
    if (
      select count(*) from public.shop_staff
      where location_id = p_location_id and role = 'owner' and status = 'active'
    ) <= 1 then
      raise exception 'CANNOT_REMOVE_LAST_OWNER';
    end if;
  end if;

  update public.shop_staff
  set status = p_status, updated_at = now()
  where location_id = p_location_id and profile_id = p_profile_id;
end;
$$;

revoke all on function public.set_shop_staff_status(uuid, uuid, text) from public;
grant execute on function public.set_shop_staff_status(uuid, uuid, text) to authenticated;
