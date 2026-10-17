-- F12 (Auditoria_Challenge_Dynasty_2026-10-12.md): idempotencia financiera incompleta por dominio.
--
-- ESTADO: ESCRITA, NO APLICADA (2026-10-14). Partes B y C verificadas en vivo contra la base
-- real (ggkthvewxmsmtupjzfnk) dentro de transacciones que terminaron en ROLLBACK (o que nunca
-- llegaron a persistir por el límite de infraestructura descrito abajo) -- ver
-- f12_payment_ledger_dryrun.test.sql. La parte A (DROP INDEX) no pudo verificarse en vivo por
-- ese mismo límite de infraestructura, pero es correcta por inspección directa del esquema y
-- del código de apply_payment_result (ver abajo). No aplicada a producción.
--
-- Tres defectos confirmados, uno por dominio de pago que todavía no tenía el patrón de ledger
-- por evento que ya usan reservas (payment_records, vía apply_payment_result) y marketplace
-- (marketplace_order_payments, vía confirm_marketplace_payment):
--
-- A) RESERVAS (payment_records): además de los índices únicos COMPUESTOS correctos
--    (provider, provider_payment_id) y (provider, provider_event_id) -- los que de verdad usa
--    apply_payment_result en su WHERE -- la tabla tenía DOS índices únicos GLOBALES
--    redundantes, uno sobre provider_payment_id solo y otro sobre provider_event_id solo
--    (confirmado vía pg_indexes). Un ID de transacción de un proveedor (p.ej. Wompi "100") que
--    coincida por casualidad con el de otro proveedor (p.ej. ePayco "100") haría que el
--    segundo pago, legítimo, fallara con una violación de unicidad -- aunque el índice
--    compuesto correcto sí los distinguiría. Se eliminan los dos índices globales; los
--    compuestos, que son los que protegen de verdad, quedan intactos.
--
--    LIMITE DE INFRAESTRUCTURA: intentar este DROP INDEX contra la base real (incluso dentro
--    de BEGIN/ROLLBACK, e incluso sobre una tabla temporal de prueba sin relación con
--    producción) se quedó colgado >180s de forma reproducible (4 intentos). Confirmado por
--    pg_stat_activity/pg_locks que no queda ninguna sesión bloqueada ni ningún lock huérfano
--    tras cada intento -- el servidor aborta limpio, solo tarda más de 180s en reportarlo a
--    esta sesión. Es la MISMA familia de flakiness ya documentada para CREATE/DROP TRIGGER
--    (F04) y para cierto CREATE FUNCTION (F08) -- pero esta vez se aisló con más precisión:
--    el patrón común es específicamente DROP de un objeto (índice, función, trigger), nunca
--    CREATE -- CREATE TABLE, CREATE INDEX y CREATE [OR REPLACE] FUNCTION con la misma
--    complejidad funcionaron sin problema en esta misma sesión. Dado que esto es un DROP
--    INDEX de una sola línea sobre dos índices ya identificados con precisión, y que el
--    comportamiento de un índice único de una sola columna es estándar de Postgres (no
--    depende de ningún dato ni lógica de este proyecto), no se necesita una reproducción en
--    vivo para confirmar que el fix es correcto -- pero sí falta ejecutarlo contra producción
--    (tú, desde el editor SQL de Supabase, o reintentando este mismo DROP INDEX más tarde si
--    el problema de infraestructura se resuelve).
--
-- B) FACTURACION (billing_invoices): el webhook (wompi-webhook y epayco-webhook, función
--    "billing" en ambos) actualiza la factura directamente con un UPDATE condicionado a
--    status<>'paid' -- protege una regresión básica, pero no existe ningún registro de los
--    eventos de pago individuales: ni unicidad por proveedor/transacción, ni proveedor/evento,
--    ni rastro de intentos fallidos o duplicados para reconciliar. Se agrega
--    billing_invoice_payments (ledger por evento, mismo patrón que marketplace_order_payments)
--    y confirm_billing_invoice_payment (RPC SECURITY DEFINER, solo service_role) que los
--    webhooks deben llamar en vez del UPDATE directo. Verificado en vivo: primer pago confirma
--    la factura, el replay exacto del mismo evento es idempotente, una identidad de pago
--    distinta bajo el mismo provider_payment_id se rechaza, un monto distinto a amount_due se
--    rechaza, y un rol distinto de service_role no puede ejecutar la función.
--
--    De paso, se confirma y corrige una variante del bug ya diagnosticado en F03: el bloque
--    "billing" de epayco-webhook escribe status='failed' para un pago rechazado, pero
--    billing_invoices_status_check (confirmado en pg_constraint) solo permite
--    draft/open/paid/void/uncollectible/refunded -- "failed" no es un valor válido y la
--    actualización reventaría con un error crudo de Postgres. wompi-webhook ya fue corregido
--    para esto en F03 (comentario explícito en el archivo); epayco-webhook tenía la misma
--    falla sin corregir en una segunda copia del código. No se ha podido disparar en
--    producción porque ePayco está desplegado pero inalcanzable desde la UI (ver F11).
--
-- C) TORNEOS (tournament_registration_payments): el hallazgo más grave de los tres, confirmado
--    leyendo la función en vivo y el resolver del checkout. confirm_tournament_registration_
--    payment(p_entry_id, p_amount_paid) no recibía ninguna identidad de proveedor/transacción/
--    evento -- solo un monto, que además REEMPLAZABA amount_paid en vez de sumarlo. Combinado
--    con lib/dynasty/checkout-resolvers.ts (resolveTournament), que siempre cotizaba el
--    amount_due COMPLETO sin restar amount_paid: un jugador que pagara dos abonos reales y
--    distintos de $50.000 cada uno para una inscripción de $100.000 (dos transacciones
--    Wompi/ePayco distintas, dos eventos de webhook distintos) terminaría así: primer evento,
--    amount_paid pasa de 0 a 50000. Segundo evento, como 50000 <= amount_paid (50000), la
--    función lo trataba como "ya procesado" (idempotente) y lo descartaba EN SILENCIO -- el
--    segundo abono real, con dinero real cobrado, nunca se reflejaba en amount_paid. Y en la
--    otra dirección: como el checkout siempre cotizaba el amount_due completo (no el saldo
--    restante), si el jugador intentaba pagar otra vez desde la propia app después de un abono
--    parcial, se le cobraba el monto COMPLETO de nuevo -- sobrecobrando la inscripción.
--    Ninguno de los dos caminos es un ataque: son el comportamiento normal de un pago parcial
--    retrasado, hoy sin soporte real.
--
--    Se agrega tournament_registration_payment_events (ledger por evento, idéntico patrón) y
--    se reescribe confirm_tournament_registration_payment para recibir identidad de proveedor,
--    deduplicar por evento, y recalcular amount_paid como la SUMA de los eventos distintos ya
--    registrados (nunca un reemplazo). Se agrega también el chequeo SERVICE_ROLE_REQUIRED que
--    ya tienen apply_payment_result/confirm_marketplace_payment/confirm_shop_order_payment y
--    que a esta función le faltaba (no es explotable hoy -- EXECUTE no está otorgado a
--    anon/authenticated, confirmado en information_schema.routine_privileges -- pero es la
--    misma defensa en profundidad que ya tienen sus hermanas).
--
--    Verificado en vivo: primer abono parcial (50000/100000) se registra como 'partial';
--    el replay exacto del mismo evento no duplica el abono; un SEGUNDO abono real y distinto
--    de igual monto SÍ se suma (100000/100000, pasa a 'paid') -- el bug de reemplazo queda
--    corregido; tournament_entries.status pasa a 'confirmed' al completar el pago; un
--    sobrepago se detecta y se rechaza explícitamente (OVERPAYMENT_DETECTED) en vez de
--    aceptarse en silencio; y un rol distinto de service_role no puede ejecutar la función.
--
-- No se tocan reglas de negocio no mencionadas por la auditoría (qué hacer con un pago vencido,
-- política de reembolsos, etc.) -- eso sigue siendo decisión de Luis.

-- ========== A) Reservas: fuera los índices únicos globales redundantes/peligrosos ==========
drop index if exists public.payment_records_provider_payment_uidx;
drop index if exists public.payment_records_provider_event_uidx;

-- ========== B) Facturación: ledger por evento + RPC de confirmación idempotente ==========
create table if not exists public.billing_invoice_payments (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.billing_invoices(id) on delete cascade,
  provider text not null,
  provider_payment_id text not null,
  provider_event_id text not null,
  amount numeric not null check (amount >= 0),
  currency_code text not null,
  status text not null check (status in ('paid','failed')),
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint billing_invoice_payments_provider_payment_key unique (provider, provider_payment_id),
  constraint billing_invoice_payments_provider_event_key unique (provider, provider_event_id)
);
create index if not exists idx_billing_invoice_payments_invoice on public.billing_invoice_payments(invoice_id);

create or replace function public.confirm_billing_invoice_payment(
  p_invoice_id uuid,
  p_provider text,
  p_provider_payment_id text,
  p_provider_event_id text,
  p_amount numeric,
  p_currency_code text,
  p_status text,
  p_raw_payload jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
declare
  v_invoice public.billing_invoices;
  v_existing public.billing_invoice_payments;
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
  if p_status not in ('paid','failed') then
    raise exception 'INVALID_PAYMENT_STATUS';
  end if;
  if p_amount is null or p_amount < 0 then
    raise exception 'INVALID_PAYMENT_AMOUNT';
  end if;

  select * into v_invoice from public.billing_invoices where id = p_invoice_id for update;
  if not found then
    raise exception 'INVOICE_NOT_FOUND';
  end if;

  select * into v_existing from public.billing_invoice_payments
    where provider = p_provider and provider_payment_id = p_provider_payment_id
    for update;
  if found then
    if v_existing.invoice_id <> p_invoice_id
       or v_existing.amount <> p_amount
       or v_existing.currency_code <> p_currency_code then
      raise exception 'PAYMENT_IDENTITY_MISMATCH';
    end if;
    return jsonb_build_object('ok', true, 'idempotent', true, 'invoice_id', p_invoice_id, 'status', v_invoice.status);
  end if;

  if exists (
    select 1 from public.billing_invoice_payments
    where provider = p_provider and provider_event_id = p_provider_event_id
  ) then
    raise exception 'PAYMENT_EVENT_ALREADY_USED';
  end if;

  insert into public.billing_invoice_payments(
    invoice_id, provider, provider_payment_id, provider_event_id, amount, currency_code, status, raw_payload
  ) values (
    p_invoice_id, p_provider, p_provider_payment_id, p_provider_event_id, p_amount, p_currency_code, p_status,
    coalesce(p_raw_payload, '{}'::jsonb)
  );

  if v_invoice.status = 'paid' then
    -- ya estaba pagada (otro evento/proveedor la cerró primero); el evento queda en el ledger
    -- para reconciliación, pero no se toca la factura.
    return jsonb_build_object('ok', true, 'idempotent', true, 'invoice_id', p_invoice_id, 'status', 'paid');
  end if;

  if p_status = 'paid' then
    if round(p_amount, 2) <> round(v_invoice.amount_due, 2)
       or upper(coalesce(p_currency_code, '')) <> upper(coalesce(v_invoice.currency_code, '')) then
      raise exception 'AMOUNT_OR_CURRENCY_MISMATCH';
    end if;
    update public.billing_invoices
      set status = 'paid',
          amount_paid = p_amount,
          provider_name = p_provider,
          provider_invoice_reference = p_provider_payment_id,
          paid_at = now(),
          updated_at = now()
      where id = p_invoice_id;
  end if;
  -- un evento 'failed' nunca cambia el estado/amount_paid de la factura -- billing_invoices no
  -- tiene un estado "failed" (ver F03); solo queda registrado en el ledger para reconciliar.

  return jsonb_build_object(
    'ok', true, 'idempotent', false, 'invoice_id', p_invoice_id,
    'status', case when p_status = 'paid' then 'paid' else v_invoice.status end
  );
end;
$fn$;

revoke all on function public.confirm_billing_invoice_payment(uuid,text,text,text,numeric,text,text,jsonb) from public, anon, authenticated;
grant execute on function public.confirm_billing_invoice_payment(uuid,text,text,text,numeric,text,text,jsonb) to service_role;

-- ========== C) Torneos: ledger por evento + RPC reescrita para sumar, no reemplazar ==========
drop function if exists public.confirm_tournament_registration_payment(uuid, numeric);

create table if not exists public.tournament_registration_payment_events (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references public.tournament_entries(id) on delete cascade,
  provider text not null,
  provider_payment_id text not null,
  provider_event_id text not null,
  amount numeric not null check (amount > 0),
  currency_code text not null,
  created_at timestamptz not null default now(),
  constraint trpe_provider_payment_key unique (provider, provider_payment_id),
  constraint trpe_provider_event_key unique (provider, provider_event_id)
);
create index if not exists idx_trpe_entry on public.tournament_registration_payment_events(entry_id);

create or replace function public.confirm_tournament_registration_payment(
  p_entry_id uuid,
  p_provider text,
  p_provider_payment_id text,
  p_provider_event_id text,
  p_amount numeric,
  p_currency_code text default 'COP'
) returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
declare
  v_entry public.tournament_entries;
  v_payment public.tournament_registration_payments;
  v_existing public.tournament_registration_payment_events;
  v_total numeric;
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
  if p_amount is null or p_amount <= 0 then
    raise exception 'INVALID_PAYMENT_AMOUNT';
  end if;

  select * into v_entry from public.tournament_entries where id = p_entry_id for update;
  if not found then
    raise exception 'ENTRY_NOT_FOUND';
  end if;
  select * into v_payment from public.tournament_registration_payments where entry_id = p_entry_id for update;
  if not found then
    raise exception 'REGISTRATION_PAYMENT_NOT_FOUND';
  end if;

  select * into v_existing from public.tournament_registration_payment_events
    where provider = p_provider and provider_payment_id = p_provider_payment_id
    for update;
  if found then
    if v_existing.entry_id <> p_entry_id
       or v_existing.amount <> p_amount
       or v_existing.currency_code <> p_currency_code then
      raise exception 'PAYMENT_IDENTITY_MISMATCH';
    end if;
    return jsonb_build_object('ok', true, 'idempotent', true, 'entry_id', p_entry_id, 'status', v_payment.status, 'amount_paid', v_payment.amount_paid);
  end if;
  if exists (
    select 1 from public.tournament_registration_payment_events
    where provider = p_provider and provider_event_id = p_provider_event_id
  ) then
    raise exception 'PAYMENT_EVENT_ALREADY_USED';
  end if;

  insert into public.tournament_registration_payment_events(
    entry_id, provider, provider_payment_id, provider_event_id, amount, currency_code
  ) values (
    p_entry_id, p_provider, p_provider_payment_id, p_provider_event_id, p_amount, p_currency_code
  );

  select coalesce(sum(amount), 0) into v_total
  from public.tournament_registration_payment_events
  where entry_id = p_entry_id;

  if v_total > v_payment.amount_due then
    raise exception 'OVERPAYMENT_DETECTED';
  end if;

  update public.tournament_registration_payments
    set amount_paid = v_total,
        status = case when v_total >= amount_due then 'paid' when v_total > 0 then 'partial' else 'unpaid' end,
        paid_at = case when v_total >= amount_due then coalesce(paid_at, now()) else paid_at end,
        updated_at = now()
    where id = v_payment.id
    returning * into v_payment;

  if v_payment.status = 'paid' then
    update public.tournament_entries
      set status = case when status in ('pending','waitlisted') then 'confirmed' else status end,
          updated_at = now()
      where id = p_entry_id;
  end if;

  return jsonb_build_object('ok', true, 'idempotent', false, 'entry_id', p_entry_id, 'status', v_payment.status, 'amount_paid', v_payment.amount_paid);
end;
$fn$;

revoke all on function public.confirm_tournament_registration_payment(uuid,text,text,text,numeric,text) from public, anon, authenticated;
grant execute on function public.confirm_tournament_registration_payment(uuid,text,text,text,numeric,text) to service_role;
