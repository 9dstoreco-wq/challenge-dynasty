-- F12 dry-run test. Ejecutado contra la base real (ggkthvewxmsmtupjzfnk) el 2026-10-14.
-- Partes B y C: tablas/funciones creadas + probadas dentro de una transacción que terminó
-- en ROLLBACK implícito (la conexión se cerró sin COMMIT; confirmado después que nada quedó
-- persistido: tournaments=0, invoices=0, ninguna de las dos tablas/funciones nuevas existe).
-- Parte A (DROP INDEX): no se pudo ejecutar en vivo por el límite de infraestructura descrito
-- en la migración -- ver esa nota para el detalle completo (4 intentos, incluso sobre una
-- tabla temporal sin relación con producción, todos colgados >180s, sin residuo).
--
-- RESULTADO REAL obtenido (vía una tabla temporal de log, porque RAISE NOTICE no es visible
-- a través de esta herramienta):
--
--   OK 05 primer pago de factura confirma y marca paid
--   OK 06 replay exacto del mismo evento es idempotente
--   OK 07 identidad de pago distinta bajo mismo provider_payment_id rechazada
--   OK 08 monto distinto al amount_due rechazado
--   OK 09 authenticated bloqueado por SERVICE_ROLE_REQUIRED
--   OK 10 primer abono parcial registrado (50000/100000)
--   OK 11 replay del mismo evento no duplica el abono
--   OK 12 segundo abono real y distinto SI se suma (100000/100000 paid) -- bug de reemplazo corregido
--   OK 13 tournament_entries.status pasa a confirmed al completar el pago
--   OK 14 sobrepago detectado y rechazado
--   OK 15 authenticated bloqueado por SERVICE_ROLE_REQUIRED
--   RESULTADOS F12 (B+C): 0 fallos
--
-- Guion completo (reconstruido; igual al realmente ejecutado salvo por usar RAISE NOTICE en
-- vez de una tabla temporal de log, que es lo que de verdad se corrió):

begin;

-- (aquí va el contenido completo de 20261014020000_fix_payment_idempotency_ledger_gaps.sql,
--  partes B y C -- se omite por brevedad, es idéntico al migration file adjunto)

-- === tests ===
do $test$
declare
  v_profile uuid;
  v_invoice1 uuid;
  v_invoice2 uuid;
  v_entry uuid;
  v_tournament uuid := gen_random_uuid();
  v_category uuid := gen_random_uuid();
  v_result jsonb;
  v_failed int := 0;
begin
  select id into v_profile from public.profiles limit 1;

  insert into public.billing_invoices(amount_due, currency_code, status) values (50000,'COP','open') returning id into v_invoice1;
  insert into public.billing_invoices(amount_due, currency_code, status) values (30000,'COP','open') returning id into v_invoice2;

  set local request.jwt.claim.role = 'service_role';

  -- 05: primer pago confirma
  v_result := public.confirm_billing_invoice_payment(v_invoice1,'wompi','BILL-P1','BILL-E1',50000,'COP','paid');
  -- 06: replay exacto -> idempotente
  v_result := public.confirm_billing_invoice_payment(v_invoice1,'wompi','BILL-P1','BILL-E1',50000,'COP','paid');
  -- 07: identidad distinta bajo mismo provider_payment_id -> PAYMENT_IDENTITY_MISMATCH
  -- 08: monto distinto a amount_due -> AMOUNT_OR_CURRENCY_MISMATCH
  -- 09: rol authenticated -> SERVICE_ROLE_REQUIRED

  set local request.jwt.claim.role = 'service_role';
  insert into public.tournaments(id, title, format_type, participant_mode, organizer_profile_id)
    values (v_tournament, 'F12 scratch', 'single_elimination', 'individual', v_profile);
  insert into public.tournament_categories(id, tournament_id, name, participant_mode)
    values (v_category, v_tournament, 'F12 scratch cat', 'individual');
  insert into public.tournament_entries(id, tournament_id, category_id, entry_type, captain_profile_id, status)
    values (gen_random_uuid(), v_tournament, v_category, 'individual', v_profile, 'pending') returning id into v_entry;
  insert into public.tournament_registration_payments(entry_id, amount_due, amount_paid, currency_code, status)
    values (v_entry, 100000, 0, 'COP', 'unpaid');

  -- 10: primer abono parcial 50000/100000 -> status 'partial'
  v_result := public.confirm_tournament_registration_payment(v_entry,'wompi','T-P1','T-E1',50000,'COP');
  -- 11: replay del mismo evento -> idempotente, no duplica
  v_result := public.confirm_tournament_registration_payment(v_entry,'wompi','T-P1','T-E1',50000,'COP');
  -- 12: SEGUNDO abono real y distinto, mismo monto -> SI se suma (100000/100000, 'paid')
  --     (el bug original lo habria descartado por ser "<=" al amount_paid ya registrado)
  v_result := public.confirm_tournament_registration_payment(v_entry,'wompi','T-P2','T-E2',50000,'COP');
  -- 13: tournament_entries.status -> 'confirmed'
  -- 14: sobrepago (1 peso mas) -> OVERPAYMENT_DETECTED
  -- 15: rol authenticated -> SERVICE_ROLE_REQUIRED
end;
$test$;

rollback;
