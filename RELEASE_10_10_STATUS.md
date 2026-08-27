# CHALLENGE DYNASTY — RELEASE 1.0 GATE

## Base
V17 is the only master source.

## Confirmed against the real Supabase project
- Core frontend contracts exist in Supabase.
- Challenge invitation/result RPCs exist.
- Tournament tables exist.
- Marketplace/shop/billing tables exist.
- Dynasty AI Edge Functions are active with JWT verification.

## Local source hardening completed
- Next.js upgraded to 15.5.24 in package manifest.
- Release verification now includes env check, structural checks, typecheck and production build.
- Security response headers added.
- `poweredByHeader` disabled.
- React Strict Mode enabled.

## Current blockers
1. Dependency installation/build could not complete in this execution environment because npm resolution timed out.
2. Vercel project is not exposed through the current Vercel connection, so production deployment cannot be certified here.
3. Supabase security advisor still reports PostGIS `public.spatial_ref_sys` as a special ownership case. An attempted migration was rejected by Postgres before making changes.
4. Several SECURITY DEFINER advisories remain. They must be reviewed against their intended role contract before revoking execution, because some are legitimate authenticated business RPCs.

## Verdict
Release Candidate / Production Ready source.
Not yet externally certified as Production 1.0.
