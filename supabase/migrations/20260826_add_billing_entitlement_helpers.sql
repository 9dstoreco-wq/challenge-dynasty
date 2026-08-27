-- CHALLENGE DYNASTY
-- Billing/Entitlement helper layer
-- Non-destructive: creates/replaces helper functions only. No seed data.

create or replace function public.has_billing_entitlement(
  p_feature_key text,
  p_profile_id uuid default null,
  p_organization_id uuid default null,
  p_seller_profile_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.billing_entitlements e
    left join public.billing_subscriptions s on s.id = e.subscription_id
    where e.feature_key = p_feature_key
      and (e.ends_at is null or e.ends_at > now())
      and (
        (p_profile_id is not null and e.profile_id = p_profile_id)
        or (p_organization_id is not null and e.organization_id = p_organization_id)
        or (p_seller_profile_id is not null and e.seller_profile_id = p_seller_profile_id)
      )
      and (s.id is null or s.status in ('trialing','active','past_due'))
  );
$$;

create or replace function public.is_billing_subscription_active(p_subscription_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.billing_subscriptions s
    where s.id = p_subscription_id
      and s.status in ('trialing','active','past_due')
      and (s.current_period_end is null or s.current_period_end > now())
  );
$$;
