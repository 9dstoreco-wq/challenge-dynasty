# DYNASTY AI RUNTIME V11

Implemented:
- Authenticated `/api/dynasty-ai/chat`
- Server-side retrieval through `get_dynasty_ai_context()`
- Coach AI frontend connected to the API
- No client-side exposure of the provider secret

Current state:
- Supabase context/entitlement layer is live.
- Model-provider execution is intentionally gated behind `DYNASTY_AI_PROVIDER_API_KEY`.
- No fake AI responses are generated when the provider is absent.

Next runtime step:
- Configure an approved model provider key in Vercel/Supabase secrets.
- Add the provider adapter on the server/Edge Function.
- Add conversation persistence and daily coaching memory with role-scoped data.
