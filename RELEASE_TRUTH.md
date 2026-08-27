# RELEASE TRUTH — CHALLENGE DYNASTY 1.0

## Verified
- V17 is the only master source.
- Live Supabase project is healthy and contains the core tables and RPCs documented in `SUPABASE_REAL_CONTRACT.md`.
- Routes check passes.
- SQL/source contract check passes.
- Core flow check passes.
- Production structure check passes.
- Hardening check passes.
- Login client initialization defect fixed.
- Skill challenge creation route no longer exposes a dead form.

## Not claimed
- No local `npm install` / production build certification in this audit environment, because dependency resolution does not complete here.
- No Vercel deployment certification from this connection, because the Vercel integration does not expose the project.
- No automatic RLS change to `public.spatial_ref_sys`.

## Final gate in connected CI
1. npm ci/install
2. npm run verify:release
3. npm run build
4. E2E smoke tests
5. deploy to Vercel
6. verify production routes and auth
