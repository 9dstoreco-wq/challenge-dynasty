# RELEASE STRATEGY V9

## One source of truth

GitHub main should be the single source for the application code.

Vercel Production should deploy from the Git-connected repository, not from Vercel Drop.

## Supabase

Supabase remains the source of truth for:
- schema
- RLS
- functions
- triggers
- operational data
- billing state
- commerce state

## AI

The AI layer does not replace the underlying data and permission model.
It consumes authorized data and exposes role-specific capabilities through entitlements.

## Before production

1. Confirm Vercel project is visible to the connected Vercel account/team.
2. Confirm GitHub main contains this release.
3. Confirm Supabase env vars are present in Vercel.
4. Generate and commit real package-lock.json.
5. Run npm ci.
6. Run all verification scripts.
7. Run next build.
8. Run Supabase smoke tests.
9. Seed only approved business catalog.
10. Deploy.
11. Inspect runtime errors immediately after release.
