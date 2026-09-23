-- Platform-level "master" access for the app's owner/operator, distinct from any
-- organization's owner_id (which only covers that one club). Nothing in this schema
-- previously distinguished the platform owner from any other player account.

create table if not exists public.platform_admins (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.platform_admins enable row level security;

-- A signed-in user may see only whether THEY are listed here (used by is_platform_admin()
-- below) -- never the full admin roster.
drop policy if exists "platform_admins self read" on public.platform_admins;
create policy "platform_admins self read"
  on public.platform_admins
  for select
  to authenticated
  using (profile_id = auth.uid());

create or replace function public.is_platform_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.platform_admins where profile_id = auth.uid()
  );
$$;

revoke all on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to authenticated;

-- Single aggregate read for the master dashboard. SECURITY DEFINER so it can read across
-- every organization regardless of RLS -- gated by is_platform_admin() as its first check,
-- so this never widens what a non-admin can see.
create or replace function public.get_platform_overview()
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  result jsonb;
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'organizations_total', (select count(*) from public.organizations),
    'organizations_active', (select count(*) from public.organizations where status = 'active'),
    'profiles_total', (select count(*) from public.profiles),
    'tournaments_total', (select count(*) from public.tournaments),
    'tournament_entries_total', (select count(*) from public.tournament_entries),
    'bookings_total', (select count(*) from public.bookings),
    'shop_orders_total', (select count(*) from public.shop_orders),
    'marketplace_orders_total', (select count(*) from public.marketplace_orders),
    'billing_subscriptions_active', (
      select count(*) from public.billing_subscriptions where status in ('active', 'trialing')
    ),
    'revenue_paid_cop', (
      coalesce((select sum(amount_paid) from public.billing_invoices where status = 'paid'), 0) +
      coalesce((select sum(total_amount) from public.shop_orders where payment_status = 'paid'), 0) +
      coalesce((select sum(total_amount) from public.marketplace_orders where status = 'paid'), 0) +
      coalesce((select sum(amount_paid) from public.booking_payment_records where payment_status = 'paid'), 0) +
      coalesce((select sum(amount_paid) from public.tournament_registration_payments where status = 'paid'), 0)
    ),
    'organizations', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', o.id,
        'name', o.name,
        'organization_type', o.organization_type,
        'city', o.city,
        'status', o.status,
        'owner_id', o.owner_id,
        'created_at', o.created_at
      )), '[]'::jsonb)
      from (
        select * from public.organizations
        order by created_at desc
        limit 100
      ) o
    )
  ) into result;

  return result;
end;
$$;

revoke all on function public.get_platform_overview() from public;
grant execute on function public.get_platform_overview() to authenticated;

-- To make yourself the platform admin, after you've registered in the app with the
-- email you'll use to log in as owner, run:
--   insert into public.platform_admins (profile_id)
--   select id from auth.users where email = 'you@example.com'
--   on conflict do nothing;
