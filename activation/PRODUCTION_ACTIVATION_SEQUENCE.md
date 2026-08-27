# CHALLENGE DYNASTY — PRODUCTION ACTIVATION SEQUENCE

## Gate 0 — code
1. Push this candidate to GitHub.
2. Set Vercel Production + Preview env vars:
   - NEXT_PUBLIC_SUPABASE_URL
   - NEXT_PUBLIC_SUPABASE_ANON_KEY
3. Verify a full Vercel build.

## Gate 1 — billing
1. Approve plan names/prices.
2. Seed billing_plans.
3. Seed billing_plan_features.
4. Connect payment provider/webhooks.
5. Create entitlements only from paid/valid subscriptions.

## Gate 2 — club/coach
1. Create real organization records.
2. Create memberships/roles/resources.
3. Create provider_profiles/services/availability.
4. Validate booking and payment ownership.

## Gate 3 — commerce
1. Seed Dynasty Shop products/variants/stock.
2. Create marketplace seller profiles for real sellers.
3. Publish real listings.
4. Validate order/checkout/fulfillment flows.

## Gate 4 — tournaments
1. Create organizer and tournament.
2. Add categories/entries.
3. Validate Fair Play/Draw/Scheduler path.
4. Validate check-in, fixtures, results and payment.

## Gate 5 — production
1. Run all repository checks.
2. Full build passes.
3. Authenticated smoke tests pass.
4. RLS negative tests pass.
5. Only then promote to Production.
