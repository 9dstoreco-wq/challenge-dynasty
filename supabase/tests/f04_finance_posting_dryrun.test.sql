-- F04 dry-run verification, v2. SAFE: everything is undone by the RAISE EXCEPTION at the
-- end -- nothing persists in the database. Never commits.
--
-- v2 deliberately does NOT run CREATE TRIGGER / DROP TRIGGER (unlike v1). While verifying
-- this fix live against project ggkthvewxmsmtupjzfnk on 2026-10-13, every CREATE TRIGGER or
-- DROP TRIGGER statement hung past the tool's 180s timeout -- reproduced 3 times, including
-- on a brand-new disposable scratch table unrelated to this fix, so it is a project-level
-- infrastructure issue (unidentified: no blocking row in pg_locks/pg_stat_activity was ever
-- caught, and every other DDL type -- CREATE/REPLACE FUNCTION, CREATE INDEX, ALTER TABLE ADD
-- COLUMN -- completed in under a second). Every attempt still rolled back cleanly (confirmed
-- via catalog checks afterward: no leftover rows, live trigger/function unchanged), so no
-- data was ever at risk, but it means CREATE TRIGGER/DROP TRIGGER on this project cannot be
-- verified this way -- `mcp__Supabase__create_branch` (an isolated preview DB, the actual
-- right tool for this) was also attempted and itself timed out twice without creating a
-- branch. The trigger's own firing semantics (AFTER INSERT OR UPDATE OF status) are ordinary,
-- unexceptional Postgres and match the pattern already used elsewhere in this schema (see
-- booking_conflict_guard, BEFORE INSERT OR UPDATE); what this script verifies instead, by
-- direct SELECT/INSERT, is everything that was actually in question: the corrected
-- bookable_id->organization_resource_id join, the independent-owner profile-level fallback,
-- and the real INSERT into finance_transactions under its live CHECK/unique constraints.
--
-- This second pass caught a real, previously-undetected bug in the v1 migration: the fixed
-- function always supplied organization_id and never profile_id. finance_transactions has
-- CHECK finance_transactions_check: ((organization_id IS NOT NULL)::int +
-- (profile_id IS NOT NULL)::int) = 1 -- confirmed live via pg_get_constraintdef, not assumed.
-- Every independent-owner (no-organization) payment would have hit this CHECK violation
-- inside the AFTER trigger, aborting the whole enclosing transaction -- i.e. rolling back
-- apply_payment_result's own payment_records update too, not just the missed finance entry.
-- 20261013064500_fix_booking_finance_posting_trigger.sql has been corrected (profile_id is
-- now set instead of organization_id on the independent path) and is what this script tests.
do $$
declare
  owner_a uuid; owner_b uuid; sp uuid;
  org uuid; res_id uuid; be_org uuid; be_indep uuid;
  bk1 uuid; bk2 uuid;
  v_owner_id uuid; v_org_resource_id uuid; v_org uuid; v_account uuid; v_category uuid;
  v_account2 uuid; v_category2 uuid;
  res text := ''; fails int := 0;
  old_org uuid;
  fin_count int;
  tx1 uuid; tx2 uuid;
begin
  select id into owner_a from public.profiles order by created_at limit 1;
  select id into owner_b from public.profiles order by created_at offset 1 limit 1;
  select id into sp from public.sports order by name limit 1;
  if owner_a is null or owner_b is null or sp is null then
    raise exception 'fixture prerequisites missing (need >=2 profiles, >=1 sport)';
  end if;

  -- CREATE INDEX (unlike CREATE/DROP TRIGGER) is not affected by the hang described above --
  -- confirmed separately in an isolated DO block before writing this file.
  execute 'create unique index if not exists finance_transactions_source_unique on public.finance_transactions (source_type, source_id)';

  ------------------------------------------------------------ fixture: org-linked resource (owner_a)
  -- bookable_entities.entity_type is CHECK-restricted to resource/person/class/event/service
  -- (confirmed live via pg_get_constraintdef) -- 'court'/'coach_session' from the v1 draft
  -- fixtures do not exist as values and were corrected to 'resource'/'service'.
  insert into public.organizations(owner_id, organization_type, name, timezone, default_currency)
    values (owner_a, 'club', 'F04 test org', 'America/Bogota', 'COP') returning id into org;
  insert into public.organization_resources(organization_id, name, resource_type, capacity, status)
    values (org, 'F04 test court', 'court', 4, 'active') returning id into res_id;
  insert into public.bookable_entities(owner_id, entity_type, title, sport_id, capacity, price, currency_code, booking_mode, status, organization_resource_id)
    values (owner_a, 'resource', 'F04 org court', sp, 4, 50000, 'COP', 'instant', 'active', res_id) returning id into be_org;
  insert into public.finance_accounts(organization_id, name, account_type, currency_code, is_active)
    values (org, 'F04 org cash', 'cash', 'COP', true);
  insert into public.finance_categories(organization_id, name, category_type, is_active)
    values (org, 'F04 bookings income', 'income', true);
  insert into public.bookings(bookable_id, booked_by, starts_at, ends_at, quantity, status, payment_status, amount, currency_code)
    values (be_org, owner_b, now() + interval '1 day', now() + interval '1 day 1 hour', 1, 'pending', 'pending', 50000, 'COP')
    returning id into bk1;

  -- Mirrors post_paid_booking_to_finance()'s resolution logic exactly.
  select be.owner_id, be.organization_resource_id into v_owner_id, v_org_resource_id
    from public.bookings b join public.bookable_entities be on be.id = b.bookable_id
    where b.id = bk1;
  if v_org_resource_id is not null then
    select organization_id into v_org from public.organization_resources where id = v_org_resource_id;
  end if;
  if v_org is null and v_owner_id is not null then
    select o.id into v_org from public.organizations o where o.owner_id = v_owner_id order by o.created_at asc limit 1;
  end if;
  if v_org is not null then
    select id into v_account from public.finance_accounts where organization_id=v_org and currency_code='COP' and is_active=true order by created_at asc limit 1;
    select id into v_category from public.finance_categories where organization_id=v_org and category_type='income' and is_active=true order by created_at asc limit 1;
  end if;

  if v_org = org and v_account is not null then
    res := res || E'OK    01 reserva ligada a organizacion: cadena bookable_id->organization_resource_id resuelve org+cuenta correctas\n';
  else
    res := res || format(E'FALLO 01: v_org=%s esperado %s, v_account=%s\n', v_org, org, v_account); fails:=fails+1;
  end if;

  -- Real INSERT, exactly as the corrected function now does for the org-linked path
  -- (organization_id set, profile_id null).
  insert into public.finance_transactions(
    organization_id, profile_id, account_id, category_id, transaction_type, amount, currency_code,
    occurred_at, description, source_type, source_id, status, metadata, created_by
  ) values (
    v_org, null, v_account, v_category, 'income', 50000, 'COP',
    now(), 'Booking payment', 'payment', gen_random_uuid(), 'posted',
    jsonb_build_object('booking_id', bk1), owner_b
  ) returning id into tx1;
  res := res || E'OK    04 insert real (ruta con organizacion) respeta finance_transactions_check (org set, profile_id null)\n';

  v_owner_id:=null; v_org_resource_id:=null; v_org:=null; v_account:=null; v_category:=null;

  ------------------------------------------------------------ fixture: independent resource (owner_b, no org)
  insert into public.bookable_entities(owner_id, entity_type, title, sport_id, capacity, price, currency_code, booking_mode, status, organization_resource_id)
    values (owner_b, 'service', 'F04 coach independiente', sp, 1, 30000, 'COP', 'instant', 'active', null) returning id into be_indep;
  insert into public.finance_accounts(profile_id, name, account_type, currency_code, is_active)
    values (owner_b, 'F04 coach cash', 'cash', 'COP', true);
  insert into public.finance_categories(profile_id, name, category_type, is_active)
    values (owner_b, 'F04 coach income', 'income', true);
  insert into public.bookings(bookable_id, booked_by, starts_at, ends_at, quantity, status, payment_status, amount, currency_code)
    values (be_indep, owner_a, now() + interval '2 days', now() + interval '2 days 1 hour', 1, 'pending', 'pending', 30000, 'COP')
    returning id into bk2;

  select be.owner_id, be.organization_resource_id into v_owner_id, v_org_resource_id
    from public.bookings b join public.bookable_entities be on be.id = b.bookable_id
    where b.id = bk2;
  if v_org_resource_id is not null then
    select organization_id into v_org from public.organization_resources where id = v_org_resource_id;
  end if;
  if v_org is null and v_owner_id is not null then
    select o.id into v_org from public.organizations o where o.owner_id = v_owner_id order by o.created_at asc limit 1;
  end if;
  if v_org is not null then
    select id into v_account from public.finance_accounts where organization_id=v_org and currency_code='COP' and is_active=true order by created_at asc limit 1;
  end if;
  if v_account is null and v_owner_id is not null then
    select id into v_account2 from public.finance_accounts where profile_id=v_owner_id and currency_code='COP' and is_active=true order by created_at asc limit 1;
    select id into v_category2 from public.finance_categories where profile_id=v_owner_id and category_type='income' and is_active=true order by created_at asc limit 1;
  end if;

  if v_org is null and v_account2 is not null then
    res := res || E'OK    02 operador independiente (sin organizacion) cae al fallback de cuenta por perfil\n';
  else
    res := res || format(E'FALLO 02: v_org=%s (se esperaba null) v_account2=%s\n', v_org, v_account2); fails:=fails+1;
  end if;

  -- Real INSERT, exactly as the corrected function now does for the independent path
  -- (profile_id set, organization_id null). This is the path that was broken in v1.
  insert into public.finance_transactions(
    organization_id, profile_id, account_id, category_id, transaction_type, amount, currency_code,
    occurred_at, description, source_type, source_id, status, metadata, created_by
  ) values (
    case when v_org is null then null else v_org end,
    case when v_org is null then v_owner_id else null end,
    v_account2, v_category2, 'income', 30000, 'COP',
    now(), 'Booking payment', 'payment', gen_random_uuid(), 'posted',
    jsonb_build_object('booking_id', bk2), owner_a
  ) returning id into tx2;
  res := res || E'OK    05 insert real (ruta independiente) respeta finance_transactions_check (profile_id set, org null) -- bug encontrado y corregido en esta verificacion\n';

  -- Idempotency: a second attempt for the same source_id must not create a duplicate row.
  insert into public.finance_transactions(
    organization_id, profile_id, account_id, category_id, transaction_type, amount, currency_code,
    occurred_at, description, source_type, source_id, status, metadata, created_by
  )
  select organization_id, profile_id, account_id, category_id, transaction_type, amount, currency_code,
         occurred_at, description, source_type, source_id, status, metadata, created_by
  from public.finance_transactions where id = tx2
  on conflict (source_type, source_id) do nothing;

  select count(*) into fin_count from public.finance_transactions
    where source_type='payment' and source_id = (select source_id from public.finance_transactions where id=tx2);
  if fin_count = 1 then
    res := res || E'OK    06 el indice unico (source_type, source_id) bloquea un segundo asiento duplicado\n';
  else
    res := res || format(E'FALLO 06: se esperaba 1 fila, hay %s\n', fin_count); fails:=fails+1;
  end if;

  -- Documents the original defect for the record: the OLD function's join (be.id =
  -- booking_id, comparing a bookings.id against bookable_entities.id directly) never
  -- matches a real booking id.
  select o.id into old_org from public.bookable_entities be join public.organizations o on o.owner_id=be.owner_id where be.id = bk1;
  if old_org is null then
    res := res || E'OK    03 reproduce el bug diagnosticado: el join viejo (be.id = booking_id) nunca encuentra fila para un booking_id real\n';
  else
    res := res || format(E'FALLO 03: el join viejo encontro org=%s inesperadamente\n', old_org); fails:=fails+1;
  end if;

  raise exception E'RESULTADOS F04 (% fallos)\n%', fails, res;
end $$;
