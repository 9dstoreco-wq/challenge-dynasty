# CHALLENGE DYNASTY — EXTRA MILE REPORT

## Release
Challenge Dynasty Release 1.1 + Extra Mile hardening, based on V17.

## Improvements delivered
1. Core challenge IDs now require canonical UUID format.
2. Dynasty AI chat now rejects oversized payloads, invalid modes, and abusive request bursts.
3. Production checks now scan runtime code for private secret patterns.
4. Skill Engine is explicitly disabled-by-contract until a real Supabase contract exists.
5. Supabase production has a security-exception registry for PostGIS-owned objects.
6. A reproducible Supabase migration is included under `supabase/migrations/`.
7. Structural checks pass after the hardening changes.

## Verified
- Route check: PASS
- SQL/source contract check: PASS
- Core flow check: PASS
- Production structure check: PASS
- Hardening check: PASS

## Not honestly certifiable in this sandbox
- npm dependency install/lockfile generation: registry unavailable.
- full TypeScript/build: dependencies are not installed locally.
- Vercel deployment: current connection does not expose the production project.

## Security exception
`public.spatial_ref_sys` is PostGIS-owned and remains the one Supabase advisor ERROR requiring a deliberate policy decision. The release does not silently enable RLS on that table.
