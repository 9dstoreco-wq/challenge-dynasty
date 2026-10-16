-- F12 follow-up: enable RLS on the two ledger tables created by F12
-- (billing_invoice_payments, tournament_registration_payment_events).
--
-- WHY: Supabase security advisors flag both as ERROR level
-- ("rls_disabled_in_public") right now in production. They already exist
-- live (created when F12 was applied) but were never given RLS, so any
-- authenticated/anon client can currently SELECT * from them directly.
--
-- SAFE TO RUN: both tables are only ever written by
-- confirm_billing_invoice_payment() / confirm_tournament_registration_payment(),
-- which are SECURITY DEFINER functions owned by `postgres` (bypasses RLS) and
-- already restricted to service_role via REVOKE/GRANT. Enabling RLS here only
-- restricts direct client-side SELECT access; it does not affect those
-- functions' ability to write.
--
-- Read policies mirror the existing, already-audited visibility rules on the
-- parent tables (billing_invoices, tournament_entries) via EXISTS, so they
-- stay in sync automatically if those policies change later.
--
-- NOTE FOR LUIS: this file is committed to the repo for history, but per our
-- rule it has NOT been run against production. Known project issue: in this
-- Supabase project, some DDL (DROP/CREATE TRIGGER, multi-guard functions)
-- hangs >3 min with no trace when run through automated tools. Plain
-- ALTER TABLE ... ENABLE ROW LEVEL SECURITY + CREATE POLICY like this one is
-- not in that failure pattern, but to stay safe, paste it into the Supabase
-- SQL editor yourself (project "Challenge Dynasty") when you're ready.

begin;

alter table public.billing_invoice_payments enable row level security;

create policy "billing invoice payments owner read"
on public.billing_invoice_payments
for select
to authenticated
using (
  exists (
    select 1 from public.billing_invoices bi
    where bi.id = billing_invoice_payments.invoice_id
  )
);

alter table public.tournament_registration_payment_events enable row level security;

create policy "tournament registration payment events owner read"
on public.tournament_registration_payment_events
for select
to authenticated
using (
  exists (
    select 1 from public.tournament_entries te
    where te.id = tournament_registration_payment_events.entry_id
  )
);

commit;

-- Verification (run after commit, read-only):
-- select relname, relrowsecurity from pg_class
--   where relname in ('billing_invoice_payments','tournament_registration_payment_events');
-- -- both should now show relrowsecurity = true
