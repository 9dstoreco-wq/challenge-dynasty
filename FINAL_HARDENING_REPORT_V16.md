# CHALLENGE DYNASTY — FINAL HARDENING REPORT V16

## Live fixes applied to Supabase

### AI security
- Removed `anon` EXECUTE access from `get_dynasty_ai_context()`.
- Removed `anon` EXECUTE access from `has_ai_entitlement(...)`.
- Kept execution for authenticated/service_role.
- Hardened `has_ai_entitlement` so callers cannot probe arbitrary users, organizations, or sellers.
- Set a controlled `search_path` on SECURITY DEFINER AI functions.

### AI RLS performance
- Replaced row-by-row `auth.uid()` evaluation with `(select auth.uid())`.
- Removed the duplicate permissive SELECT policy on `ai_messages`.
- Added indexes covering the new AI foreign keys.

## Verification
- AI tables remain RLS protected.
- Final AI policies resolve to authenticated-only ownership policies.
- `anon` no longer has EXECUTE on the two AI helper functions.
- AI foreign-key indexes exist.

## Deliberately NOT changed
- PostGIS `spatial_ref_sys` / extension placement.
- Existing application SECURITY DEFINER functions used by core Challenge/Club/Booking flows. These require separate function-by-function authorization review because blindly revoking them could break product behavior.
- Existing unused indexes. They should be reviewed only after representative production workloads exist.

## Production blockers still outside this connection
- Real `OPENAI_API_KEY` secret configuration.
- GitHub main publication of the final source.
- Vercel project access through the active Vercel connection.
- Real package-lock generation and clean CI build.
