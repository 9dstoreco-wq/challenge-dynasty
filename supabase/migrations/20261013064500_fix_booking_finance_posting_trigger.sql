-- F04 (Auditoria_Challenge_Dynasty_2026-10-12.md): critico, contabilizacion de reservas
-- defectuosa. Tres bugs reales en post_paid_booking_to_finance() / su trigger, confirmados
-- contra el esquema y las foreign keys en vivo (no inferidos):
--
-- 1. El unico trigger sobre payment_records es `AFTER UPDATE OF status` (confirmado via
--    pg_get_triggerdef), nunca `AFTER INSERT`. apply_payment_result inserta directamente
--    una fila ya en status='paid' cuando no existe un intento previo para ese
--    provider_payment_id -- ese primer pago nunca dispara el trigger en absoluto.
-- 2. post_paid_booking_to_finance() buscaba la organizacion con
--      `bookable_entities be ... where be.id = new.booking_id`
--    pero new.booking_id es payment_records.booking_id, que referencia bookings.id -- NO
--    bookable_entities.id (bookings.bookable_id es la columna que sí referencia
--    bookable_entities.id). Comparar un id de reserva contra un id de recurso reservable es
--    comparar dos espacios de ids distintos: el select virtualmente nunca encuentra fila,
--    v_org queda NULL y la funcion retorna sin contabilizar nada, en silencio, siempre.
-- 3. `insert into finance_transactions(...) on conflict do nothing` no protegia nada: la
--    tabla solo tenia PRIMARY KEY(id), con id generado nuevo en cada insert -- un conflicto
--    nunca puede ocurrir. Si el trigger llegara a dispararse dos veces para el mismo pago
--    (una vez corregido el bug 1, por ejemplo una fila que entra ya paid por INSERT y por
--    algun camino tambien dispara una UPDATE posterior) se duplicaria el asiento contable.
--
-- Tambien corrige un cuarto problema no señalado explicitamente por la auditoria: la
-- funcion solo buscaba finance_accounts/finance_categories por organization_id, por lo que
-- un dueño de recurso SIN organizacion (operador independiente, bookable_entities.owner_id
-- con una cuenta de finanzas propia via finance_accounts.profile_id) nunca recibia su
-- asiento tampoco -- no solo quien tiene organizacion.
--
-- Cadena correcta: bookings.bookable_id -> bookable_entities.id ->
-- bookable_entities.organization_resource_id -> organization_resources.organization_id
-- (cuando existe; confirmado NOT NULL en organization_resources). Si el recurso es
-- independiente (organization_resource_id NULL), se mantiene el heuristico anterior como
-- respaldo: una organizacion cuyo owner_id coincida con el profile dueño del recurso. Si
-- ninguna de las dos resuelve una organizacion, se intenta una cuenta de finanzas a nivel de
-- perfil (finance_accounts.profile_id) antes de desistir.
--
-- QUINTO bug, encontrado durante la verificacion con datos reales (dry-run contra la base
-- en vivo, 2026-10-13), NO presente en el primer borrador de este archivo: la version
-- original de este fix insertaba siempre organization_id (v_org) y nunca profile_id. La
-- tabla finance_transactions tiene `CHECK finance_transactions_check:
-- ((organization_id IS NOT NULL)::int + (profile_id IS NOT NULL)::int) = 1` (confirmado via
-- pg_get_constraintdef, no asumido) -- exige que EXACTAMENTE uno de los dos este presente.
-- Con v_org NULL (la ruta independiente que este mismo fix agrega), ese INSERT violaba la
-- constraint -- y como esto corre dentro de un trigger AFTER, la excepcion revierte TODA la
-- transaccion que lo contiene, incluyendo el UPDATE de payment_records que hizo
-- apply_payment_result. Es decir: la primera version de este fix habria roto permanentemente
-- (nunca silenciosamente -- con error duro) cada pago de un operador independiente, algo
-- peor que el bug original que pretendia arreglar. Corregido: profile_id se asigna cuando
-- v_org es NULL, organization_id en caso contrario -- nunca ambos, nunca ninguno.
--
-- NOT applied to production by this commit. Prepared on branch
-- fix/wompi-webhook-reconciliation per Mensaje_para_Claude.md ("no apliques migraciones a
-- producción"). Apply only after the user reviews it, ideally first against an
-- isolated/staging database with a real paid booking fixture (F10 tracks the lack of one).

-- Real idempotency key for one ledger entry per source record. A plain (non-partial) unique
-- index is enough: Postgres treats NULL as distinct from NULL, so rows from other sources
-- that leave source_type/source_id NULL are unaffected.
create unique index if not exists finance_transactions_source_unique
  on public.finance_transactions (source_type, source_id);

create or replace function public.post_paid_booking_to_finance()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_owner_id uuid;
  v_org_resource_id uuid;
  v_org uuid;
  v_account uuid;
  v_category uuid;
begin
  if tg_op = 'INSERT' then
    if new.status <> 'paid' then
      return new;
    end if;
  else
    if new.status <> 'paid' or old.status = 'paid' then
      return new;
    end if;
  end if;

  -- booking -> bookable_entity (bookings.bookable_id, not bookings.id / payment_records.booking_id
  -- compared directly against bookable_entities.id as the old version did).
  select be.owner_id, be.organization_resource_id
    into v_owner_id, v_org_resource_id
  from public.bookings b
  join public.bookable_entities be on be.id = b.bookable_id
  where b.id = new.booking_id;

  if not found then
    return new;
  end if;

  if v_org_resource_id is not null then
    select organization_id into v_org
    from public.organization_resources
    where id = v_org_resource_id;
  end if;

  if v_org is null and v_owner_id is not null then
    select o.id into v_org
    from public.organizations o
    where o.owner_id = v_owner_id
    order by o.created_at asc
    limit 1;
  end if;

  if v_org is not null then
    select id into v_account from public.finance_accounts
    where organization_id = v_org and currency_code = new.currency_code and is_active = true
    order by created_at asc limit 1;
    if v_account is not null then
      select id into v_category from public.finance_categories
      where organization_id = v_org and category_type = 'income' and is_active = true
      order by created_at asc limit 1;
    end if;
  end if;

  -- No organization at all (independent owner): fall back to their own profile-level
  -- finance account instead of silently dropping the entry.
  if v_account is null and v_owner_id is not null then
    select id into v_account from public.finance_accounts
    where profile_id = v_owner_id and currency_code = new.currency_code and is_active = true
    order by created_at asc limit 1;
    if v_account is not null then
      select id into v_category from public.finance_categories
      where profile_id = v_owner_id and category_type = 'income' and is_active = true
      order by created_at asc limit 1;
    end if;
  end if;

  if v_account is null then
    return new;
  end if;

  -- finance_transactions_check requires EXACTLY ONE of organization_id/profile_id to be
  -- set (confirmed live via pg_get_constraintdef: ((organization_id IS NOT NULL)::int +
  -- (profile_id IS NOT NULL)::int) = 1). The org-linked path above leaves v_org set and
  -- profile_id must stay NULL; the independent-owner fallback path leaves v_org NULL and
  -- profile_id must be v_owner_id instead, or every independent-operator payment raises a
  -- 23514 check violation here -- inside an AFTER trigger, that aborts the whole enclosing
  -- transaction, rolling back apply_payment_result's own payment_records update too. Found
  -- and fixed during dry-run verification (Supabase execute_sql, synthetic fixtures,
  -- 2026-10-13): the first draft of this function always passed organization_id and never
  -- profile_id, which failed this constraint for every independent-owner booking.
  insert into public.finance_transactions(
    organization_id, profile_id, account_id, category_id, transaction_type, amount, currency_code,
    occurred_at, description, source_type, source_id, status, metadata, created_by
  ) values (
    v_org, case when v_org is null then v_owner_id else null end, v_account, v_category,
    'income', new.amount, new.currency_code,
    coalesce(new.paid_at, now()), 'Booking payment', 'payment', new.id, 'posted',
    jsonb_build_object('booking_id', new.booking_id, 'provider', new.provider),
    new.payer_profile_id
  )
  on conflict (source_type, source_id) do nothing;

  return new;
end;
$function$;

drop trigger if exists trg_post_paid_booking_to_finance on public.payment_records;
create trigger trg_post_paid_booking_to_finance
  after insert or update of status on public.payment_records
  for each row execute function public.post_paid_booking_to_finance();
