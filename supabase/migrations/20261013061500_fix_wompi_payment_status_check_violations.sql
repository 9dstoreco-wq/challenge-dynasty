-- F03 (Auditoria_Challenge_Dynasty_2026-10-12.md): apply_payment_result reused the
-- payment_records-level status verbatim when updating bookings.payment_status. A Wompi
-- VOIDED transaction normalizes to payment_records.status = 'cancelled' (a valid value
-- there -- see payment_records_status_check), but bookings_payment_status_check only allows
-- not_required/pending/paid/refunded/partially_refunded/failed. The old function's
-- `update bookings set payment_status = p_status` therefore raised a raw Postgres
-- CHECK-constraint violation for any VOIDED event, which the webhook's catch block did not
-- recognize as a permanent rejection -- it answered 500 and Wompi retried the same doomed
-- update for 24h, while the payment_records row (updated earlier in the same function, in a
-- separate statement) had already been written correctly.
--
-- Fix: a voided/cancelled payment ATTEMPT is not the same concept as a cancelled BOOKING
-- (bookings.status already has its own 'cancelled' value for that, set elsewhere). From the
-- booking's point of view a voided attempt simply means the payment did not go through, same
-- as a declined one -- so both 'failed' and 'cancelled' payment_records statuses now map to
-- bookings.payment_status = 'failed', a value already inside the existing CHECK constraint.
-- This does NOT touch the CHECK constraint itself or payment_records.status (both unchanged,
-- both already correct) -- only the one derived UPDATE inside this function.
--
-- NOT applied to production by this commit. Prepared on branch fix/wompi-webhook-reconciliation
-- per Mensaje_para_Claude.md P0 #2 ("no actives llaves reales, no despliegues ni apliques
-- migraciones a producción"). Apply via `supabase db push` (or the dashboard SQL editor)
-- only after the user reviews it, ideally first against an isolated/staging database.

create or replace function public.apply_payment_result(
  p_provider text,
  p_provider_payment_id text,
  p_provider_event_id text,
  p_booking_id uuid,
  p_amount numeric,
  p_currency_code text,
  p_status text,
  p_payer_profile_id uuid default null::uuid,
  p_raw_payload jsonb default '{}'::jsonb
)
returns payment_records
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_payment public.payment_records;
  v_booking public.bookings;
  v_existing public.payment_records;
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

    -- Refund states are terminal except for partial -> full refund.
    if v_existing.status = 'refunded'
       and p_status <> 'refunded' then
      raise exception 'PAYMENT_TERMINAL_STATE';
    end if;
    if v_existing.status = 'partially_refunded'
       and p_status not in ('partially_refunded','refunded') then
      raise exception 'PAYMENT_TERMINAL_STATE';
    end if;
    -- A cancelled payment cannot be resurrected under the same provider payment id.
    if v_existing.status = 'cancelled'
       and p_status <> 'cancelled' then
      raise exception 'PAYMENT_TERMINAL_STATE';
    end if;
    -- Paid cannot regress to a pre-payment/failure state.
    if v_existing.status = 'paid'
       and p_status in ('pending','authorized','failed','cancelled') then
      raise exception 'PAYMENT_STATE_REGRESSION';
    end if;

    -- apply_payment_result must never manufacture refund accounting.
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
    -- A new payment record cannot claim a refund state without refund accounting.
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
    update public.bookings
    set payment_status = 'paid', status = 'confirmed', updated_at = now()
    where id = p_booking_id
      and status = 'pending';
  elsif p_status in ('failed','cancelled') then
    -- F03 fix: both map to the booking-level 'failed', the only CHECK-compatible value for
    -- "this payment attempt did not go through" -- never 'cancelled', which does not exist
    -- in bookings_payment_status_check and would be confusable with a cancelled booking
    -- (bookings.status), a separate concept entirely.
    update public.bookings
    set payment_status = 'failed', updated_at = now()
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
