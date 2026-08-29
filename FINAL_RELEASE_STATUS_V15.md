# CHALLENGE DYNASTY — FINAL RELEASE V15

## Live backend
- `dynasty-ai-context`: ACTIVE, JWT required
- `dynasty-ai-chat`: ACTIVE, version 2, JWT required
- AI context/memory/daily-session functions: present
- AI persistence tables protected by RLS

## Model configuration
Default model is now `gpt-5.6`, matching the current OpenAI API documentation.
Provider secret is still required in Supabase:
- OPENAI_API_KEY

Optional:
- DYNASTY_AI_MODEL

## External release blockers
1. Set the real OpenAI secret in Supabase Edge Function secrets.
2. Publish the final repository to the user's GitHub main branch.
3. Verify the GitHub-connected Vercel project is visible to the active Vercel integration.
4. Generate/commit the real package-lock.json.
5. Run a clean CI build.
6. Execute an authenticated end-to-end Coach AI test.

No provider secret is stored in this artifact.
No fake commercial data was seeded.
