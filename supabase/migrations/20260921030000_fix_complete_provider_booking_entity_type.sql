-- Fixes complete_provider_booking, found in a follow-up sweep that widened
-- the RPC contract audit beyond `status` columns to every other enum-like
-- CHECK-constrained column (2026-09-21).
--
-- EVIDENCE (live DB, project ggkthvewxmsmtupjzfnk):
--   bookable_entities_entity_type_check -> entity_type IN
--     ('resource','person','class','event','service')
--
-- complete_provider_booking looks up the provider behind a booking with:
--   select entity_id into v_provider from public.bookable_entities
--   where id=v_booking.bookable_id and entity_type='provider_service';
-- 'provider_service' is not, and can never be, a real bookable_entities.
-- entity_type value -- only 'service' is. This WHERE clause therefore never
-- matches any row, v_provider is always NULL, and the function always raises
-- 'Booking is not a provider service', regardless of the booking. Net effect:
-- a provider can never mark ANY booking as completed through this RPC. Fix:
-- compare against the real value, 'service'. No other logic changes.

CREATE OR REPLACE FUNCTION public.complete_provider_booking(p_booking_id uuid)
 RETURNS bookings
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_booking public.bookings; declare v_provider uuid; begin select * into v_booking from public.bookings where id=p_booking_id for update; if not found then raise exception 'Booking not found'; end if; select entity_id into v_provider from public.bookable_entities where id=v_booking.bookable_id and entity_type='service'; if v_provider is null then raise exception 'Booking is not a provider service'; end if; if not exists (select 1 from public.provider_services ps where ps.id=v_provider and ps.provider_id=auth.uid()) and not exists (select 1 from public.bookable_entities be join public.organizations o on o.owner_id=be.owner_id where be.id=v_booking.bookable_id and o.owner_id=auth.uid()) then raise exception 'Not authorized to complete this booking'; end if; if v_booking.status<>'confirmed' then raise exception 'Only confirmed bookings can be completed'; end if; update public.bookings set status='completed',updated_at=now(),metadata=metadata||jsonb_build_object('completed_at',now()) where id=p_booking_id returning * into v_booking; return v_booking; end; $function$;
