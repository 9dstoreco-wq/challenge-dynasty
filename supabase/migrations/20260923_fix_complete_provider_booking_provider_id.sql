-- complete_provider_booking still can't authorize a coach, even after the
-- 2026-09-21 entity_type fix (20260921030000). It checks:
--   exists (select 1 from provider_services ps where ps.id=v_provider and ps.provider_id=auth.uid())
-- but provider_services.provider_id stores a provider_profiles.id (see the
-- RLS policies on provider_services: "provider_id IN (select pp.id from
-- provider_profiles pp where pp.profile_id = auth.uid())"), never a raw
-- profiles.id. provider_profiles.id defaults to gen_random_uuid() and is
-- never equal to profile_id, so `ps.provider_id = auth.uid()` can never be
-- true -- an independent coach could never complete a single booking
-- through this RPC, regardless of the earlier fix. Same bug family as the
-- prior migration, one level deeper in the same function.

CREATE OR REPLACE FUNCTION public.complete_provider_booking(p_booking_id uuid)
 RETURNS bookings
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_booking public.bookings;
  v_provider uuid;
begin
  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;

  select entity_id into v_provider from public.bookable_entities where id=v_booking.bookable_id and entity_type='service';
  if v_provider is null then raise exception 'Booking is not a provider service'; end if;

  if not exists (
    select 1 from public.provider_services ps
    join public.provider_profiles pp on pp.id = ps.provider_id
    where ps.id = v_provider and pp.profile_id = auth.uid()
  ) and not exists (
    select 1 from public.bookable_entities be
    join public.organizations o on o.owner_id = be.owner_id
    where be.id = v_booking.bookable_id and o.owner_id = auth.uid()
  ) then
    raise exception 'Not authorized to complete this booking';
  end if;

  if v_booking.status <> 'confirmed' then raise exception 'Only confirmed bookings can be completed'; end if;

  update public.bookings
  set status='completed', updated_at=now(), metadata=metadata||jsonb_build_object('completed_at',now())
  where id=p_booking_id
  returning * into v_booking;

  return v_booking;
end;
$function$;
