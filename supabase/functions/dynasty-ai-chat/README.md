# dynasty-ai-chat

Live Supabase Edge Function for Dynasty AI.

Required server secrets:
- OPENAI_API_KEY
- optional DYNASTY_AI_MODEL

JWT verification is required.

The function uses the authenticated user's RLS-scoped context and AI memory and stores conversation messages in `ai_messages`.
