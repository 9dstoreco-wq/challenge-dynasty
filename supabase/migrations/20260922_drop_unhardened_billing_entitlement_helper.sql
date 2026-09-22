-- CHALLENGE DYNASTY
-- Security cleanup: 20260826_add_billing_entitlement_helpers.sql created
-- public.has_billing_entitlement(feature_key, profile_id, organization_id, seller_profile_id),
-- but it was superseded the same day by the hardened public.has_ai_entitlement() in
-- 20260826_ai_security_performance_hardening.sql. Nothing ever dropped the old function, and
-- unlike the replacement it trusts whatever profile_id/organization_id/seller_profile_id the
-- caller passes in (no auth.uid() match, no organization_memberships / seller ownership check),
-- so any authenticated caller could use it to probe whether an arbitrary profile or
-- organization holds a given billing entitlement. Nothing in the app calls it (confirmed via
-- repo-wide grep) -- drop it outright rather than leaving an unused, unhardened duplicate of
-- the real entitlement check reachable over PostgREST.

drop function if exists public.has_billing_entitlement(text, uuid, uuid, uuid);
