# CHALLENGE DYNASTY — MASTER PLATFORM V17

## Live verified
Supabase:
- dynasty-maintenance: ACTIVE v3
- dynasty-ai-context: ACTIVE v1
- dynasty-ai-chat: ACTIVE v3
- JWT verification enabled for all three

Dynasty AI:
- Authenticated user context
- Entitlements
- RLS-scoped organization/seller context
- Persistent conversations
- Persistent messages
- AI memory
- Daily coach session completion
- Usage telemetry
- OpenAI Responses API adapter
- No provider secret stored in client source

Security hardening:
- anon EXECUTE removed from Dynasty AI helper functions
- entitlement probing constrained to the authenticated subject
- AI RLS policies optimized with SELECT auth.uid()
- duplicate ai_messages SELECT policy removed
- missing AI FK indexes added

## Consolidation rule
V17 is the single master package for the work done in this conversation.
Do not continue from older V9/V10/V11/V12/V13/V14/V15/V16 packages.

## Remaining external release gates
The connected Vercel team currently exposes zero projects, so no Vercel production deployment can be honestly claimed from this connection.
The historical Vercel build also showed:
- Next.js 14.2.31 security warning
- missing NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY during prerender of login/register/onboarding

Those must be fixed in the actual Vercel project before production certification.

The production-vs-GitHub drift and the larger contract-drift findings are documented in CHALLENGE_DYNASTY_DEEP_AUDIT_V2.md and must be treated as release-gate work rather than papered over.
