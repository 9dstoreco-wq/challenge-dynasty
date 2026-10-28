-- BUG ENCONTRADO EN AUDITORIA DE NAV (2026-10-28): TournamentPendingPaymentsPanel.tsx (el boton
-- "Marcar como pagado en efectivo" que usa el organizador) llamaba directo a
-- confirm_tournament_registration_payment desde el navegador. Esa funcion exige
-- auth.role() = 'service_role' (raise exception 'SERVICE_ROLE_REQUIRED') y ni siquiera tiene
-- GRANT EXECUTE para 'authenticated' -- esta reservada para los webhooks reales de pago
-- (Wompi), nunca para el navegador. Resultado: el boton fallaba el 100% de las veces, para
-- cualquier organizador. Verificado en vivo: pg_get_functiondef mostro el check de
-- service_role, y information_schema.routine_privileges confirmo que 'authenticated' no tiene
-- EXECUTE sobre esa funcion.
--
-- Esta nueva funcion es la version segura para que el propio ORGANIZADOR del torneo marque un
-- pago en efectivo, sin necesitar la llave de service_role. Reusa la misma logica de sumar
-- eventos de pago (para quedar compatible con confirm_tournament_registration_payment, que
-- tambien puede seguir sumando pagos reales del proveedor despues) pero:
--   - verifica que quien llama sea el organizador del torneo (organizer_profile_id = auth.uid()
--     o dueno de la organizacion organizadora), no service_role.
--   - genera su propio provider_payment_id/provider_event_id en el servidor (no confia en los
--     que mande el cliente), con provider='manual_cash', para que cada click cree un evento
--     nuevo e idempotente no se pueda falsificar desde el navegador.
--
-- Probado en BEGIN/ROLLBACK contra produccion: organizador real marca pago en efectivo exitoso
-- (status pasa a 'paid' cuando el monto cubre amount_due), rechazo FORBIDDEN para quien no es
-- organizador de ese torneo, rechazo ENTRY_NOT_FOUND para un entry_id inexistente, y rechazo
-- OVERPAYMENT_DETECTED si el monto excede lo que falta por pagar.

create or replace function public.mark_tournament_entry_paid_manually(p_entry_id uuid, p_amount numeric)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_entry public.tournament_entries;
  v_payment public.tournament_registration_payments;
  v_total numeric;
  v_is_organizer boolean;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'INVALID_PAYMENT_AMOUNT'; end if;

  select * into v_entry from public.tournament_entries where id = p_entry_id for update;
  if not found then raise exception 'ENTRY_NOT_FOUND'; end if;

  select exists (
    select 1 from public.tournaments t
    where t.id = v_entry.tournament_id
      and (
        t.organizer_profile_id = auth.uid()
        or (t.organization_id is not null and exists (
          select 1 from public.organizations o where o.id = t.organization_id and o.owner_id = auth.uid()
        ))
      )
  ) into v_is_organizer;
  if not v_is_organizer then raise exception 'FORBIDDEN'; end if;

  select * into v_payment from public.tournament_registration_payments where entry_id = p_entry_id for update;
  if not found then raise exception 'REGISTRATION_PAYMENT_NOT_FOUND'; end if;

  insert into public.tournament_registration_payment_events(
    entry_id, provider, provider_payment_id, provider_event_id, amount, currency_code
  ) values (
    p_entry_id, 'manual_cash', gen_random_uuid()::text, gen_random_uuid()::text, p_amount, v_payment.currency_code
  );

  select coalesce(sum(amount), 0) into v_total
  from public.tournament_registration_payment_events
  where entry_id = p_entry_id;

  if v_total > v_payment.amount_due then raise exception 'OVERPAYMENT_DETECTED'; end if;

  update public.tournament_registration_payments
    set amount_paid = v_total,
        status = case when v_total >= amount_due then 'paid' when v_total > 0 then 'partial' else 'unpaid' end,
        paid_at = case when v_total >= amount_due then coalesce(paid_at, now()) else paid_at end,
        updated_at = now()
    where id = v_payment.id
    returning * into v_payment;

  if v_payment.status = 'paid' and not exists (
    select 1 from public.tournament_entry_members where entry_id = p_entry_id and status <> 'confirmed'
  ) then
    update public.tournament_entries
      set status = case when status in ('pending', 'waitlisted') then 'confirmed' else status end,
          updated_at = now()
      where id = p_entry_id;
  end if;

  return jsonb_build_object('ok', true, 'entry_id', p_entry_id, 'status', v_payment.status, 'amount_paid', v_payment.amount_paid);
end;
$function$;

grant execute on function public.mark_tournament_entry_paid_manually(uuid, numeric) to authenticated;
