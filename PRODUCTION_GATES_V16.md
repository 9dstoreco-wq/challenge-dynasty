# PRODUCTION GATES V16

PASS:
- Supabase AI RLS hardening applied.
- AI helper anon access removed.
- AI entitlement authorization constrained to current user/authorized org/seller.
- AI indexes present.

BLOCKED:
- OpenAI secret configuration.
- GitHub -> Vercel release visibility.
- Clean CI build pending real lockfile.
