-- CORRECCION 2026-10-14 (encontrada al aplicar esta migracion, antes de que llegara a
-- produccion): esta migracion reescribe apply_payment_result() completa y, al hacerlo,
-- revertia sin querer el fix de F03 (ver 20261013061500_fix_wompi_payment_status_check_violations.sql)
-- -- volvia a escribir bookings.payment_status = p_status verbatim para 'cancelled', que
-- bookings_payment_status_check no admite. Corregido antes de aplicar: ver el bloque
-- failed/cancelled mas abajo, ahora mapea ambos a 'failed' igual que F03. Nunca se aplico
-- a produccion con el bug -- se detecto en la revision previa a aplicar.

-- F05 (Auditoria_Challenge_Dynasty_2026-10-12.md): "Alta: un pago puede quedar
-- pagado sin reserva confirmada". apply_payment_result() inserta/actualiza
-- payment_records a 'paid' siempre, pero solo confirmaba la reserva
-- (bookings.status -> 'confirmed', payment_status -> 'paid') cuando
-- bookings.status = 'pending'. Si para cuando llega la confirmacion de pago
-- (webhook de Wompi/ePayco) la reserva ya habia cambiado a 'expired'
-- (expire_pending_booking_offers, 15 min por defecto via booking_policies),
-- 'cancelled', 'completed', 'no_show' o 'waitlisted', ese UPDATE condicional
-- afectaba 0 filas -- en silencio, sin excepcion, sin alerta. Resultado: el
-- dinero queda registrado como paid en payment_records (correcto, la
-- pasarela si lo cobro), pero la reserva nunca se confirma -- y como
-- enforce_booking_capacity() solo cuenta reservas en status
-- pending/confirmed, el cupo ya pudo haberse liberado y dado a otra persona
-- (doble venta del mismo cupo, uno de los dos pago sin reserva real).
--
-- Remediacion pedida explicitamente por la auditoria: "revalidar
-- disponibilidad o devolver/conciliar; no reconfirmar automaticamente sin
-- capacidad". Implementado tal cual:
--
-- - Si la reserva esta 'pending' o ya 'confirmed' (p.ej. confirmada por un
--   administrador con el pago aun pendiente): comportamiento sin cambios,
--   se confirma/marca paid directo. Una reserva 'confirmed' ya ocupa su
--   cupo legitimamente (enforce_booking_capacity la cuenta), no necesita
--   revalidacion.
-- - Si la reserva esta en cualquier otro estado (expired, cancelled,
--   completed, no_show, waitlisted) cuando llega un pago 'paid': se
--   revalida la capacidad real del recurso para ese horario (misma logica
--   que enforce_booking_capacity, sumando otras reservas pending/confirmed
--   que se solapan). Si SIGUE habiendo cupo, se reconfirma la reserva
--   (status='confirmed', payment_status='paid') y se deja constancia en
--   bookings.metadata (late_payment_reconfirmed=true) de que fue un pago
--   tardio. Si NO hay cupo, la reserva NO se reconfirma -- se deja tal cual
--   estaba -- pero el pago se registra igual como 'paid' en
--   payment_records (el dinero no se pierde de vista) y se marca
--   needs_manual_reconciliation=true ahi, mas payment_needs_refund=true en
--   bookings.metadata, para que el equipo de finanzas pueda encontrar y
--   reembolsar/conciliar estos casos manualmente (no hay tabla de alertas
--   todavia -- ver F06/observabilidad, hallazgo separado -- por eso se usa
--   la columna metadata jsonb ya existente en ambas tablas, sin migracion
--   de esquema adicional).
--
-- Nunca reconfirma automaticamente sin capacidad real -- exactamente lo que
-- pide la auditoria. El resto de la funcion (validaciones de
-- service_role, idempotencia por provider_payment_id/provider_event_id,
-- transiciones de reembolso, failed/cancelled/refunded) queda igual --
-- no estaba en cuestion para F05.
--
-- NOTA (pendiente de verificar cuando el device bridge este disponible):
-- la auditoria tambien senala que "el resolver [de checkout, en
-- lib/dynasty/checkout-resolvers.ts] solo rechaza cancelled y paid; no
-- expired, completed u otros estados no cobrables" -- es decir, el
-- frontend podria intentar iniciar un pago NUEVO sobre una reserva que ya
-- no deberia aceptar pagos. Ese es un problema de la capa de iniciacion
-- (evitarlo de entrada), separado de este fix (que es la capa de
-- confirmacion/defensa en profundidad para cuando un pago igual llega,
-- por una condicion de carrera o un webhook fuera de orden). No se pudo
-- inspeccionar ese archivo en esta sesion por una desconexion del puente
-- al dispositivo del usuario -- queda pendiente revisarlo y, si hace
-- falta, ampliar el rechazo a expired/completed/no_show/waitlisted ahi
-- tambien.
--
-- Verificado en vivo contra la base real (ggkthvewxmsmtupjzfnk) dentro de
-- un bloque DO $$ ... RAISE EXCEPTION ... END $$ que revierte todo
-- (confirmado: 0 filas de prueba restantes, funcion en vivo sin cambios,
-- current_user vuelve a postgres). Ver
-- f05_late_payment_capacity_dryrun.test.sql. 6/6 checks OK:
-- reserva expired + capacidad disponible -> se reconfirma correctamente;
-- reserva expired + SIN capacidad (otra reserva confirmed ya ocupa el
-- cupo) -> NO se reconfirma, pago registrado igual y marcado para
-- reconciliacion manual; reserva pending normal -> sigue igual (sin
-- regresion); reserva ya confirmed con pago pendiente -> se marca paid
-- directo sin pasar por el chequeo de capacidad (sin regresion).
--
-- NOT applied to production by this commit. Prepared on branch
-- fix/wompi-webhook-reconciliation per Mensaje_para_Claude.md. Apply only
-- after the user reviews it.

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
      -- Normal path (pending -> first confirmation) or the booking is already
      -- confirmed and simply holds its capacity slot legitimately (confirmed
      -- bookings are counted by enforce_booking_capacity) -- no revalidation
      -- needed either way.
      update public.bookings
      set payment_status = 'paid', status = 'confirmed', updated_at = now()
      where id = p_booking_id;
    else
      -- F05: late/out-of-order payment on a booking that is no longer
      -- pending/confirmed (expired, cancelled, completed, no_show,
      -- waitlisted). Never auto-reconfirm without re-checking real capacity
      -- first -- same overlap logic as enforce_booking_capacity().
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
        -- No capacity (or resource vanished): do NOT reconfirm. The payment
        -- itself still gets recorded as paid above -- the money isn't lost --
        -- but both rows are flagged so finance/ops can find and
        -- refund/reconcile it manually.
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
    -- F03 fix (must be preserved here too, this function was re-created whole by F05):
    -- bookings_payment_status_check has no 'cancelled' value -- both a declined and a
    -- voided provider attempt map to the booking-level 'failed'. Writing p_status verbatim
    -- here would silently reintroduce the exact CHECK-constraint violation F03 fixed.
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
