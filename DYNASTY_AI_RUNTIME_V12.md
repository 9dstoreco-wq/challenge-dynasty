# DYNASTY AI RUNTIME V12

## Live backend capabilities added
- ai_conversations
- ai_messages
- ai_memory_notes
- ai_daily_coach_sessions
- ai_usage_events
- get_dynasty_ai_context()
- get_dynasty_ai_memory()
- upsert_dynasty_ai_memory()
- get_or_create_daily_coach_session()
- mark_ai_daily_coach_completed()

## Product behavior
Coach AI now has:
- daily session state
- persistent conversation tables
- memory notes with scope/key/confidence
- usage telemetry table
- RLS owner isolation

## Model provider
The runtime remains provider-gated. For an OpenAI implementation, the current official API uses the Responses API; server-side credentials must remain private. The model/provider secret must be configured before production AI responses are enabled.

## Cost control
AI usage events are recorded server-side. Client users cannot insert/update/delete usage records directly.
