# DYNASTY AI PRODUCTION CONNECT — V13

## Live Supabase infrastructure
- `dynasty-ai-context` — ACTIVE
- `dynasty-ai-chat` — ACTIVE, JWT required
- AI memory tables/RPCs — present
- Daily coach session functions — present

## Frontend
`/api/dynasty-ai/chat` now forwards authenticated requests to the live Supabase Edge Function `dynasty-ai-chat`.

## Provider
The Edge Function calls the OpenAI Responses API and uses:
- `OPENAI_API_KEY` as a server secret
- `DYNASTY_AI_MODEL` optional, defaulting to `gpt-5.6-luna`

## Required production configuration
Set these secrets in Supabase Edge Function secrets:
- `OPENAI_API_KEY`
- optional `DYNASTY_AI_MODEL`

Never expose `OPENAI_API_KEY` to browser/client code.

## Behavior when provider key is missing
The function returns `AI_PROVIDER_NOT_CONFIGURED` and does not fabricate an AI answer.

## Next technical gate
1. Configure provider secret.
2. Send an authenticated test message.
3. Confirm a row appears in `ai_messages` for the user and assistant.
4. Confirm daily session / memory calls work.
5. Then connect Vercel production to the GitHub release.
