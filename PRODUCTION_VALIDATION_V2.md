# CHALLENGE DYNASTY — INTEGRATION V2

## Validation target
Validate the live frontend against the real Supabase contracts before production deployment.

## Priority flows
1. Marketplace: published listings → seller → inventory.
2. Dynasty Shop: published products → variants → order model.
3. Club OS: organizations → memberships → resources → bookings.
4. Coach OS: provider profile → services → availability → booking links.
5. Billing: plans → features → subscriptions → entitlements → invoices.
6. Challenges: create → invitation → accept/reject → match → result → review.
7. Tournament: tournament → category → entries → stages/groups → fixtures → check-ins/payments.
8. Notifications and social.

## Production blockers
- No real production deployment until build passes in CI/Vercel.
- No data seeding until the final plan/product catalog is approved.
- No billing activation until payment provider credentials and webhook handling are configured.
- No tournament write tests until organizer/member RLS is verified.

## Current backend facts verified separately
The live Supabase project already contains the main tables and RPCs needed for these flows. The remaining work is frontend-to-backend contract alignment, configuration, and end-to-end verification.
