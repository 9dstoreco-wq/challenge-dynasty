-- F05 dry-run verification. SAFE: everything is undone by the RAISE EXCEPTION
-- at the end -- nothing persists in the database. Never commits. Verified
-- live against project ggkthvewxmsmtupjzfnk on 2026-10-13: after running,
-- confirmed 0 leftover rows and apply_payment_result's live definition
-- unchanged (current_user reverts to postgres).
--
-- Installs the fixed apply_payment_result() from
-- 20261013200000_fix_late_payment_capacity_revalidation.sql inside this same
-- transaction (CREATE OR REPLACE FUNCTION, like CREATE INDEX/ALTER TABLE, is
-- not affected by the CREATE/DROP TRIGGER hang documented in the F04
-- verification files) and exercises it against four scenarios with real
-- fixtures and a real capacity constraint:
--
--   A. Booking expired, but the resource still has free capacity for that
--      slot -> late payment SHOULD reconfirm it (status='confirmed'), and
--      gets flagged late_payment_reconfirmed=true so it's auditable.
--   B. Booking expired, AND another CONFIRMED booking already occupies the
--      resource's only slot for that overlapping time -> late payment must
--      NOT reconfirm (stays 'expired'). The payment itself is still
--      recorded as 'paid' (money isn't lost track of) but both the
--      payment_records row and the booking get flagged for manual
--      refund/reconciliation.
--   C. Regression: an ordinary 'pending' booking paid for the first time ->
--      confirms exactly as before the fix.
--   D. Regression: a booking already 'confirmed' with payment_status still
--      'pending' (e.g. an admin override) -> payment just marks it paid,
--      skipping the capacity re-check entirely (it already legitimately
--      holds its slot).
do $$
declare
  owner_a uuid; buyer uuid; other_buyer uuid; sp uuid;
  be1 uuid; be2 uuid;
  bk_expired uuid; bk_cancelled uuid; bk_blocking uuid; bk_pending uuid; bk_confirmed_unpaid uuid;
  v_status text; v_payment_status text; v_metadata jsonb;
  v_pay_status text; v_pay_metadata jsonb;
  res text := ''; fails int := 0;
begin
  select id into owner_a from public.profiles order by created_at limit 1;
  select id into buyer from public.profiles order by created_at offset 1 limit 1;
  select id into other_buyer from public.profiles order by created_at offset 2 limit 1;
  select id into sp from public.sports order by name limit 1;
  if owner_a is null or buyer is null or other_buyer is null or sp is null then
    raise exception 'se necesitan >=3 profiles y >=1 sport';
  end if;

  -- capacity 1 (case B: fully occupied) / capacity 2 (case A: room to spare)
  insert into public.bookable_entities(owner_id, entity_type, title, sport_id, capacity, price, currency_code, booking_mode, status)
    values (owner_a, 'resource', 'F05 test court cap1', sp, 1, 50000, 'COP', 'instant', 'active') returning id into be1;
  insert into public.bookable_entities(owner_id, entity_type, title, sport_id, capacity, price, currency_code, booking_mode, status)
    values (owner_a, 'resource', 'F05 test court cap2', sp, 2, 50000, 'COP', 'instant', 'active') returning id into be2;

  insert into public.bookings(bookable_id, booked_by, starts_at, ends_at, quantity, status, payment_status, amount, currency_code)
    values (be2, buyer, now() + interval '1 day', now() + interval '1 day 1 hour', 1, 'expired', 'pending', 50000, 'COP')
    returning id into bk_expired;

  insert into public.bookings(bookable_id, booked_by, starts_at, ends_at, quantity, status, payment_status, amount, currency_code)
    values (be1, buyer, now() + interval '2 days', now() + interval '2 days 1 hour', 1, 'expired', 'pending', 50000, 'COP')
    returning id into bk_cancelled;
  insert into public.bookings(bookable_id, booked_by, starts_at, ends_at, quantity, status, payment_status, amount, currency_code)
    values (be1, other_buyer, now() + interval '2 days', now() + interval '2 days 1 hour', 1, 'confirmed', 'paid', 50000, 'COP')
    returning id into bk_blocking;

  insert into public.bookings(bookable_id, booked_by, starts_at, ends_at, quantity, status, payment_status, amount, currency_code)
    values (be2, buyer, now() + interval '3 days', now() + interval '3 days 1 hour', 1, 'pending', 'pending', 50000, 'COP')
    returning id into bk_pending;

  insert into public.bookings(bookable_id, booked_by, starts_at, ends_at, quantity, status, payment_status, amount, currency_code)
    values (be2, buyer, now() + interval '4 days', now() + interval '4 days 1 hour', 1, 'confirmed', 'pending', 50000, 'COP')
    returning id into bk_confirmed_unpaid;

  execute $FN$
    CREATE OR REPLACE FUNCTION public.apply_payment_result(p_provider text, p_provider_payment_id text, p_provider_event_id text, p_booking_id uuid, p_amount numeric, p_currency_code text, p_status text, p_payer_profile_id uuid DEFAULT NULL::uuid, p_raw_payload jsonb DEFAULT '{}'::jsonb)
     RETURNS payment_records
     LANGUAGE plpgsql
     SECURITY DEFINER
     SET search_path TO 'public', 'pg_temp'
    AS $function$
    declare
      v_payment public.payment_records;
      v_booking public.bookings;
      v_existing public.payment_records;
      v_reserved integer;
      v_capacity integer;
    begin
      if auth.role() <> 'service_role' then
        raise exception 'SERVICE_ROLE_REQUIRED';
      end if;
      if p_provider is null or length(trim(p_provider)) = 0 then
        raise exception 'INVALID_PAYMENT_PROVIDER';
      end if;
      if p_provider_payment_id is null or length(trim(p_provider_payment_id)) = 0 then
        raise exception 'INVALID_PROVIDER_PAYMENT_ID';
      end if;
      if p_provider_event_id is null or length(trim(p_provider_event_id)) = 0 then
        raise exception 'INVALID_PROVIDER_EVENT_ID';
      end if;
      if p_status not in ('pending','authorized','paid','failed','refunded','partially_refunded','cancelled') then
        raise exception 'INVALID_PAYMENT_STATUS';
      end if;
      if p_amount is null or p_amount < 0 then
        raise exception 'INVALID_PAYMENT_AMOUNT';
      end if;

      select * into v_booking
      from public.bookings
      where id = p_booking_id
      for update;
      if not found then
        raise exception 'BOOKING_NOT_FOUND';
      end if;
      if p_amount <> v_booking.amount or p_currency_code <> v_booking.currency_code then
        raise exception 'PAYMENT_AMOUNT_OR_CURRENCY_MISMATCH';
      end if;

      select * into v_existing
      from public.payment_records
      where provider = p_provider
        and provider_payment_id = p_provider_payment_id
      for update;

      if found then
        if v_existing.booking_id <> p_booking_id
           or v_existing.amount <> p_amount
           or v_existing.currency_code <> p_currency_code then
          raise exception 'PAYMENT_IDENTITY_MISMATCH';
        end if;
        if v_existing.provider_event_id is not null
           and v_existing.provider_event_id <> p_provider_event_id then
          raise exception 'PAYMENT_EVENT_ID_MISMATCH';
        end if;
        if v_existing.status = 'refunded'
           and p_status <> 'refunded' then
          raise exception 'PAYMENT_TERMINAL_STATE';
        end if;
        if v_existing.status = 'partially_refunded'
           and p_status not in ('partially_refunded','refunded') then
          raise exception 'PAYMENT_TERMINAL_STATE';
        end if;
        if v_existing.status = 'cancelled'
           and p_status <> 'cancelled' then
          raise exception 'PAYMENT_TERMINAL_STATE';
        end if;
        if v_existing.status = 'paid'
           and p_status in ('pending','authorized','failed','cancelled') then
          raise exception 'PAYMENT_STATE_REGRESSION';
        end if;
        if p_status = 'refunded'
           and coalesce(v_existing.refunded_amount,0) <> v_existing.amount then
          raise exception 'REFUND_ACCOUNTING_MISMATCH';
        end if;
        if p_status = 'partially_refunded'
           and (coalesce(v_existing.refunded_amount,0) <= 0
                or coalesce(v_existing.refunded_amount,0) >= v_existing.amount) then
          raise exception 'REFUND_ACCOUNTING_MISMATCH';
        end if;

        update public.payment_records
        set provider_event_id = p_provider_event_id,
            status = p_status,
            payer_profile_id = coalesce(p_payer_profile_id, payer_profile_id),
            raw_payload = coalesce(p_raw_payload, '{}'::jsonb),
            paid_at = case when p_status = 'paid' then coalesce(paid_at, now()) else paid_at end,
            updated_at = now()
        where id = v_existing.id
        returning * into v_payment;
      else
        if exists (
          select 1 from public.payment_records
          where provider = p_provider
            and provider_event_id = p_provider_event_id
        ) then
          raise exception 'PAYMENT_EVENT_ALREADY_USED';
        end if;
        if p_status in ('refunded','partially_refunded') then
          raise exception 'REFUND_REQUIRES_REFUND_RECORD';
        end if;

        insert into public.payment_records(
          booking_id, provider, provider_payment_id, provider_event_id,
          amount, currency_code, status, payer_profile_id, raw_payload, paid_at
        ) values (
          p_booking_id, p_provider, p_provider_payment_id, p_provider_event_id,
          p_amount, p_currency_code, p_status, p_payer_profile_id,
          coalesce(p_raw_payload,'{}'::jsonb),
          case when p_status = 'paid' then now() else null end
        )
        returning * into v_payment;
      end if;

      if p_status = 'paid' then
        if v_booking.status in ('pending','confirmed') then
          update public.bookings
          set payment_status = 'paid', status = 'confirmed', updated_at = now()
          where id = p_booking_id;
        else
          select coalesce(sum(b2.quantity), 0) into v_reserved
          from public.bookings b2
          where b2.bookable_id = v_booking.bookable_id
            and b2.id <> v_booking.id
            and b2.status in ('pending','confirmed')
            and b2.starts_at < v_booking.ends_at
            and b2.ends_at > v_booking.starts_at;

          select capacity into v_capacity
          from public.bookable_entities
          where id = v_booking.bookable_id;

          if v_capacity is not null and v_reserved + v_booking.quantity <= v_capacity then
            update public.bookings
            set payment_status = 'paid', status = 'confirmed', updated_at = now(),
                metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
                  'late_payment_reconfirmed', true,
                  'late_payment_previous_status', v_booking.status,
                  'late_payment_reconfirmed_at', now()
                )
            where id = p_booking_id;
          else
            update public.payment_records
            set metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
              'needs_manual_reconciliation', true,
              'reconciliation_reason', 'booking_not_confirmable_no_capacity',
              'booking_status_at_payment', v_booking.status,
              'flagged_at', now()
            )
            where id = v_payment.id;

            update public.bookings
            set metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
              'payment_needs_refund', true,
              'payment_needs_refund_payment_id', v_payment.id,
              'payment_needs_refund_flagged_at', now()
            )
            where id = p_booking_id;
          end if;
        end if;
      elsif p_status in ('failed','cancelled') then
        update public.bookings
        set payment_status = p_status, updated_at = now()
        where id = p_booking_id
          and payment_status not in ('paid','refunded','partially_refunded');
      elsif p_status in ('refunded','partially_refunded') then
        update public.bookings
        set payment_status = p_status, updated_at = now()
        where id = p_booking_id;
      end if;

      return v_payment;
    end;
    $function$;
  $FN$;

  execute format('set local role service_role');
  execute format('set local request.jwt.claims = %L', json_build_object('role','service_role')::text);

  -- A: expired + capacity available -> reconfirm
  perform public.apply_payment_result('wompi','f05-a-pay','f05-a-evt', bk_expired, 50000,'COP','paid');
  select status, metadata into v_status, v_metadata from public.bookings where id = bk_expired;
  if v_status = 'confirmed' and (v_metadata->>'late_payment_reconfirmed')::boolean is true then
    res := res || E'OK    01 expired + capacidad disponible -> se reconfirma (confirmed) y queda marcada late_payment_reconfirmed\n';
  else
    res := res || format(E'FALLO 01: status=%s metadata=%s\n', v_status, v_metadata); fails:=fails+1;
  end if;
  select status into v_pay_status from public.payment_records where booking_id=bk_expired;
  if v_pay_status = 'paid' then
    res := res || E'OK    02 payment_records queda en paid para el pago tardio reconfirmado\n';
  else
    res := res || format(E'FALLO 02: payment_records.status=%s\n', v_pay_status); fails:=fails+1;
  end if;

  -- B: expired + SIN capacidad (ya ocupada por otra reserva confirmed) -> NO reconfirmar
  perform public.apply_payment_result('wompi','f05-b-pay','f05-b-evt', bk_cancelled, 50000,'COP','paid');
  select status, metadata into v_status, v_metadata from public.bookings where id = bk_cancelled;
  if v_status = 'expired' and (v_metadata->>'payment_needs_refund')::boolean is true then
    res := res || E'OK    03 expired + SIN capacidad -> NO se reconfirma (sigue expired), queda marcada payment_needs_refund\n';
  else
    res := res || format(E'FALLO 03: status=%s metadata=%s\n', v_status, v_metadata); fails:=fails+1;
  end if;
  select status, metadata into v_pay_status, v_pay_metadata from public.payment_records where booking_id=bk_cancelled;
  if v_pay_status = 'paid' and (v_pay_metadata->>'needs_manual_reconciliation')::boolean is true then
    res := res || E'OK    04 el pago SI se registra como paid (el dinero no se pierde) y queda marcado needs_manual_reconciliation\n';
  else
    res := res || format(E'FALLO 04: payment_records.status=%s metadata=%s\n', v_pay_status, v_pay_metadata); fails:=fails+1;
  end if;

  -- C (regresion): pending normal -> sin cambios
  perform public.apply_payment_result('wompi','f05-c-pay','f05-c-evt', bk_pending, 50000,'COP','paid');
  select status into v_status from public.bookings where id = bk_pending;
  if v_status = 'confirmed' then
    res := res || E'OK    05 reserva pending normal sigue confirmandose igual que antes (sin regresion)\n';
  else
    fails:=fails+1; res := res || format(E'FALLO 05: status=%s\n', v_status);
  end if;

  -- D (regresion): ya confirmed con pago pendiente -> solo marca paid, sin chequeo de capacidad
  perform public.apply_payment_result('wompi','f05-d-pay','f05-d-evt', bk_confirmed_unpaid, 50000,'COP','paid');
  select status, payment_status into v_status, v_payment_status from public.bookings where id = bk_confirmed_unpaid;
  if v_status = 'confirmed' and v_payment_status = 'paid' then
    res := res || E'OK    06 reserva ya confirmed con pago pendiente -> se marca paid directo, sin chequeo de capacidad\n';
  else
    fails:=fails+1; res := res || format(E'FALLO 06: status=%s payment_status=%s\n', v_status, v_payment_status);
  end if;

  raise exception E'RESULTADOS F05 (% fallos)\n%', fails, res;
end $$;
