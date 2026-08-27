# Vercel Environment Contract

Required at Build, Preview and Production:
- NEXT_PUBLIC_SUPABASE_URL
- NEXT_PUBLIC_SUPABASE_ANON_KEY

Server-only billing/provider secrets must not use NEXT_PUBLIC_ prefixes.

Production validation:
1. Verify env vars exist in Vercel.
2. Run npm ci.
3. Run npm run build.
4. Render login/register.
5. Verify authenticated Supabase access.
6. Verify marketplace/shop/business pages.
