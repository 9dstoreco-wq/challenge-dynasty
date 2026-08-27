# Production Release Checklist V6

BLOCKERS
- [ ] Vercel env vars set for Preview + Production
- [ ] npm ci passes
- [ ] npm run build passes
- [ ] Login/register render
- [ ] Authenticated Supabase client works
- [ ] No fake catalog data shown
- [ ] RLS smoke checks
- [ ] Billing catalog approved
- [ ] Payment provider/webhooks configured
- [ ] Dynasty Shop catalog approved
- [ ] Marketplace seller flow approved
- [ ] First test club/coach/tournament identities ready

GO-LIVE
- [ ] Deploy via GitHub-connected Vercel
- [ ] Verify production URL
- [ ] Challenge smoke test
- [ ] Booking smoke test
- [ ] Tournament read flow
- [ ] Shop browse
- [ ] Marketplace browse

ROLLBACK
Return Vercel production to the previous known-good deployment if a release blocker appears.
