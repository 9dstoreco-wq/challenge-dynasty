# CHALLENGE DYNASTY — REAL SUPABASE CONTRACT

## Authority
The live Supabase project is the backend source of truth. `supabase/schema_master.sql` in this bundle is an offline reference only and may drift from production. Do not use the bundled SQL as proof that a production table exists.

## Verified live core tables
- profiles
- sports
- challenges
- challenge_participants
- matches
- match_results
- challenge_invitations
- player_sports
- player_progression
- xp_events
- player_cards
- achievements
- player_achievements
- player_rivalries
- social_posts
- social_follows
- social_reactions
- social_comments
- notifications
- notification_preferences
- user_blocks
- organizations
- organization_resources
- bookings
- provider_profiles
- provider_services
- marketplace_listings
- marketplace_seller_profiles
- shop_products
- shop_product_variants
- shop_orders
- billing_plans
- billing_subscriptions
- billing_entitlements
- tournaments
- tournament_categories
- tournament_entries
- tournament_entry_members
- tournament_stages
- tournament_groups
- tournament_group_entries
- tournament_fixtures
- payment_records
- conversations
- conversation_participants
- conversation_messages
- ai_conversations
- ai_messages
- ai_memory_notes
- ai_daily_coach_sessions
- ai_usage_events

## Verified live challenge / AI RPCs
- create_challenge
- respond_to_challenge_invitation
- submit_challenge_result
- review_challenge_result
- get_dynasty_ai_context
- get_or_create_daily_coach_session
- mark_notification_read

## Intentionally not exposed
The old `partner_requests` / `pair_profiles` contract exists in some historical offline SQL artifacts but is not present in the live Supabase schema currently connected to Dynasty. The UI therefore keeps partner-request creation disabled rather than calling a stale RPC.

## Security note
Supabase currently reports a critical advisory for `public.spatial_ref_sys`. This is a PostGIS-owned table. Do not enable RLS blindly; the correct production remediation must preserve PostGIS behavior and be applied with explicit policies or a supported extension-schema strategy.
