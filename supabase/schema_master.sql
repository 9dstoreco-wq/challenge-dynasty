-- Challenge Dynasty -- SCHEMA MASTER (snapshot de referencia)
-- ESTADO: SOLO REFERENCIA. NO EJECUTAR contra una base de datos que ya tiene estos objetos
-- (va a fallar en cada ALTER TABLE ADD CONSTRAINT y cada CREATE POLICY con "ya existe").
-- Generado: 2026-10-08, por introspeccion directa de la base de datos EN VIVO de Supabase
-- (proyecto ggkthvewxmsmtupjzfnk), usando pg_catalog (pg_get_constraintdef, pg_get_indexdef,
-- pg_get_functiondef, pg_get_triggerdef, pg_get_viewdef, format_type) -- las mismas funciones
-- que usa pg_dump para generar DDL exacto. No es una migracion escrita a mano: es lo que la
-- base de datos real reporto que tiene hoy.
--
-- PARA QUE SIRVE:
-- El archivo anterior de schema_master.sql no coincidia con la base en vivo (viejo, de antes
-- de ~260 migraciones aplicadas una por una en el editor SQL de Supabase durante este proyecto).
-- Si alguien quisiera montar Challenge Dynasty desde cero hoy, pegar y correr el archivo viejo
-- no reproduciria la base real. Este archivo nuevo SI la reproduce: es el espejo fiel de las
-- ~205 tablas de la app (206 contando spatial_ref_sys, que la crea sola la extension postgis),
-- 1023 restricciones, 458 indices propios, 316 politicas RLS, 139 funciones, 28 triggers y
-- 5 vistas que existen hoy en produccion -- verificado corriendo este archivo completo contra
-- un Postgres 16 + PostGIS limpio antes de entregarlo: termino sin un solo error y los conteos
-- de tablas/politicas/funciones/triggers/indices/restricciones/vistas del resultado coinciden
-- exactamente con los de produccion.
--
-- COMO USARLO (proyecto Supabase nuevo y vacio):
-- 1. Crear el proyecto en Supabase (gratis).
-- 2. En el editor SQL, pegar y correr este archivo completo, UNA SOLA VEZ, de arriba a abajo.
-- 3. Los roles anon/authenticated/service_role y los permisos por defecto en el esquema public
--    ya los trae Supabase de fabrica en cualquier proyecto nuevo -- este archivo solo ajusta
--    permiso por permiso las tablas donde produccion restringio mas alla de RLS (ver la
--    seccion PERMISOS al final).
--
-- QUE NO INCLUYE (limitaciones conocidas, honestas):
-- - Nada del esquema "auth" (usuarios, sesiones) ni "storage" -- eso Supabase lo crea solo en
--   cada proyecto nuevo, no es parte de las migraciones de esta app.
-- - Los datos (filas) de ninguna tabla -- esto es solo la ESTRUCTURA, no un backup.
-- - La extension postgis crea sus propias tablas/vistas de sistema (spatial_ref_sys,
--   geometry_columns, geography_columns) automaticamente al hacer CREATE EXTENSION --
--   tambien se recrean solas, no estan listadas aqui. (spatial_ref_sys es justamente el
--   hallazgo de RLS deshabilitado ya registrado en la auditoria como riesgo bajo -- es tabla
--   de catalogo de PostGIS, de solo lectura publica por diseno, no datos de la app.)
-- - La tabla "zz_probe_cards" (abajo) parece un resto de pruebas (solo tiene una columna
--   "id integer", sin RLS real util) -- se incluye porque existe hoy en produccion, pero vale
--   la pena que Luis decida si se puede borrar.
--
-- Carpeta supabase/migrations/ -- que hacer con ella:
-- Sigue siendo el lugar donde se agregan los cambios NUEVOS de aqui en adelante (una lectura
-- cronologica de "que cambio y por que", archivo por archivo). Este schema_master.sql no la
-- reemplaza ni la vuelve innecesaria para el futuro -- lo que arregla es el punto de partida:
-- antes, un proyecto nuevo no se podia reconstruir ni con schema_master.sql (viejo) ni con la
-- carpeta de migraciones (que tampoco tiene las ~260 migraciones reales aplicadas una por una
-- en el editor SQL). Ahora, un proyecto nuevo arranca de este archivo, y de ahi en adelante
-- sigue los archivos de supabase/migrations/ en orden de fecha si hay alguno mas reciente que
-- esta fecha de exportacion (2026-10-08).



-- ============================================================================
-- EXTENSIONES
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "postgis" WITH SCHEMA public;
-- pg_cron y supabase_vault ya vienen habilitadas por Supabase en cualquier proyecto nuevo.


-- ============================================================================
-- TABLAS (205)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.account_security_devices (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  device_label text,
  platform text,
  device_fingerprint_hash text,
  last_ip_hash text,
  first_seen_at timestamp with time zone DEFAULT now() NOT NULL,
  last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
  revoked_at timestamp with time zone,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS public.account_security_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid,
  event_type text NOT NULL,
  risk_level text DEFAULT 'low'::text NOT NULL,
  ip_hash text,
  device_id uuid,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.achievements (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  code text NOT NULL,
  category text NOT NULL,
  xp_reward integer DEFAULT 0 NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_coach_interactions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  mode text NOT NULL,
  model text NOT NULL,
  policy_version text NOT NULL,
  context_hash text NOT NULL,
  input_summary jsonb DEFAULT '{}'::jsonb NOT NULL,
  output jsonb DEFAULT '{}'::jsonb NOT NULL,
  latency_ms integer,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_conversations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  mode text DEFAULT 'coach'::text NOT NULL,
  title text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_daily_coach_sessions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  session_date date DEFAULT CURRENT_DATE NOT NULL,
  mode text DEFAULT 'coach'::text NOT NULL,
  plan jsonb DEFAULT '{}'::jsonb NOT NULL,
  completed boolean DEFAULT false NOT NULL,
  completed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_evolution_agent_performance (
  role text NOT NULL,
  reviews_count integer DEFAULT 0 NOT NULL,
  successful_reviews integer DEFAULT 0 NOT NULL,
  failed_reviews integer DEFAULT 0 NOT NULL,
  average_score numeric DEFAULT 0 NOT NULL,
  weight numeric DEFAULT 1 NOT NULL,
  last_outcome text,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_evolution_council_reviews (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  proposal_id uuid NOT NULL,
  run_id uuid NOT NULL,
  role text NOT NULL,
  verdict text NOT NULL,
  score integer NOT NULL,
  findings jsonb DEFAULT '[]'::jsonb NOT NULL,
  recommendation text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_evolution_evaluations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  proposal_id uuid NOT NULL,
  stage text NOT NULL,
  verdict text NOT NULL,
  score numeric,
  findings jsonb DEFAULT '[]'::jsonb NOT NULL,
  metrics jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_evolution_locks (
  lock_key text NOT NULL,
  locked_at timestamp with time zone DEFAULT now() NOT NULL,
  run_id uuid,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_evolution_memory (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  memory_key text NOT NULL,
  summary text NOT NULL,
  evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
  outcome text,
  confidence numeric DEFAULT 0.5 NOT NULL,
  source_run_id uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_evolution_outcomes (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  proposal_id uuid NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  applied boolean DEFAULT false NOT NULL,
  outcome text,
  baseline_metrics jsonb DEFAULT '{}'::jsonb NOT NULL,
  observed_metrics jsonb DEFAULT '{}'::jsonb NOT NULL,
  impact_score numeric,
  regression_detected boolean DEFAULT false NOT NULL,
  evidence jsonb DEFAULT '[]'::jsonb NOT NULL,
  notes text,
  observed_at timestamp with time zone,
  measured_by text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  learning_applied_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS public.ai_evolution_proposals (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  run_id uuid NOT NULL,
  title text NOT NULL,
  category text NOT NULL,
  hypothesis text,
  evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
  proposed_change text NOT NULL,
  expected_value text,
  attack_findings jsonb DEFAULT '[]'::jsonb NOT NULL,
  risk_level text DEFAULT 'medium'::text NOT NULL,
  status text DEFAULT 'proposed'::text NOT NULL,
  test_report jsonb DEFAULT '{}'::jsonb NOT NULL,
  approved_by uuid,
  approved_at timestamp with time zone,
  applied_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  score numeric,
  simulation jsonb DEFAULT '{}'::jsonb NOT NULL,
  critique jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_evolution_runs (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  trigger_type text DEFAULT 'manual'::text NOT NULL,
  scope text DEFAULT 'platform'::text NOT NULL,
  status text DEFAULT 'started'::text NOT NULL,
  model text,
  summary text,
  observations jsonb DEFAULT '{}'::jsonb NOT NULL,
  proposals jsonb DEFAULT '[]'::jsonb NOT NULL,
  risk_level text,
  requires_approval boolean DEFAULT true NOT NULL,
  started_at timestamp with time zone DEFAULT now() NOT NULL,
  finished_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_memory_notes (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  scope text DEFAULT 'athlete'::text NOT NULL,
  note_key text NOT NULL,
  note_value jsonb DEFAULT '{}'::jsonb NOT NULL,
  confidence numeric,
  source_message_id uuid,
  active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_messages (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  conversation_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  role text NOT NULL,
  content text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_policy_evaluations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  version text NOT NULL,
  metric text NOT NULL,
  score numeric NOT NULL,
  sample_size integer DEFAULT 0 NOT NULL,
  details jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_policy_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  version text NOT NULL,
  event_type text NOT NULL,
  actor text NOT NULL,
  details jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_policy_versions (
  version text NOT NULL,
  prompt_template text NOT NULL,
  model text NOT NULL,
  status text NOT NULL,
  score numeric DEFAULT 0 NOT NULL,
  sample_size integer DEFAULT 0 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  promoted_at timestamp with time zone,
  parent_version text,
  activated_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS public.ai_recommendation_outcomes (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  interaction_id uuid NOT NULL,
  recommendation_key text NOT NULL,
  outcome text NOT NULL,
  reward numeric DEFAULT 0 NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_request_reservations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  feature_key text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  expires_at timestamp with time zone DEFAULT (now() + '00:10:00'::interval) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_usage_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid,
  feature_key text NOT NULL,
  model text,
  input_tokens integer,
  output_tokens integer,
  request_id text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.analytics_daily_metrics (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  metric_date date NOT NULL,
  metric_scope text NOT NULL,
  profile_id uuid,
  organization_id uuid,
  seller_profile_id uuid,
  sport_id uuid,
  metric_key text NOT NULL,
  metric_value numeric(18,4) DEFAULT 0 NOT NULL,
  dimensions jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.analytics_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid,
  organization_id uuid,
  seller_profile_id uuid,
  session_id text,
  event_name text NOT NULL,
  entity_type text,
  entity_id uuid,
  sport_id uuid,
  properties jsonb DEFAULT '{}'::jsonb NOT NULL,
  occurred_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  actor_profile_id uuid,
  organization_id uuid,
  action text NOT NULL,
  target_type text,
  target_id uuid,
  request_id text,
  source_channel text,
  ip_hash text,
  user_agent_hash text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  occurred_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.background_job_runs (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  job_key text NOT NULL,
  status text NOT NULL,
  started_at timestamp with time zone DEFAULT now() NOT NULL,
  completed_at timestamp with time zone,
  details jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS public.billing_entitlements (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  subscription_id uuid,
  profile_id uuid,
  organization_id uuid,
  seller_profile_id uuid,
  feature_key text NOT NULL,
  feature_value jsonb DEFAULT 'true'::jsonb NOT NULL,
  starts_at timestamp with time zone DEFAULT now() NOT NULL,
  ends_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.billing_invoices (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  subscription_id uuid,
  profile_id uuid,
  organization_id uuid,
  seller_profile_id uuid,
  invoice_number text,
  amount_due numeric(14,2) DEFAULT 0 NOT NULL,
  amount_paid numeric(14,2) DEFAULT 0 NOT NULL,
  currency_code text DEFAULT 'USD'::text NOT NULL,
  status text DEFAULT 'open'::text NOT NULL,
  due_at timestamp with time zone,
  paid_at timestamp with time zone,
  provider_name text,
  provider_invoice_reference text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.billing_plan_features (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  plan_id uuid NOT NULL,
  feature_key text NOT NULL,
  feature_value jsonb DEFAULT 'true'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.billing_plans (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  audience_type text NOT NULL,
  description text,
  billing_interval text NOT NULL,
  price numeric(14,2) DEFAULT 0 NOT NULL,
  currency_code text DEFAULT 'USD'::text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.billing_subscriptions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  plan_id uuid NOT NULL,
  profile_id uuid,
  organization_id uuid,
  seller_profile_id uuid,
  status text DEFAULT 'trialing'::text NOT NULL,
  current_period_start timestamp with time zone,
  current_period_end timestamp with time zone,
  cancel_at_period_end boolean DEFAULT false NOT NULL,
  provider_name text,
  provider_customer_reference text,
  provider_subscription_reference text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.billing_usage_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  subscription_id uuid,
  profile_id uuid,
  organization_id uuid,
  seller_profile_id uuid,
  feature_key text NOT NULL,
  quantity numeric(14,2) DEFAULT 1 NOT NULL,
  occurred_at timestamp with time zone DEFAULT now() NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS public.bookable_entities (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  owner_id uuid,
  entity_type text NOT NULL,
  entity_id uuid,
  title text NOT NULL,
  sport_id uuid,
  activity_name text,
  location_id uuid,
  capacity integer DEFAULT 1 NOT NULL,
  duration_minutes integer,
  price numeric(12,2) DEFAULT 0 NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  booking_mode text DEFAULT 'instant'::text NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  organization_resource_id uuid
);

CREATE TABLE IF NOT EXISTS public.booking_availability_rules (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  bookable_id uuid NOT NULL,
  day_of_week smallint,
  start_time time without time zone,
  end_time time without time zone,
  timezone text DEFAULT 'America/Bogota'::text NOT NULL,
  valid_from date,
  valid_until date,
  is_available boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.booking_blackouts (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  bookable_id uuid NOT NULL,
  starts_at timestamp with time zone NOT NULL,
  ends_at timestamp with time zone NOT NULL,
  reason text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.booking_dependencies (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  parent_bookable_id uuid NOT NULL,
  required_bookable_id uuid NOT NULL,
  quantity integer DEFAULT 1 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.booking_finance_links (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  booking_id uuid NOT NULL,
  finance_transaction_id uuid NOT NULL,
  finance_invoice_id uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.booking_groups (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  requested_by uuid NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  starts_at timestamp with time zone NOT NULL,
  ends_at timestamp with time zone NOT NULL,
  total_amount numeric(12,2) DEFAULT 0 NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  payment_status text DEFAULT 'not_required'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.booking_payment_records (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  booking_id uuid NOT NULL,
  provider_service_id uuid,
  payment_owner_type text NOT NULL,
  provider_id uuid,
  organization_id uuid,
  amount_due numeric(14,2) DEFAULT 0 NOT NULL,
  amount_paid numeric(14,2) DEFAULT 0 NOT NULL,
  deposit_amount numeric(14,2) DEFAULT 0 NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  payment_status text DEFAULT 'unpaid'::text NOT NULL,
  paid_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.booking_policies (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  bookable_id uuid NOT NULL,
  min_notice_minutes integer DEFAULT 0 NOT NULL,
  cancellation_deadline_minutes integer,
  no_show_grace_minutes integer DEFAULT 0 NOT NULL,
  allow_waitlist boolean DEFAULT false NOT NULL,
  auto_promote_waitlist boolean DEFAULT true NOT NULL,
  max_active_bookings_per_user integer,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  payment_hold_minutes integer DEFAULT 15 NOT NULL
);

CREATE TABLE IF NOT EXISTS public.booking_waitlist (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  bookable_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  requested_starts_at timestamp with time zone NOT NULL,
  requested_ends_at timestamp with time zone NOT NULL,
  quantity integer DEFAULT 1 NOT NULL,
  status text DEFAULT 'waiting'::text NOT NULL,
  priority integer DEFAULT 0 NOT NULL,
  expires_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.bookings (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  bookable_id uuid NOT NULL,
  booked_by uuid NOT NULL,
  starts_at timestamp with time zone NOT NULL,
  ends_at timestamp with time zone NOT NULL,
  quantity integer DEFAULT 1 NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  payment_status text DEFAULT 'not_required'::text NOT NULL,
  amount numeric(12,2) DEFAULT 0 NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  notes text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  booking_group_id uuid
);

CREATE TABLE IF NOT EXISTS public.card_definitions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  code text NOT NULL,
  category text NOT NULL,
  rarity text DEFAULT 'common'::text NOT NULL,
  xp_reward integer DEFAULT 0 NOT NULL,
  trigger_key text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.card_delivery_failures (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  challenge_id uuid NOT NULL,
  match_id uuid NOT NULL,
  winner_profile_id uuid NOT NULL,
  loser_profile_id uuid,
  sport_id uuid,
  rarity text,
  step text NOT NULL,
  stake_loser_card_id uuid,
  error_message text,
  attempts integer DEFAULT 0 NOT NULL,
  resolved boolean DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  last_attempt_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS public.challenge_card_stakes (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  challenge_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  card_id uuid NOT NULL,
  status text DEFAULT 'locked'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  settled_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS public.challenge_invitations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  challenge_id uuid NOT NULL,
  inviter_id uuid NOT NULL,
  invitee_id uuid,
  status text DEFAULT 'pending'::text NOT NULL,
  message text,
  expires_at timestamp with time zone,
  responded_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.challenge_participants (
  challenge_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  role text DEFAULT 'participant'::text NOT NULL,
  status text DEFAULT 'invited'::text NOT NULL,
  joined_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.challenge_share_links (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  challenge_id uuid NOT NULL,
  created_by uuid NOT NULL,
  token text DEFAULT encode(gen_random_bytes(16), 'hex'::text) NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  expires_at timestamp with time zone,
  max_uses integer,
  uses_count integer DEFAULT 0 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.challenges (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  sport_id uuid NOT NULL,
  creator_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  status text DEFAULT 'open'::text NOT NULL,
  challenge_type text DEFAULT 'match'::text NOT NULL,
  scheduled_at timestamp with time zone,
  location_name text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.content_reports (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  reporter_profile_id uuid,
  target_type text NOT NULL,
  target_id uuid NOT NULL,
  reason text NOT NULL,
  details text,
  status text DEFAULT 'open'::text NOT NULL,
  resolution_notes text,
  resolved_by uuid,
  resolved_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.conversation_messages (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  conversation_id uuid NOT NULL,
  sender_profile_id uuid,
  body text NOT NULL,
  status text DEFAULT 'sent'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  edited_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS public.conversation_participants (
  conversation_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  last_read_at timestamp with time zone,
  joined_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.conversations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  context_type text,
  context_id uuid,
  created_by uuid,
  status text DEFAULT 'open'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.data_retention_policies (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  entity_type text NOT NULL,
  retention_days integer,
  anonymize_after_days integer,
  enabled boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.discovery_blocks (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  block_scope text DEFAULT 'entity'::text NOT NULL,
  reason text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.discovery_controls (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  distance_mode text DEFAULT 'nearby'::text NOT NULL,
  custom_radius_km numeric(6,2),
  show_recommendation_reasons boolean DEFAULT true NOT NULL,
  personalized_recommendations boolean DEFAULT true NOT NULL,
  blocked_entity_types text[] DEFAULT '{}'::text[] NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.discovery_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid,
  entity_type text NOT NULL,
  entity_id uuid,
  surface text NOT NULL,
  event_type text NOT NULL,
  location_context jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.discovery_preferences (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  sports_scope uuid[] DEFAULT '{}'::uuid[] NOT NULL,
  discovery_radius_km numeric(6,2) DEFAULT 25 NOT NULL,
  allow_local boolean DEFAULT true NOT NULL,
  allow_regional boolean DEFAULT true NOT NULL,
  allow_national boolean DEFAULT true NOT NULL,
  allow_global boolean DEFAULT false NOT NULL,
  preferred_languages text[] DEFAULT ARRAY['es'::text] NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.dynasty_card_transfers (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  card_id uuid NOT NULL,
  from_profile_id uuid NOT NULL,
  to_profile_id uuid NOT NULL,
  challenge_id uuid,
  match_id uuid,
  reason text DEFAULT 'challenge_stake'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.dynasty_cards (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  serial bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  sport_id uuid NOT NULL,
  owner_profile_id uuid NOT NULL,
  original_profile_id uuid NOT NULL,
  rarity text DEFAULT 'common'::text NOT NULL,
  origin text NOT NULL,
  is_protected boolean DEFAULT false NOT NULL,
  source_match_id uuid,
  stats jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.dynasty_mission_rewards (
  user_mission_id uuid NOT NULL,
  awarded_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.dynasty_progression_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  source_type text NOT NULL,
  source_id uuid NOT NULL,
  sport_id uuid,
  won boolean NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.entity_availability (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  availability_status text DEFAULT 'available'::text NOT NULL,
  starts_at timestamp with time zone,
  ends_at timestamp with time zone,
  schedule jsonb DEFAULT '{}'::jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.entity_sports (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  sport_id uuid NOT NULL,
  is_primary boolean DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.finance_accounts (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  organization_id uuid,
  profile_id uuid,
  name text NOT NULL,
  account_type text NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.finance_categories (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  organization_id uuid,
  profile_id uuid,
  parent_id uuid,
  name text NOT NULL,
  category_type text NOT NULL,
  activity_id uuid,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.finance_invoices (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  organization_id uuid,
  profile_id uuid,
  invoice_number text,
  direction text NOT NULL,
  counterparty_name text NOT NULL,
  issue_date date DEFAULT CURRENT_DATE NOT NULL,
  due_date date,
  total_amount numeric(14,2) NOT NULL,
  paid_amount numeric(14,2) DEFAULT 0 NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  status text DEFAULT 'open'::text NOT NULL,
  activity_id uuid,
  source_type text,
  source_id uuid,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.finance_recurring_items (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  organization_id uuid,
  profile_id uuid,
  account_id uuid,
  category_id uuid,
  transaction_type text NOT NULL,
  amount numeric(14,2) NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  description text,
  frequency text NOT NULL,
  next_occurrence date NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.finance_transactions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  organization_id uuid,
  profile_id uuid,
  account_id uuid NOT NULL,
  category_id uuid,
  activity_id uuid,
  transaction_type text NOT NULL,
  amount numeric(14,2) NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  occurred_at timestamp with time zone DEFAULT now() NOT NULL,
  description text,
  source_type text,
  source_id uuid,
  counterparty_name text,
  status text DEFAULT 'posted'::text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.intelligence_signals (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid,
  signal_type text NOT NULL,
  entity_type text,
  entity_id uuid,
  sport_id uuid,
  weight numeric(12,6) DEFAULT 1 NOT NULL,
  occurred_at timestamp with time zone DEFAULT now() NOT NULL,
  expires_at timestamp with time zone,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS public.locale_translations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  locale_code text NOT NULL,
  namespace text NOT NULL,
  translation_key text NOT NULL,
  value text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.marketplace_item_returns (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  order_item_id uuid NOT NULL,
  quantity integer NOT NULL,
  refund_amount numeric(14,2) NOT NULL,
  status text DEFAULT 'requested'::text NOT NULL,
  reason text,
  provider_refund_id text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.marketplace_listing_analytics_daily (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  listing_id uuid NOT NULL,
  metric_date date NOT NULL,
  impressions integer DEFAULT 0 NOT NULL,
  detail_views integer DEFAULT 0 NOT NULL,
  contact_actions integer DEFAULT 0 NOT NULL,
  saves integer DEFAULT 0 NOT NULL,
  conversions integer DEFAULT 0 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.marketplace_listing_delivery_options (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  listing_id uuid NOT NULL,
  delivery_type text NOT NULL,
  country_code text,
  city text,
  region text,
  base_price numeric(14,2) DEFAULT 0 NOT NULL,
  estimated_min_days integer,
  estimated_max_days integer,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.marketplace_listing_inventory (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  listing_id uuid NOT NULL,
  sku text,
  quantity_available integer DEFAULT 0 NOT NULL,
  low_stock_threshold integer DEFAULT 0 NOT NULL,
  reserved_quantity integer DEFAULT 0 NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.marketplace_listings (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  owner_id uuid NOT NULL,
  listing_type text NOT NULL,
  title text NOT NULL,
  description text,
  city text,
  country_code text,
  sport_id uuid,
  status text DEFAULT 'draft'::text NOT NULL,
  is_featured boolean DEFAULT false NOT NULL,
  published_at timestamp with time zone,
  expires_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  location_scope text DEFAULT 'local'::text NOT NULL,
  region text,
  coordinates geography(Point,4326),
  service_radius_km numeric(6,2),
  audience_scope text DEFAULT 'sport_specific'::text NOT NULL,
  seller_id uuid,
  price numeric(14,2),
  currency_code text DEFAULT 'COP'::text,
  is_premium_placement boolean DEFAULT false NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS public.marketplace_order_items (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  order_id uuid NOT NULL,
  listing_id uuid NOT NULL,
  seller_id uuid NOT NULL,
  sku text,
  quantity integer NOT NULL,
  unit_price numeric(14,2) NOT NULL,
  delivery_amount numeric(14,2) DEFAULT 0 NOT NULL,
  seller_fee numeric(14,2) DEFAULT 0 NOT NULL,
  line_total numeric(14,2) GENERATED ALWAYS AS ((((quantity)::numeric * unit_price) + delivery_amount)) STORED,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.marketplace_order_payments (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  order_id uuid NOT NULL,
  provider text NOT NULL,
  provider_payment_id text NOT NULL,
  provider_event_id text,
  amount numeric(14,2) NOT NULL,
  currency_code text NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.marketplace_order_refunds (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  payment_id uuid NOT NULL,
  amount numeric(14,2) NOT NULL,
  provider_refund_id text NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  reason text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.marketplace_orders (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  buyer_id uuid NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  subtotal numeric(14,2) DEFAULT 0 NOT NULL,
  delivery_amount numeric(14,2) DEFAULT 0 NOT NULL,
  platform_fee numeric(14,2) DEFAULT 0 NOT NULL,
  total_amount numeric(14,2) DEFAULT 0 NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  provider text,
  provider_payment_id text,
  provider_event_id text,
  paid_at timestamp with time zone,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.marketplace_promotions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  listing_id uuid NOT NULL,
  promotion_type text NOT NULL,
  starts_at timestamp with time zone DEFAULT now() NOT NULL,
  ends_at timestamp with time zone,
  budget_amount numeric(14,2),
  status text DEFAULT 'active'::text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.marketplace_seller_profiles (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  owner_id uuid NOT NULL,
  organization_id uuid,
  display_name text NOT NULL,
  seller_type text NOT NULL,
  verification_status text DEFAULT 'unverified'::text NOT NULL,
  premium_status text DEFAULT 'free'::text NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  country_code text,
  city text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.marketplace_seller_settlements (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  order_id uuid NOT NULL,
  seller_id uuid NOT NULL,
  gross_amount numeric(14,2) NOT NULL,
  platform_fee numeric(14,2) NOT NULL,
  refunds_amount numeric(14,2) DEFAULT 0 NOT NULL,
  net_amount numeric(14,2) GENERATED ALWAYS AS (((gross_amount - platform_fee) - refunds_amount)) STORED,
  currency_code text NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  provider_payout_id text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.match_results (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  match_id uuid NOT NULL,
  winner_profile_id uuid,
  result_data jsonb DEFAULT '{}'::jsonb NOT NULL,
  submitted_by uuid NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.matches (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  challenge_id uuid,
  sport_id uuid NOT NULL,
  status text DEFAULT 'scheduled'::text NOT NULL,
  scheduled_at timestamp with time zone,
  started_at timestamp with time zone,
  completed_at timestamp with time zone,
  location_name text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.missions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  code text NOT NULL,
  title text NOT NULL,
  description text,
  sport_id uuid,
  mission_type text NOT NULL,
  target jsonb DEFAULT '{}'::jsonb NOT NULL,
  xp_reward integer DEFAULT 0 NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.moderation_actions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  target_type text NOT NULL,
  target_id uuid NOT NULL,
  action_type text NOT NULL,
  reason text,
  actor_profile_id uuid,
  expires_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.notification_deliveries (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  notification_id uuid NOT NULL,
  channel text NOT NULL,
  status text DEFAULT 'queued'::text NOT NULL,
  provider_reference text,
  attempted_at timestamp with time zone,
  delivered_at timestamp with time zone,
  failure_reason text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.notification_devices (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  platform text NOT NULL,
  push_token text,
  device_identifier text,
  is_active boolean DEFAULT true NOT NULL,
  last_seen_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.notification_preferences (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  in_app_enabled boolean DEFAULT true NOT NULL,
  push_enabled boolean DEFAULT true NOT NULL,
  email_enabled boolean DEFAULT true NOT NULL,
  categories jsonb DEFAULT '{}'::jsonb NOT NULL,
  quiet_hours jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  category text NOT NULL,
  type text NOT NULL,
  title text NOT NULL,
  body text,
  action_type text,
  action_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
  source_type text,
  source_id uuid,
  priority text DEFAULT 'normal'::text NOT NULL,
  read_at timestamp with time zone,
  archived_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.organization_activities (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  organization_id uuid NOT NULL,
  location_id uuid,
  sport_id uuid,
  activity_name text NOT NULL,
  activity_type text DEFAULT 'sport'::text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  settings jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.organization_activity_memberships (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  organization_membership_id uuid NOT NULL,
  activity_id uuid NOT NULL,
  role_in_activity text DEFAULT 'participant'::text NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.organization_locations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  organization_id uuid NOT NULL,
  name text NOT NULL,
  address text,
  country_code text,
  city text,
  latitude numeric(9,6),
  longitude numeric(9,6),
  timezone text DEFAULT 'America/Bogota'::text NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.organization_member_roles (
  membership_id uuid NOT NULL,
  role_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.organization_memberships (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  organization_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  membership_type text DEFAULT 'member'::text NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  joined_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.organization_permissions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  permission_key text NOT NULL,
  description text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.organization_resources (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  organization_id uuid NOT NULL,
  location_id uuid,
  sport_id uuid,
  name text NOT NULL,
  resource_type text NOT NULL,
  capacity integer DEFAULT 1 NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.organization_role_permissions (
  role_id uuid NOT NULL,
  permission_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.organization_roles (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  organization_id uuid,
  code text NOT NULL,
  name text NOT NULL,
  description text,
  is_system boolean DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.organizations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  owner_id uuid NOT NULL,
  organization_type text DEFAULT 'club'::text NOT NULL,
  name text NOT NULL,
  slug text,
  description text,
  status text DEFAULT 'active'::text NOT NULL,
  country_code text,
  city text,
  timezone text DEFAULT 'America/Bogota'::text NOT NULL,
  default_currency text DEFAULT 'COP'::text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.pair_profiles (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  sport_id uuid NOT NULL,
  player_1 uuid NOT NULL,
  player_2 uuid NOT NULL,
  ranking_points integer DEFAULT 1000 NOT NULL,
  wins integer DEFAULT 0 NOT NULL,
  losses integer DEFAULT 0 NOT NULL,
  reputation_score integer DEFAULT 100 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.partner_preferences (
  user_id uuid NOT NULL,
  sport_id uuid NOT NULL,
  preferred_level text,
  max_distance_km numeric(5,2) DEFAULT 10 NOT NULL,
  availability text,
  notes text,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.partner_requests (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  sport_id uuid NOT NULL,
  requester_id uuid NOT NULL,
  recipient_id uuid NOT NULL,
  status text DEFAULT 'PENDING'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  responded_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS public.payment_records (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  booking_id uuid NOT NULL,
  provider text NOT NULL,
  provider_payment_id text NOT NULL,
  provider_event_id text,
  amount numeric NOT NULL,
  currency_code text NOT NULL,
  status text NOT NULL,
  payer_profile_id uuid,
  raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  paid_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  refunded_amount numeric DEFAULT 0 NOT NULL
);

CREATE TABLE IF NOT EXISTS public.payment_refunds (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  payment_id uuid NOT NULL,
  amount numeric NOT NULL,
  provider_refund_id text,
  status text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.platform_admins (
  profile_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.platform_security_exceptions (
  key text NOT NULL,
  severity text NOT NULL,
  status text NOT NULL,
  details text NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.platform_test_assertions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  run_id uuid NOT NULL,
  assertion_key text NOT NULL,
  passed boolean NOT NULL,
  detail jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.platform_test_runs (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  suite text NOT NULL,
  status text DEFAULT 'running'::text NOT NULL,
  started_at timestamp with time zone DEFAULT now() NOT NULL,
  finished_at timestamp with time zone,
  summary jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.player_achievements (
  profile_id uuid NOT NULL,
  achievement_id uuid NOT NULL,
  source_id uuid,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  unlocked_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.player_availability (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  sport_id uuid,
  intent text DEFAULT 'match'::text NOT NULL,
  starts_at timestamp with time zone NOT NULL,
  ends_at timestamp with time zone NOT NULL,
  location_name text,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.player_cards (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  card_definition_id uuid NOT NULL,
  source_type text,
  source_id uuid,
  payload jsonb DEFAULT '{}'::jsonb NOT NULL,
  language_code text DEFAULT 'es'::text NOT NULL,
  earned_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.player_progression (
  profile_id uuid NOT NULL,
  total_xp bigint DEFAULT 0 NOT NULL,
  level integer DEFAULT 1 NOT NULL,
  current_title text,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.player_rivalries (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  sport_id uuid NOT NULL,
  player_one_id uuid NOT NULL,
  player_two_id uuid NOT NULL,
  matches_count integer DEFAULT 0 NOT NULL,
  player_one_wins integer DEFAULT 0 NOT NULL,
  player_two_wins integer DEFAULT 0 NOT NULL,
  last_match_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.player_season_progression (
  profile_id uuid NOT NULL,
  season_id uuid NOT NULL,
  sport_id uuid,
  xp_earned bigint DEFAULT 0 NOT NULL,
  matches_played integer DEFAULT 0 NOT NULL,
  wins integer DEFAULT 0 NOT NULL,
  losses integer DEFAULT 0 NOT NULL,
  best_win_streak integer DEFAULT 0 NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.player_sport_streaks (
  profile_id uuid NOT NULL,
  sport_id uuid NOT NULL,
  current_win_streak integer DEFAULT 0 NOT NULL,
  best_win_streak integer DEFAULT 0 NOT NULL,
  last_match_at timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.player_sports (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  sport_id uuid NOT NULL,
  relationship text DEFAULT 'active'::text NOT NULL,
  skill_level text,
  is_primary boolean DEFAULT false NOT NULL,
  is_discoverable boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.profile_locale_preferences (
  profile_id uuid NOT NULL,
  locale_code text NOT NULL,
  timezone text,
  currency_code text,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.profile_locations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  country_code text NOT NULL,
  region text,
  city text,
  neighborhood text,
  coordinates geography(Point,4326),
  search_radius_km numeric(6,2) DEFAULT 25 NOT NULL,
  precision_mode text DEFAULT 'city'::text NOT NULL,
  is_discoverable boolean DEFAULT true NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid NOT NULL,
  username text,
  display_name text NOT NULL,
  avatar_url text,
  country_code text,
  city text,
  bio text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  preferred_language text DEFAULT 'es'::text NOT NULL,
  is_discoverable boolean DEFAULT true NOT NULL,
  player_status text DEFAULT 'active'::text NOT NULL
);

CREATE TABLE IF NOT EXISTS public.promotion_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  promotion_id uuid NOT NULL,
  profile_id uuid,
  event_type text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.promotions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  listing_id uuid NOT NULL,
  promotion_type text NOT NULL,
  status text DEFAULT 'draft'::text NOT NULL,
  starts_at timestamp with time zone,
  ends_at timestamp with time zone,
  budget_amount numeric(12,2),
  currency_code text DEFAULT 'USD'::text NOT NULL,
  targeting jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.provider_availability (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  provider_id uuid NOT NULL,
  organization_id uuid,
  day_of_week smallint,
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  timezone text DEFAULT 'America/Bogota'::text NOT NULL,
  is_available boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.provider_organization_relationships (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  provider_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  membership_id uuid,
  relationship_type text NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  can_manage_own_schedule boolean DEFAULT false NOT NULL,
  can_create_own_services boolean DEFAULT false NOT NULL,
  can_view_own_students boolean DEFAULT true NOT NULL,
  can_manage_own_bookings boolean DEFAULT true NOT NULL,
  starts_on date,
  ends_on date,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.provider_profiles (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  provider_type text DEFAULT 'coach'::text NOT NULL,
  headline text,
  bio text,
  verification_status text DEFAULT 'unverified'::text NOT NULL,
  is_independent boolean DEFAULT true NOT NULL,
  accepts_online boolean DEFAULT false NOT NULL,
  accepts_in_person boolean DEFAULT true NOT NULL,
  default_currency text DEFAULT 'COP'::text NOT NULL,
  timezone text DEFAULT 'America/Bogota'::text NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.provider_service_booking_links (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  provider_service_id uuid NOT NULL,
  bookable_id uuid NOT NULL,
  provider_id uuid,
  organization_id uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.provider_services (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  provider_id uuid,
  organization_id uuid,
  activity_id uuid,
  title text NOT NULL,
  description text,
  service_mode text NOT NULL,
  ownership_type text NOT NULL,
  operational_owner_type text NOT NULL,
  payment_owner_type text NOT NULL,
  duration_minutes integer,
  capacity integer DEFAULT 1 NOT NULL,
  price numeric(12,2) DEFAULT 0 NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.provider_students (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  provider_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  organization_id uuid,
  status text DEFAULT 'active'::text NOT NULL,
  first_session_at timestamp with time zone,
  last_session_at timestamp with time zone,
  notes text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.rate_limit_hits (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  bucket text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.rating_history (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  sport_id uuid NOT NULL,
  source_match_id uuid,
  rating_before numeric(10,2) NOT NULL,
  rating_after numeric(10,2) NOT NULL,
  delta numeric(10,2) NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.recommendation_candidates (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  target_type text NOT NULL,
  target_id uuid NOT NULL,
  sport_id uuid,
  country_code text,
  region text,
  city text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  visibility text DEFAULT 'public'::text NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.recommendation_explanations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  reason_code text NOT NULL,
  reason_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.recommendation_impressions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid,
  candidate_id uuid NOT NULL,
  context_key text NOT NULL,
  score numeric(12,6),
  rank_position integer,
  clicked_at timestamp with time zone,
  converted_at timestamp with time zone,
  dismissed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.recommendation_preferences (
  profile_id uuid NOT NULL,
  preferred_sports jsonb DEFAULT '[]'::jsonb NOT NULL,
  country_code text,
  region text,
  city text,
  discovery_radius_km numeric(10,2),
  allow_online boolean DEFAULT true NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.referral_codes (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  code text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.referrals (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  referrer_id uuid NOT NULL,
  referred_profile_id uuid NOT NULL,
  referral_code_id uuid,
  status text DEFAULT 'registered'::text NOT NULL,
  qualified_at timestamp with time zone,
  rewarded_at timestamp with time zone,
  xp_reward integer DEFAULT 0 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.relevance_feedback (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  feedback_type text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.relevance_rules (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  code text NOT NULL,
  entity_type text NOT NULL,
  rule_type text NOT NULL,
  weight numeric(10,4) DEFAULT 1 NOT NULL,
  config jsonb DEFAULT '{}'::jsonb NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.search_documents (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  title text NOT NULL,
  subtitle text,
  search_text text NOT NULL,
  sport_id uuid,
  country_code text,
  region text,
  city text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  is_online boolean DEFAULT false NOT NULL,
  visibility text DEFAULT 'public'::text NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.seasons (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  sport_id uuid,
  name text NOT NULL,
  status text DEFAULT 'draft'::text NOT NULL,
  starts_at timestamp with time zone,
  ends_at timestamp with time zone,
  rules jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.security_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid,
  event_type text NOT NULL,
  severity text DEFAULT 'info'::text NOT NULL,
  status text DEFAULT 'open'::text NOT NULL,
  source text,
  related_entity_type text,
  related_entity_id uuid,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  resolved_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS public.security_rate_limits (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  scope_type text NOT NULL,
  scope_key text NOT NULL,
  endpoint_key text NOT NULL,
  window_started_at timestamp with time zone NOT NULL,
  request_count integer DEFAULT 0 NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.share_event_actions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  shareable_event_id uuid NOT NULL,
  actor_id uuid,
  platform text NOT NULL,
  action_type text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.share_event_templates (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  code text NOT NULL,
  event_type text NOT NULL,
  language_code text NOT NULL,
  variant_key text NOT NULL,
  title_template text NOT NULL,
  body_template text,
  is_active boolean DEFAULT true NOT NULL,
  weight integer DEFAULT 100 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shareable_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid,
  event_type text NOT NULL,
  source_type text,
  source_id uuid,
  visibility text DEFAULT 'public'::text NOT NULL,
  share_token text DEFAULT encode(gen_random_bytes(16), 'hex'::text) NOT NULL,
  language_code text DEFAULT 'es'::text NOT NULL,
  payload jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  expires_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS public.shop_cart_items (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  cart_id uuid NOT NULL,
  product_id uuid NOT NULL,
  variant_id uuid,
  quantity integer NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_carts (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  status text DEFAULT 'ACTIVE'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_coupons (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  code text NOT NULL,
  discount_type text NOT NULL,
  discount_value numeric(12,2) NOT NULL,
  starts_at timestamp with time zone,
  ends_at timestamp with time zone,
  usage_limit integer,
  usage_count integer DEFAULT 0 NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_customers (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid,
  full_name text NOT NULL,
  document_type text,
  document_number text,
  phone text,
  email text,
  address text,
  notes text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_inventory_adjustments (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  location_id uuid NOT NULL,
  variant_id uuid NOT NULL,
  previous_quantity integer NOT NULL,
  counted_quantity integer NOT NULL,
  delta_quantity integer NOT NULL,
  reason text NOT NULL,
  source_type text DEFAULT 'STOCK_COUNT'::text NOT NULL,
  created_by uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_inventory_levels (
  location_id uuid NOT NULL,
  variant_id uuid NOT NULL,
  stock_quantity integer DEFAULT 0 NOT NULL,
  reserved_quantity integer DEFAULT 0 NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_inventory_movements (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  location_id uuid NOT NULL,
  variant_id uuid NOT NULL,
  movement_type text NOT NULL,
  quantity integer NOT NULL,
  unit_cost numeric,
  source_type text,
  source_id uuid,
  notes text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_inventory_reservations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  order_id uuid NOT NULL,
  variant_id uuid NOT NULL,
  quantity integer NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  expires_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  location_id uuid
);

CREATE TABLE IF NOT EXISTS public.shop_invoices (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  order_id uuid NOT NULL,
  customer_id uuid,
  invoice_number bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  status text DEFAULT 'issued'::text NOT NULL,
  subtotal numeric DEFAULT 0 NOT NULL,
  tax_amount numeric DEFAULT 0 NOT NULL,
  discount_amount numeric DEFAULT 0 NOT NULL,
  total_amount numeric DEFAULT 0 NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  issued_at timestamp with time zone DEFAULT now() NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_location_inventory (
  location_id uuid NOT NULL,
  variant_id uuid NOT NULL,
  quantity integer DEFAULT 0 NOT NULL,
  reserved_quantity integer DEFAULT 0 NOT NULL,
  reorder_level integer DEFAULT 0 NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_locations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  name text NOT NULL,
  code text NOT NULL,
  address text,
  phone text,
  status text DEFAULT 'active'::text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  location_type text DEFAULT 'physical'::text NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_order_items (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  order_id uuid NOT NULL,
  product_id uuid,
  variant_id uuid,
  product_title text NOT NULL,
  variant_title text,
  quantity integer NOT NULL,
  unit_price numeric(12,2) NOT NULL,
  line_total numeric(12,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_order_payments (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  order_id uuid NOT NULL,
  provider text NOT NULL,
  provider_payment_id text NOT NULL,
  provider_event_id text NOT NULL,
  amount numeric NOT NULL,
  currency_code text NOT NULL,
  status text NOT NULL,
  raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  paid_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_orders (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid,
  order_number bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  subtotal numeric(12,2) DEFAULT 0 NOT NULL,
  discount_amount numeric(12,2) DEFAULT 0 NOT NULL,
  shipping_amount numeric(12,2) DEFAULT 0 NOT NULL,
  total_amount numeric(12,2) DEFAULT 0 NOT NULL,
  shipping_data jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  fulfillment_status text DEFAULT 'pending'::text NOT NULL,
  payment_status text DEFAULT 'unpaid'::text NOT NULL,
  tracking_number text,
  coupon_code text,
  fulfillment_location_id uuid,
  sales_channel text DEFAULT 'online'::text NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_pos_payments (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  sale_id uuid NOT NULL,
  payment_method text NOT NULL,
  amount numeric(14,2) NOT NULL,
  reference text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_pos_registers (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  location_id uuid NOT NULL,
  name text NOT NULL,
  code text NOT NULL,
  status text DEFAULT 'open'::text NOT NULL,
  opened_at timestamp with time zone,
  closed_at timestamp with time zone,
  opened_by uuid,
  closed_by uuid,
  opening_float numeric(14,2) DEFAULT 0 NOT NULL,
  closing_total numeric(14,2),
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_pos_sale_items (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  sale_id uuid NOT NULL,
  product_id uuid,
  variant_id uuid,
  product_title text NOT NULL,
  variant_title text,
  quantity integer NOT NULL,
  unit_price numeric(14,2) NOT NULL,
  line_discount numeric(14,2) DEFAULT 0 NOT NULL,
  line_total numeric(14,2) NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_pos_sales (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  order_id uuid NOT NULL,
  location_id uuid NOT NULL,
  register_id uuid NOT NULL,
  customer_id uuid,
  seller_profile_id uuid,
  sale_number bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  sale_channel text DEFAULT 'physical'::text NOT NULL,
  subtotal numeric DEFAULT 0 NOT NULL,
  discount_amount numeric DEFAULT 0 NOT NULL,
  tax_amount numeric DEFAULT 0 NOT NULL,
  total_amount numeric DEFAULT 0 NOT NULL,
  payment_method text,
  invoice_id uuid,
  status text DEFAULT 'completed'::text NOT NULL,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  channel_location_id uuid
);

CREATE TABLE IF NOT EXISTS public.shop_product_variants (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  product_id uuid NOT NULL,
  sku text,
  title text NOT NULL,
  attributes jsonb DEFAULT '{}'::jsonb NOT NULL,
  price numeric(12,2),
  stock_quantity integer DEFAULT 0 NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  reserved_quantity integer DEFAULT 0 NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_products (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  slug text NOT NULL,
  title text NOT NULL,
  description text,
  product_type text DEFAULT 'merchandise'::text NOT NULL,
  status text DEFAULT 'draft'::text NOT NULL,
  base_price numeric(12,2) NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  featured boolean DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  sport_id uuid,
  inventory_tracking boolean DEFAULT true NOT NULL,
  is_preorder boolean DEFAULT false NOT NULL,
  preorder_available_at timestamp with time zone,
  is_limited_edition boolean DEFAULT false NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_registers (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  location_id uuid NOT NULL,
  name text NOT NULL,
  code text NOT NULL,
  status text DEFAULT 'open'::text NOT NULL,
  opened_by uuid,
  opened_at timestamp with time zone,
  closed_by uuid,
  closed_at timestamp with time zone,
  opening_cash numeric DEFAULT 0 NOT NULL,
  closing_cash numeric,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_return_items (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  return_id uuid NOT NULL,
  sale_item_id uuid,
  variant_id uuid,
  quantity integer NOT NULL,
  unit_refund numeric(14,2) NOT NULL,
  line_refund numeric(14,2) NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_returns (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  sale_id uuid NOT NULL,
  location_id uuid NOT NULL,
  customer_id uuid,
  return_number bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  reason text,
  refund_method text,
  refund_amount numeric(14,2) DEFAULT 0 NOT NULL,
  status text DEFAULT 'completed'::text NOT NULL,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS public.shop_staff (
  location_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  role text DEFAULT 'cashier'::text NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.skill_challenges (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  creator_id uuid NOT NULL,
  sport_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  category text NOT NULL,
  difficulty text DEFAULT 'INTERMEDIATE'::text NOT NULL,
  target_votes integer DEFAULT 100 NOT NULL,
  points integer DEFAULT 100 NOT NULL,
  status text DEFAULT 'OPEN'::text NOT NULL,
  expires_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.skill_comments (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  submission_id uuid NOT NULL,
  user_id uuid NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.skill_submissions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  challenge_id uuid NOT NULL,
  user_id uuid NOT NULL,
  video_url text NOT NULL,
  caption text,
  votes integer DEFAULT 0 NOT NULL,
  skill_points_awarded integer DEFAULT 0 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.skill_votes (
  submission_id uuid NOT NULL,
  user_id uuid NOT NULL,
  value integer DEFAULT 1 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.social_comments (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  post_id uuid NOT NULL,
  author_profile_id uuid NOT NULL,
  parent_comment_id uuid,
  body text NOT NULL,
  status text DEFAULT 'visible'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.social_follows (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  follower_profile_id uuid NOT NULL,
  followed_profile_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.social_posts (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  author_profile_id uuid NOT NULL,
  sport_id uuid,
  post_type text DEFAULT 'text'::text NOT NULL,
  body text,
  visibility text DEFAULT 'public'::text NOT NULL,
  source_type text,
  source_id uuid,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.social_reactions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  post_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  reaction_type text DEFAULT 'like'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.social_share_actions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  share_card_id uuid NOT NULL,
  profile_id uuid,
  channel text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.social_share_cards (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid,
  source_type text NOT NULL,
  source_id uuid NOT NULL,
  template_key text NOT NULL,
  title text,
  subtitle text,
  payload jsonb DEFAULT '{}'::jsonb NOT NULL,
  image_url text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.social_share_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  challenge_id uuid,
  share_link_id uuid,
  actor_id uuid,
  platform text NOT NULL,
  event_type text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.sport_rankings (
  profile_id uuid NOT NULL,
  sport_id uuid NOT NULL,
  rating numeric(10,2) DEFAULT 1000 NOT NULL,
  wins integer DEFAULT 0 NOT NULL,
  losses integer DEFAULT 0 NOT NULL,
  matches_played integer DEFAULT 0 NOT NULL,
  rank integer,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.sports (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  slug text NOT NULL,
  name text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  icon text DEFAULT '🏅'::text,
  color text DEFAULT '#64748B'::text,
  team_size integer
);

CREATE TABLE IF NOT EXISTS public.support_ticket_messages (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  ticket_id uuid NOT NULL,
  author_profile_id uuid,
  body text NOT NULL,
  is_internal boolean DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  requester_profile_id uuid NOT NULL,
  category text NOT NULL,
  subject text NOT NULL,
  description text NOT NULL,
  priority text DEFAULT 'normal'::text NOT NULL,
  status text DEFAULT 'open'::text NOT NULL,
  assigned_to uuid,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.supported_locales (
  code text NOT NULL,
  name text NOT NULL,
  native_name text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  is_default boolean DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.system_health_checks (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  check_key text NOT NULL,
  status text NOT NULL,
  latency_ms integer,
  details jsonb DEFAULT '{}'::jsonb NOT NULL,
  checked_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tournament_categories (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  tournament_id uuid NOT NULL,
  name text NOT NULL,
  description text,
  participant_mode text NOT NULL,
  capacity integer,
  entry_fee numeric(14,2),
  status text DEFAULT 'open'::text NOT NULL,
  rules jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tournament_checkins (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  entry_id uuid NOT NULL,
  profile_id uuid,
  method text DEFAULT 'manual'::text NOT NULL,
  checked_in_by uuid,
  checked_in_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tournament_entries (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  tournament_id uuid NOT NULL,
  category_id uuid NOT NULL,
  entry_type text NOT NULL,
  captain_profile_id uuid,
  status text DEFAULT 'pending'::text NOT NULL,
  seed integer,
  checked_in_at timestamp with time zone,
  registration_data jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tournament_entry_members (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  entry_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  role text DEFAULT 'member'::text NOT NULL,
  status text DEFAULT 'confirmed'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tournament_fixtures (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  tournament_id uuid NOT NULL,
  category_id uuid,
  stage_id uuid,
  group_id uuid,
  match_id uuid,
  slot integer,
  round_number integer,
  side_a_entry_id uuid,
  side_b_entry_id uuid,
  winner_entry_id uuid,
  next_fixture_id uuid,
  status text DEFAULT 'scheduled'::text NOT NULL,
  scheduled_at timestamp with time zone,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tournament_group_entries (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  group_id uuid NOT NULL,
  entry_id uuid NOT NULL,
  points numeric(10,2) DEFAULT 0 NOT NULL,
  played integer DEFAULT 0 NOT NULL,
  wins integer DEFAULT 0 NOT NULL,
  losses integer DEFAULT 0 NOT NULL,
  score_for numeric(10,2) DEFAULT 0 NOT NULL,
  score_against numeric(10,2) DEFAULT 0 NOT NULL,
  rank integer,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tournament_groups (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  stage_id uuid NOT NULL,
  name text NOT NULL,
  group_order integer DEFAULT 1 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tournament_prizes (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  tournament_id uuid NOT NULL,
  category_id uuid,
  "position" integer NOT NULL,
  title text,
  prize_type text NOT NULL,
  value numeric(14,2),
  currency_code text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tournament_registration_payments (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  entry_id uuid NOT NULL,
  amount_due numeric(14,2) DEFAULT 0 NOT NULL,
  amount_paid numeric(14,2) DEFAULT 0 NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  status text DEFAULT 'unpaid'::text NOT NULL,
  paid_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tournament_sponsors (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  tournament_id uuid NOT NULL,
  name text NOT NULL,
  tier text,
  website text,
  logo_url text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tournament_stages (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  tournament_id uuid NOT NULL,
  category_id uuid,
  name text NOT NULL,
  stage_type text NOT NULL,
  stage_order integer DEFAULT 1 NOT NULL,
  status text DEFAULT 'pending'::text NOT NULL,
  rules jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.tournaments (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  organization_id uuid,
  organizer_profile_id uuid,
  sport_id uuid,
  title text NOT NULL,
  slug text,
  description text,
  format_type text NOT NULL,
  participant_mode text NOT NULL,
  visibility text DEFAULT 'public'::text NOT NULL,
  status text DEFAULT 'draft'::text NOT NULL,
  registration_opens_at timestamp with time zone,
  registration_closes_at timestamp with time zone,
  starts_at timestamp with time zone,
  ends_at timestamp with time zone,
  location_name text,
  location_id uuid,
  capacity integer,
  entry_fee numeric(14,2) DEFAULT 0 NOT NULL,
  currency_code text DEFAULT 'COP'::text NOT NULL,
  cancellation_policy jsonb DEFAULT '{}'::jsonb NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.user_blocks (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  blocker_profile_id uuid NOT NULL,
  blocked_profile_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.user_missions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  mission_id uuid NOT NULL,
  progress numeric DEFAULT 0 NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  started_at timestamp with time zone DEFAULT now() NOT NULL,
  completed_at timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.weekly_challenge_participants (
  participant_id text NOT NULL,
  challenge_id text NOT NULL,
  started_at date DEFAULT CURRENT_DATE NOT NULL,
  status text DEFAULT 'active'::text NOT NULL,
  completion_percentage integer DEFAULT 0 NOT NULL,
  submitted_days jsonb DEFAULT '[]'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.weekly_challenge_submissions (
  id bigint GENERATED BY DEFAULT AS IDENTITY NOT NULL,
  participant_id text NOT NULL,
  challenge_id text NOT NULL,
  day integer NOT NULL,
  note text NOT NULL,
  submitted_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.xp_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  source_type text NOT NULL,
  source_id uuid,
  amount integer NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.zz_probe_cards (
  id integer
);


-- ============================================================================
-- LLAVES PRIMARIAS Y RESTRICCIONES UNIQUE (299)
-- ============================================================================

ALTER TABLE public.account_security_devices ADD CONSTRAINT account_security_devices_pkey PRIMARY KEY (id);
ALTER TABLE public.account_security_events ADD CONSTRAINT account_security_events_pkey PRIMARY KEY (id);
ALTER TABLE public.achievements ADD CONSTRAINT achievements_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_coach_interactions ADD CONSTRAINT ai_coach_interactions_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_conversations ADD CONSTRAINT ai_conversations_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_daily_coach_sessions ADD CONSTRAINT ai_daily_coach_sessions_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_evolution_agent_performance ADD CONSTRAINT ai_evolution_agent_performance_pkey PRIMARY KEY (role);
ALTER TABLE public.ai_evolution_council_reviews ADD CONSTRAINT ai_evolution_council_reviews_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_evolution_evaluations ADD CONSTRAINT ai_evolution_evaluations_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_evolution_locks ADD CONSTRAINT ai_evolution_locks_pkey PRIMARY KEY (lock_key);
ALTER TABLE public.ai_evolution_memory ADD CONSTRAINT ai_evolution_memory_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_evolution_outcomes ADD CONSTRAINT ai_evolution_outcomes_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_evolution_proposals ADD CONSTRAINT ai_evolution_proposals_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_evolution_runs ADD CONSTRAINT ai_evolution_runs_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_memory_notes ADD CONSTRAINT ai_memory_notes_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_messages ADD CONSTRAINT ai_messages_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_policy_evaluations ADD CONSTRAINT ai_policy_evaluations_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_policy_events ADD CONSTRAINT ai_policy_events_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_policy_versions ADD CONSTRAINT ai_policy_versions_pkey PRIMARY KEY (version);
ALTER TABLE public.ai_recommendation_outcomes ADD CONSTRAINT ai_recommendation_outcomes_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_request_reservations ADD CONSTRAINT ai_request_reservations_pkey PRIMARY KEY (id);
ALTER TABLE public.ai_usage_events ADD CONSTRAINT ai_usage_events_pkey PRIMARY KEY (id);
ALTER TABLE public.analytics_daily_metrics ADD CONSTRAINT analytics_daily_metrics_pkey PRIMARY KEY (id);
ALTER TABLE public.analytics_events ADD CONSTRAINT analytics_events_pkey PRIMARY KEY (id);
ALTER TABLE public.audit_logs ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);
ALTER TABLE public.background_job_runs ADD CONSTRAINT background_job_runs_pkey PRIMARY KEY (id);
ALTER TABLE public.billing_entitlements ADD CONSTRAINT billing_entitlements_pkey PRIMARY KEY (id);
ALTER TABLE public.billing_invoices ADD CONSTRAINT billing_invoices_pkey PRIMARY KEY (id);
ALTER TABLE public.billing_plan_features ADD CONSTRAINT billing_plan_features_pkey PRIMARY KEY (id);
ALTER TABLE public.billing_plans ADD CONSTRAINT billing_plans_pkey PRIMARY KEY (id);
ALTER TABLE public.billing_subscriptions ADD CONSTRAINT billing_subscriptions_pkey PRIMARY KEY (id);
ALTER TABLE public.billing_usage_events ADD CONSTRAINT billing_usage_events_pkey PRIMARY KEY (id);
ALTER TABLE public.bookable_entities ADD CONSTRAINT bookable_entities_pkey PRIMARY KEY (id);
ALTER TABLE public.booking_availability_rules ADD CONSTRAINT booking_availability_rules_pkey PRIMARY KEY (id);
ALTER TABLE public.booking_blackouts ADD CONSTRAINT booking_blackouts_pkey PRIMARY KEY (id);
ALTER TABLE public.booking_dependencies ADD CONSTRAINT booking_dependencies_pkey PRIMARY KEY (id);
ALTER TABLE public.booking_finance_links ADD CONSTRAINT booking_finance_links_pkey PRIMARY KEY (id);
ALTER TABLE public.booking_groups ADD CONSTRAINT booking_groups_pkey PRIMARY KEY (id);
ALTER TABLE public.booking_payment_records ADD CONSTRAINT booking_payment_records_pkey PRIMARY KEY (id);
ALTER TABLE public.booking_policies ADD CONSTRAINT booking_policies_pkey PRIMARY KEY (id);
ALTER TABLE public.booking_waitlist ADD CONSTRAINT booking_waitlist_pkey PRIMARY KEY (id);
ALTER TABLE public.bookings ADD CONSTRAINT bookings_pkey PRIMARY KEY (id);
ALTER TABLE public.card_definitions ADD CONSTRAINT card_definitions_pkey PRIMARY KEY (id);
ALTER TABLE public.card_delivery_failures ADD CONSTRAINT card_delivery_failures_pkey PRIMARY KEY (id);
ALTER TABLE public.challenge_card_stakes ADD CONSTRAINT challenge_card_stakes_pkey PRIMARY KEY (id);
ALTER TABLE public.challenge_invitations ADD CONSTRAINT challenge_invitations_pkey PRIMARY KEY (id);
ALTER TABLE public.challenge_participants ADD CONSTRAINT challenge_participants_pkey PRIMARY KEY (challenge_id, profile_id);
ALTER TABLE public.challenge_share_links ADD CONSTRAINT challenge_share_links_pkey PRIMARY KEY (id);
ALTER TABLE public.challenges ADD CONSTRAINT challenges_pkey PRIMARY KEY (id);
ALTER TABLE public.content_reports ADD CONSTRAINT content_reports_pkey PRIMARY KEY (id);
ALTER TABLE public.conversation_messages ADD CONSTRAINT conversation_messages_pkey PRIMARY KEY (id);
ALTER TABLE public.conversation_participants ADD CONSTRAINT conversation_participants_pkey PRIMARY KEY (conversation_id, profile_id);
ALTER TABLE public.conversations ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);
ALTER TABLE public.data_retention_policies ADD CONSTRAINT data_retention_policies_pkey PRIMARY KEY (id);
ALTER TABLE public.discovery_blocks ADD CONSTRAINT discovery_blocks_pkey PRIMARY KEY (id);
ALTER TABLE public.discovery_controls ADD CONSTRAINT discovery_controls_pkey PRIMARY KEY (id);
ALTER TABLE public.discovery_events ADD CONSTRAINT discovery_events_pkey PRIMARY KEY (id);
ALTER TABLE public.discovery_preferences ADD CONSTRAINT discovery_preferences_pkey PRIMARY KEY (id);
ALTER TABLE public.dynasty_card_transfers ADD CONSTRAINT dynasty_card_transfers_pkey PRIMARY KEY (id);
ALTER TABLE public.dynasty_cards ADD CONSTRAINT dynasty_cards_pkey PRIMARY KEY (id);
ALTER TABLE public.dynasty_mission_rewards ADD CONSTRAINT dynasty_mission_rewards_pkey PRIMARY KEY (user_mission_id);
ALTER TABLE public.dynasty_progression_events ADD CONSTRAINT dynasty_progression_events_pkey PRIMARY KEY (id);
ALTER TABLE public.entity_availability ADD CONSTRAINT entity_availability_pkey PRIMARY KEY (id);
ALTER TABLE public.entity_sports ADD CONSTRAINT entity_sports_pkey PRIMARY KEY (id);
ALTER TABLE public.finance_accounts ADD CONSTRAINT finance_accounts_pkey PRIMARY KEY (id);
ALTER TABLE public.finance_categories ADD CONSTRAINT finance_categories_pkey PRIMARY KEY (id);
ALTER TABLE public.finance_invoices ADD CONSTRAINT finance_invoices_pkey PRIMARY KEY (id);
ALTER TABLE public.finance_recurring_items ADD CONSTRAINT finance_recurring_items_pkey PRIMARY KEY (id);
ALTER TABLE public.finance_transactions ADD CONSTRAINT finance_transactions_pkey PRIMARY KEY (id);
ALTER TABLE public.intelligence_signals ADD CONSTRAINT intelligence_signals_pkey PRIMARY KEY (id);
ALTER TABLE public.locale_translations ADD CONSTRAINT locale_translations_pkey PRIMARY KEY (id);
ALTER TABLE public.marketplace_item_returns ADD CONSTRAINT marketplace_item_returns_pkey PRIMARY KEY (id);
ALTER TABLE public.marketplace_listing_analytics_daily ADD CONSTRAINT marketplace_listing_analytics_daily_pkey PRIMARY KEY (id);
ALTER TABLE public.marketplace_listing_delivery_options ADD CONSTRAINT marketplace_listing_delivery_options_pkey PRIMARY KEY (id);
ALTER TABLE public.marketplace_listing_inventory ADD CONSTRAINT marketplace_listing_inventory_pkey PRIMARY KEY (id);
ALTER TABLE public.marketplace_listings ADD CONSTRAINT marketplace_listings_pkey PRIMARY KEY (id);
ALTER TABLE public.marketplace_order_items ADD CONSTRAINT marketplace_order_items_pkey PRIMARY KEY (id);
ALTER TABLE public.marketplace_order_payments ADD CONSTRAINT marketplace_order_payments_pkey PRIMARY KEY (id);
ALTER TABLE public.marketplace_order_refunds ADD CONSTRAINT marketplace_order_refunds_pkey PRIMARY KEY (id);
ALTER TABLE public.marketplace_orders ADD CONSTRAINT marketplace_orders_pkey PRIMARY KEY (id);
ALTER TABLE public.marketplace_promotions ADD CONSTRAINT marketplace_promotions_pkey PRIMARY KEY (id);
ALTER TABLE public.marketplace_seller_profiles ADD CONSTRAINT marketplace_seller_profiles_pkey PRIMARY KEY (id);
ALTER TABLE public.marketplace_seller_settlements ADD CONSTRAINT marketplace_seller_settlements_pkey PRIMARY KEY (id);
ALTER TABLE public.match_results ADD CONSTRAINT match_results_pkey PRIMARY KEY (id);
ALTER TABLE public.matches ADD CONSTRAINT matches_pkey PRIMARY KEY (id);
ALTER TABLE public.missions ADD CONSTRAINT missions_pkey PRIMARY KEY (id);
ALTER TABLE public.moderation_actions ADD CONSTRAINT moderation_actions_pkey PRIMARY KEY (id);
ALTER TABLE public.notification_deliveries ADD CONSTRAINT notification_deliveries_pkey PRIMARY KEY (id);
ALTER TABLE public.notification_devices ADD CONSTRAINT notification_devices_pkey PRIMARY KEY (id);
ALTER TABLE public.notification_preferences ADD CONSTRAINT notification_preferences_pkey PRIMARY KEY (id);
ALTER TABLE public.notifications ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);
ALTER TABLE public.organization_activities ADD CONSTRAINT organization_activities_pkey PRIMARY KEY (id);
ALTER TABLE public.organization_activity_memberships ADD CONSTRAINT organization_activity_memberships_pkey PRIMARY KEY (id);
ALTER TABLE public.organization_locations ADD CONSTRAINT organization_locations_pkey PRIMARY KEY (id);
ALTER TABLE public.organization_member_roles ADD CONSTRAINT organization_member_roles_pkey PRIMARY KEY (membership_id, role_id);
ALTER TABLE public.organization_memberships ADD CONSTRAINT organization_memberships_pkey PRIMARY KEY (id);
ALTER TABLE public.organization_permissions ADD CONSTRAINT organization_permissions_pkey PRIMARY KEY (id);
ALTER TABLE public.organization_resources ADD CONSTRAINT organization_resources_pkey PRIMARY KEY (id);
ALTER TABLE public.organization_role_permissions ADD CONSTRAINT organization_role_permissions_pkey PRIMARY KEY (role_id, permission_id);
ALTER TABLE public.organization_roles ADD CONSTRAINT organization_roles_pkey PRIMARY KEY (id);
ALTER TABLE public.organizations ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);
ALTER TABLE public.pair_profiles ADD CONSTRAINT pair_profiles_pkey PRIMARY KEY (id);
ALTER TABLE public.partner_preferences ADD CONSTRAINT partner_preferences_pkey PRIMARY KEY (user_id, sport_id);
ALTER TABLE public.partner_requests ADD CONSTRAINT partner_requests_pkey PRIMARY KEY (id);
ALTER TABLE public.payment_records ADD CONSTRAINT payment_records_pkey PRIMARY KEY (id);
ALTER TABLE public.payment_refunds ADD CONSTRAINT payment_refunds_pkey PRIMARY KEY (id);
ALTER TABLE public.platform_admins ADD CONSTRAINT platform_admins_pkey PRIMARY KEY (profile_id);
ALTER TABLE public.platform_security_exceptions ADD CONSTRAINT platform_security_exceptions_pkey PRIMARY KEY (key);
ALTER TABLE public.platform_test_assertions ADD CONSTRAINT platform_test_assertions_pkey PRIMARY KEY (id);
ALTER TABLE public.platform_test_runs ADD CONSTRAINT platform_test_runs_pkey PRIMARY KEY (id);
ALTER TABLE public.player_achievements ADD CONSTRAINT player_achievements_pkey PRIMARY KEY (profile_id, achievement_id);
ALTER TABLE public.player_availability ADD CONSTRAINT player_availability_pkey PRIMARY KEY (id);
ALTER TABLE public.player_cards ADD CONSTRAINT player_cards_pkey PRIMARY KEY (id);
ALTER TABLE public.player_progression ADD CONSTRAINT player_progression_pkey PRIMARY KEY (profile_id);
ALTER TABLE public.player_rivalries ADD CONSTRAINT player_rivalries_pkey PRIMARY KEY (id);
ALTER TABLE public.player_season_progression ADD CONSTRAINT player_season_progression_pkey PRIMARY KEY (profile_id, season_id);
ALTER TABLE public.player_sport_streaks ADD CONSTRAINT player_sport_streaks_pkey PRIMARY KEY (profile_id, sport_id);
ALTER TABLE public.player_sports ADD CONSTRAINT player_sports_pkey PRIMARY KEY (id);
ALTER TABLE public.profile_locale_preferences ADD CONSTRAINT profile_locale_preferences_pkey PRIMARY KEY (profile_id);
ALTER TABLE public.profile_locations ADD CONSTRAINT profile_locations_pkey PRIMARY KEY (id);
ALTER TABLE public.profiles ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);
ALTER TABLE public.promotion_events ADD CONSTRAINT promotion_events_pkey PRIMARY KEY (id);
ALTER TABLE public.promotions ADD CONSTRAINT promotions_pkey PRIMARY KEY (id);
ALTER TABLE public.provider_availability ADD CONSTRAINT provider_availability_pkey PRIMARY KEY (id);
ALTER TABLE public.provider_organization_relationships ADD CONSTRAINT provider_organization_relationships_pkey PRIMARY KEY (id);
ALTER TABLE public.provider_profiles ADD CONSTRAINT provider_profiles_pkey PRIMARY KEY (id);
ALTER TABLE public.provider_service_booking_links ADD CONSTRAINT provider_service_booking_links_pkey PRIMARY KEY (id);
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_pkey PRIMARY KEY (id);
ALTER TABLE public.provider_students ADD CONSTRAINT provider_students_pkey PRIMARY KEY (id);
ALTER TABLE public.rate_limit_hits ADD CONSTRAINT rate_limit_hits_pkey PRIMARY KEY (id);
ALTER TABLE public.rating_history ADD CONSTRAINT rating_history_pkey PRIMARY KEY (id);
ALTER TABLE public.recommendation_candidates ADD CONSTRAINT recommendation_candidates_pkey PRIMARY KEY (id);
ALTER TABLE public.recommendation_explanations ADD CONSTRAINT recommendation_explanations_pkey PRIMARY KEY (id);
ALTER TABLE public.recommendation_impressions ADD CONSTRAINT recommendation_impressions_pkey PRIMARY KEY (id);
ALTER TABLE public.recommendation_preferences ADD CONSTRAINT recommendation_preferences_pkey PRIMARY KEY (profile_id);
ALTER TABLE public.referral_codes ADD CONSTRAINT referral_codes_pkey PRIMARY KEY (id);
ALTER TABLE public.referrals ADD CONSTRAINT referrals_pkey PRIMARY KEY (id);
ALTER TABLE public.relevance_feedback ADD CONSTRAINT relevance_feedback_pkey PRIMARY KEY (id);
ALTER TABLE public.relevance_rules ADD CONSTRAINT relevance_rules_pkey PRIMARY KEY (id);
ALTER TABLE public.search_documents ADD CONSTRAINT search_documents_pkey PRIMARY KEY (id);
ALTER TABLE public.seasons ADD CONSTRAINT seasons_pkey PRIMARY KEY (id);
ALTER TABLE public.security_events ADD CONSTRAINT security_events_pkey PRIMARY KEY (id);
ALTER TABLE public.security_rate_limits ADD CONSTRAINT security_rate_limits_pkey PRIMARY KEY (id);
ALTER TABLE public.share_event_actions ADD CONSTRAINT share_event_actions_pkey PRIMARY KEY (id);
ALTER TABLE public.share_event_templates ADD CONSTRAINT share_event_templates_pkey PRIMARY KEY (id);
ALTER TABLE public.shareable_events ADD CONSTRAINT shareable_events_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_cart_items ADD CONSTRAINT shop_cart_items_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_carts ADD CONSTRAINT shop_carts_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_coupons ADD CONSTRAINT shop_coupons_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_customers ADD CONSTRAINT shop_customers_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_inventory_adjustments ADD CONSTRAINT shop_inventory_adjustments_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_inventory_levels ADD CONSTRAINT shop_inventory_levels_pkey PRIMARY KEY (location_id, variant_id);
ALTER TABLE public.shop_inventory_movements ADD CONSTRAINT shop_inventory_movements_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_inventory_reservations ADD CONSTRAINT shop_inventory_reservations_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_invoices ADD CONSTRAINT shop_invoices_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_location_inventory ADD CONSTRAINT shop_location_inventory_pkey PRIMARY KEY (location_id, variant_id);
ALTER TABLE public.shop_locations ADD CONSTRAINT shop_locations_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_order_items ADD CONSTRAINT shop_order_items_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_order_payments ADD CONSTRAINT shop_order_payments_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_orders ADD CONSTRAINT shop_orders_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_pos_payments ADD CONSTRAINT shop_pos_payments_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_pos_registers ADD CONSTRAINT shop_pos_registers_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_pos_sale_items ADD CONSTRAINT shop_pos_sale_items_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_pos_sales ADD CONSTRAINT shop_pos_sales_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_product_variants ADD CONSTRAINT shop_product_variants_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_products ADD CONSTRAINT shop_products_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_registers ADD CONSTRAINT shop_registers_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_return_items ADD CONSTRAINT shop_return_items_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_returns ADD CONSTRAINT shop_returns_pkey PRIMARY KEY (id);
ALTER TABLE public.shop_staff ADD CONSTRAINT shop_staff_pkey PRIMARY KEY (location_id, profile_id);
ALTER TABLE public.skill_challenges ADD CONSTRAINT skill_challenges_pkey PRIMARY KEY (id);
ALTER TABLE public.skill_comments ADD CONSTRAINT skill_comments_pkey PRIMARY KEY (id);
ALTER TABLE public.skill_submissions ADD CONSTRAINT skill_submissions_pkey PRIMARY KEY (id);
ALTER TABLE public.skill_votes ADD CONSTRAINT skill_votes_pkey PRIMARY KEY (submission_id, user_id);
ALTER TABLE public.social_comments ADD CONSTRAINT social_comments_pkey PRIMARY KEY (id);
ALTER TABLE public.social_follows ADD CONSTRAINT social_follows_pkey PRIMARY KEY (id);
ALTER TABLE public.social_posts ADD CONSTRAINT social_posts_pkey PRIMARY KEY (id);
ALTER TABLE public.social_reactions ADD CONSTRAINT social_reactions_pkey PRIMARY KEY (id);
ALTER TABLE public.social_share_actions ADD CONSTRAINT social_share_actions_pkey PRIMARY KEY (id);
ALTER TABLE public.social_share_cards ADD CONSTRAINT social_share_cards_pkey PRIMARY KEY (id);
ALTER TABLE public.social_share_events ADD CONSTRAINT social_share_events_pkey PRIMARY KEY (id);
ALTER TABLE public.sport_rankings ADD CONSTRAINT sport_rankings_pkey PRIMARY KEY (profile_id, sport_id);
ALTER TABLE public.sports ADD CONSTRAINT sports_pkey PRIMARY KEY (id);
ALTER TABLE public.support_ticket_messages ADD CONSTRAINT support_ticket_messages_pkey PRIMARY KEY (id);
ALTER TABLE public.support_tickets ADD CONSTRAINT support_tickets_pkey PRIMARY KEY (id);
ALTER TABLE public.supported_locales ADD CONSTRAINT supported_locales_pkey PRIMARY KEY (code);
ALTER TABLE public.system_health_checks ADD CONSTRAINT system_health_checks_pkey PRIMARY KEY (id);
ALTER TABLE public.tournament_categories ADD CONSTRAINT tournament_categories_pkey PRIMARY KEY (id);
ALTER TABLE public.tournament_checkins ADD CONSTRAINT tournament_checkins_pkey PRIMARY KEY (id);
ALTER TABLE public.tournament_entries ADD CONSTRAINT tournament_entries_pkey PRIMARY KEY (id);
ALTER TABLE public.tournament_entry_members ADD CONSTRAINT tournament_entry_members_pkey PRIMARY KEY (id);
ALTER TABLE public.tournament_fixtures ADD CONSTRAINT tournament_fixtures_pkey PRIMARY KEY (id);
ALTER TABLE public.tournament_group_entries ADD CONSTRAINT tournament_group_entries_pkey PRIMARY KEY (id);
ALTER TABLE public.tournament_groups ADD CONSTRAINT tournament_groups_pkey PRIMARY KEY (id);
ALTER TABLE public.tournament_prizes ADD CONSTRAINT tournament_prizes_pkey PRIMARY KEY (id);
ALTER TABLE public.tournament_registration_payments ADD CONSTRAINT tournament_registration_payments_pkey PRIMARY KEY (id);
ALTER TABLE public.tournament_sponsors ADD CONSTRAINT tournament_sponsors_pkey PRIMARY KEY (id);
ALTER TABLE public.tournament_stages ADD CONSTRAINT tournament_stages_pkey PRIMARY KEY (id);
ALTER TABLE public.tournaments ADD CONSTRAINT tournaments_pkey PRIMARY KEY (id);
ALTER TABLE public.user_blocks ADD CONSTRAINT user_blocks_pkey PRIMARY KEY (id);
ALTER TABLE public.user_missions ADD CONSTRAINT user_missions_pkey PRIMARY KEY (id);
ALTER TABLE public.weekly_challenge_participants ADD CONSTRAINT weekly_challenge_participants_pkey PRIMARY KEY (participant_id);
ALTER TABLE public.weekly_challenge_submissions ADD CONSTRAINT weekly_challenge_submissions_pkey PRIMARY KEY (id);
ALTER TABLE public.xp_events ADD CONSTRAINT xp_events_pkey PRIMARY KEY (id);
ALTER TABLE public.account_security_devices ADD CONSTRAINT account_security_devices_profile_id_device_fingerprint_hash_key UNIQUE (profile_id, device_fingerprint_hash);
ALTER TABLE public.achievements ADD CONSTRAINT achievements_code_key UNIQUE (code);
ALTER TABLE public.ai_daily_coach_sessions ADD CONSTRAINT ai_daily_coach_sessions_profile_id_session_date_mode_key UNIQUE (profile_id, session_date, mode);
ALTER TABLE public.ai_evolution_council_reviews ADD CONSTRAINT ai_evolution_council_reviews_proposal_id_role_key UNIQUE (proposal_id, role);
ALTER TABLE public.ai_evolution_outcomes ADD CONSTRAINT ai_evolution_outcomes_proposal_id_key UNIQUE (proposal_id);
ALTER TABLE public.ai_memory_notes ADD CONSTRAINT ai_memory_notes_profile_id_scope_note_key_key UNIQUE (profile_id, scope, note_key);
ALTER TABLE public.analytics_daily_metrics ADD CONSTRAINT analytics_daily_metrics_metric_date_metric_scope_profile_id_key UNIQUE (metric_date, metric_scope, profile_id, organization_id, seller_profile_id, sport_id, metric_key);
ALTER TABLE public.billing_plan_features ADD CONSTRAINT billing_plan_features_plan_id_feature_key_key UNIQUE (plan_id, feature_key);
ALTER TABLE public.billing_plans ADD CONSTRAINT billing_plans_code_key UNIQUE (code);
ALTER TABLE public.booking_dependencies ADD CONSTRAINT booking_dependencies_parent_bookable_id_required_bookable_i_key UNIQUE (parent_bookable_id, required_bookable_id);
ALTER TABLE public.booking_finance_links ADD CONSTRAINT booking_finance_links_booking_id_finance_transaction_id_key UNIQUE (booking_id, finance_transaction_id);
ALTER TABLE public.booking_payment_records ADD CONSTRAINT booking_payment_records_booking_id_key UNIQUE (booking_id);
ALTER TABLE public.booking_policies ADD CONSTRAINT booking_policies_bookable_id_key UNIQUE (bookable_id);
ALTER TABLE public.booking_waitlist ADD CONSTRAINT booking_waitlist_bookable_id_profile_id_requested_starts_at_key UNIQUE (bookable_id, profile_id, requested_starts_at, requested_ends_at);
ALTER TABLE public.card_definitions ADD CONSTRAINT card_definitions_code_key UNIQUE (code);
ALTER TABLE public.challenge_share_links ADD CONSTRAINT challenge_share_links_token_key UNIQUE (token);
ALTER TABLE public.data_retention_policies ADD CONSTRAINT data_retention_policies_entity_type_key UNIQUE (entity_type);
ALTER TABLE public.discovery_blocks ADD CONSTRAINT discovery_blocks_profile_id_entity_type_entity_id_block_sco_key UNIQUE (profile_id, entity_type, entity_id, block_scope);
ALTER TABLE public.discovery_controls ADD CONSTRAINT discovery_controls_profile_id_key UNIQUE (profile_id);
ALTER TABLE public.discovery_preferences ADD CONSTRAINT discovery_preferences_profile_id_key UNIQUE (profile_id);
ALTER TABLE public.dynasty_progression_events ADD CONSTRAINT dynasty_progression_events_profile_id_source_type_source_id_key UNIQUE (profile_id, source_type, source_id);
ALTER TABLE public.entity_availability ADD CONSTRAINT entity_availability_entity_type_entity_id_key UNIQUE (entity_type, entity_id);
ALTER TABLE public.entity_sports ADD CONSTRAINT entity_sports_entity_type_entity_id_sport_id_key UNIQUE (entity_type, entity_id, sport_id);
ALTER TABLE public.locale_translations ADD CONSTRAINT locale_translations_locale_code_namespace_translation_key_key UNIQUE (locale_code, namespace, translation_key);
ALTER TABLE public.marketplace_listing_analytics_daily ADD CONSTRAINT marketplace_listing_analytics_daily_listing_id_metric_date_key UNIQUE (listing_id, metric_date);
ALTER TABLE public.marketplace_listing_inventory ADD CONSTRAINT marketplace_listing_inventory_listing_id_key UNIQUE (listing_id);
ALTER TABLE public.marketplace_order_payments ADD CONSTRAINT marketplace_order_payments_provider_provider_event_id_key UNIQUE (provider, provider_event_id);
ALTER TABLE public.marketplace_order_payments ADD CONSTRAINT marketplace_order_payments_provider_provider_payment_id_key UNIQUE (provider, provider_payment_id);
ALTER TABLE public.marketplace_order_refunds ADD CONSTRAINT marketplace_order_refunds_payment_id_provider_refund_id_key UNIQUE (payment_id, provider_refund_id);
ALTER TABLE public.marketplace_seller_settlements ADD CONSTRAINT marketplace_seller_settlements_order_id_seller_id_key UNIQUE (order_id, seller_id);
ALTER TABLE public.matches ADD CONSTRAINT matches_challenge_id_key UNIQUE (challenge_id);
ALTER TABLE public.missions ADD CONSTRAINT missions_code_key UNIQUE (code);
ALTER TABLE public.notification_devices ADD CONSTRAINT notification_devices_profile_id_device_identifier_key UNIQUE (profile_id, device_identifier);
ALTER TABLE public.notification_preferences ADD CONSTRAINT notification_preferences_profile_id_key UNIQUE (profile_id);
ALTER TABLE public.organization_activities ADD CONSTRAINT organization_activities_organization_id_location_id_sport_i_key UNIQUE (organization_id, location_id, sport_id, activity_name);
ALTER TABLE public.organization_activity_memberships ADD CONSTRAINT organization_activity_members_organization_membership_id_ac_key UNIQUE (organization_membership_id, activity_id, role_in_activity);
ALTER TABLE public.organization_memberships ADD CONSTRAINT organization_memberships_organization_id_profile_id_key UNIQUE (organization_id, profile_id);
ALTER TABLE public.organization_permissions ADD CONSTRAINT organization_permissions_permission_key_key UNIQUE (permission_key);
ALTER TABLE public.organization_roles ADD CONSTRAINT organization_roles_organization_id_code_key UNIQUE (organization_id, code);
ALTER TABLE public.organizations ADD CONSTRAINT organizations_slug_key UNIQUE (slug);
ALTER TABLE public.pair_profiles ADD CONSTRAINT pair_profiles_sport_id_player_1_player_2_key UNIQUE (sport_id, player_1, player_2);
ALTER TABLE public.partner_requests ADD CONSTRAINT partner_requests_sport_id_requester_id_recipient_id_key UNIQUE (sport_id, requester_id, recipient_id);
ALTER TABLE public.payment_records ADD CONSTRAINT payment_records_provider_provider_event_id_key UNIQUE (provider, provider_event_id);
ALTER TABLE public.payment_records ADD CONSTRAINT payment_records_provider_provider_payment_id_key UNIQUE (provider, provider_payment_id);
ALTER TABLE public.payment_refunds ADD CONSTRAINT payment_refunds_payment_id_provider_refund_id_key UNIQUE (payment_id, provider_refund_id);
ALTER TABLE public.player_rivalries ADD CONSTRAINT player_rivalries_sport_id_player_one_id_player_two_id_key UNIQUE (sport_id, player_one_id, player_two_id);
ALTER TABLE public.player_sports ADD CONSTRAINT player_sports_profile_id_sport_id_key UNIQUE (profile_id, sport_id);
ALTER TABLE public.profile_locations ADD CONSTRAINT profile_locations_profile_id_key UNIQUE (profile_id);
ALTER TABLE public.profiles ADD CONSTRAINT profiles_username_key UNIQUE (username);
ALTER TABLE public.provider_organization_relationships ADD CONSTRAINT provider_organization_relations_provider_id_organization_id_key UNIQUE (provider_id, organization_id);
ALTER TABLE public.provider_profiles ADD CONSTRAINT provider_profiles_profile_id_key UNIQUE (profile_id);
ALTER TABLE public.provider_service_booking_links ADD CONSTRAINT provider_service_booking_links_provider_service_id_key UNIQUE (provider_service_id);
ALTER TABLE public.provider_students ADD CONSTRAINT provider_students_provider_id_profile_id_organization_id_key UNIQUE (provider_id, profile_id, organization_id);
ALTER TABLE public.recommendation_candidates ADD CONSTRAINT recommendation_candidates_target_type_target_id_key UNIQUE (target_type, target_id);
ALTER TABLE public.referral_codes ADD CONSTRAINT referral_codes_code_key UNIQUE (code);
ALTER TABLE public.referral_codes ADD CONSTRAINT referral_codes_profile_id_key UNIQUE (profile_id);
ALTER TABLE public.referrals ADD CONSTRAINT referrals_referred_profile_id_key UNIQUE (referred_profile_id);
ALTER TABLE public.relevance_rules ADD CONSTRAINT relevance_rules_code_key UNIQUE (code);
ALTER TABLE public.search_documents ADD CONSTRAINT search_documents_entity_type_entity_id_key UNIQUE (entity_type, entity_id);
ALTER TABLE public.security_rate_limits ADD CONSTRAINT security_rate_limits_scope_type_scope_key_endpoint_key_wind_key UNIQUE (scope_type, scope_key, endpoint_key, window_started_at);
ALTER TABLE public.share_event_templates ADD CONSTRAINT share_event_templates_code_key UNIQUE (code);
ALTER TABLE public.share_event_templates ADD CONSTRAINT share_event_templates_event_type_language_code_variant_key_key UNIQUE (event_type, language_code, variant_key);
ALTER TABLE public.shareable_events ADD CONSTRAINT shareable_events_share_token_key UNIQUE (share_token);
ALTER TABLE public.shop_coupons ADD CONSTRAINT shop_coupons_code_key UNIQUE (code);
ALTER TABLE public.shop_customers ADD CONSTRAINT shop_customers_document_type_document_number_key UNIQUE (document_type, document_number);
ALTER TABLE public.shop_inventory_reservations ADD CONSTRAINT shop_inventory_reservations_order_id_variant_id_key UNIQUE (order_id, variant_id);
ALTER TABLE public.shop_invoices ADD CONSTRAINT shop_invoices_invoice_number_key UNIQUE (invoice_number);
ALTER TABLE public.shop_invoices ADD CONSTRAINT shop_invoices_order_id_key UNIQUE (order_id);
ALTER TABLE public.shop_locations ADD CONSTRAINT shop_locations_code_key UNIQUE (code);
ALTER TABLE public.shop_order_payments ADD CONSTRAINT shop_order_payments_provider_provider_event_id_key UNIQUE (provider, provider_event_id);
ALTER TABLE public.shop_order_payments ADD CONSTRAINT shop_order_payments_provider_provider_payment_id_key UNIQUE (provider, provider_payment_id);
ALTER TABLE public.shop_orders ADD CONSTRAINT shop_orders_order_number_key UNIQUE (order_number);
ALTER TABLE public.shop_pos_registers ADD CONSTRAINT shop_pos_registers_location_id_code_key UNIQUE (location_id, code);
ALTER TABLE public.shop_pos_sales ADD CONSTRAINT shop_pos_sales_order_id_key UNIQUE (order_id);
ALTER TABLE public.shop_pos_sales ADD CONSTRAINT shop_pos_sales_sale_number_key UNIQUE (sale_number);
ALTER TABLE public.shop_product_variants ADD CONSTRAINT shop_product_variants_sku_key UNIQUE (sku);
ALTER TABLE public.shop_products ADD CONSTRAINT shop_products_slug_key UNIQUE (slug);
ALTER TABLE public.shop_registers ADD CONSTRAINT shop_registers_code_key UNIQUE (code);
ALTER TABLE public.shop_returns ADD CONSTRAINT shop_returns_return_number_key UNIQUE (return_number);
ALTER TABLE public.skill_submissions ADD CONSTRAINT skill_submissions_challenge_id_user_id_key UNIQUE (challenge_id, user_id);
ALTER TABLE public.social_follows ADD CONSTRAINT social_follows_follower_profile_id_followed_profile_id_key UNIQUE (follower_profile_id, followed_profile_id);
ALTER TABLE public.social_reactions ADD CONSTRAINT social_reactions_post_id_profile_id_key UNIQUE (post_id, profile_id);
ALTER TABLE public.sports ADD CONSTRAINT sports_name_key UNIQUE (name);
ALTER TABLE public.sports ADD CONSTRAINT sports_slug_key UNIQUE (slug);
ALTER TABLE public.tournament_checkins ADD CONSTRAINT tournament_checkins_entry_id_profile_id_key UNIQUE (entry_id, profile_id);
ALTER TABLE public.tournament_entry_members ADD CONSTRAINT tournament_entry_members_entry_id_profile_id_key UNIQUE (entry_id, profile_id);
ALTER TABLE public.tournament_fixtures ADD CONSTRAINT tournament_fixtures_match_id_key UNIQUE (match_id);
ALTER TABLE public.tournament_group_entries ADD CONSTRAINT tournament_group_entries_group_id_entry_id_key UNIQUE (group_id, entry_id);
ALTER TABLE public.tournament_groups ADD CONSTRAINT tournament_groups_stage_id_group_order_key UNIQUE (stage_id, group_order);
ALTER TABLE public.tournament_registration_payments ADD CONSTRAINT tournament_registration_payments_entry_id_key UNIQUE (entry_id);
ALTER TABLE public.tournament_stages ADD CONSTRAINT tournament_stages_tournament_id_category_id_stage_order_key UNIQUE (tournament_id, category_id, stage_order);
ALTER TABLE public.tournaments ADD CONSTRAINT tournaments_slug_key UNIQUE (slug);
ALTER TABLE public.user_blocks ADD CONSTRAINT user_blocks_blocker_profile_id_blocked_profile_id_key UNIQUE (blocker_profile_id, blocked_profile_id);
ALTER TABLE public.user_missions ADD CONSTRAINT user_missions_profile_id_mission_id_key UNIQUE (profile_id, mission_id);
ALTER TABLE public.weekly_challenge_submissions ADD CONSTRAINT weekly_challenge_submissions_participant_id_challenge_id_da_key UNIQUE (participant_id, challenge_id, day);

-- ============================================================================
-- LLAVES FORANEAS (362)
-- ============================================================================

ALTER TABLE public.account_security_devices ADD CONSTRAINT account_security_devices_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.account_security_events ADD CONSTRAINT account_security_events_device_id_fkey FOREIGN KEY (device_id) REFERENCES account_security_devices(id) ON DELETE SET NULL;
ALTER TABLE public.account_security_events ADD CONSTRAINT account_security_events_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.ai_coach_interactions ADD CONSTRAINT ai_coach_interactions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.ai_conversations ADD CONSTRAINT ai_conversations_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.ai_daily_coach_sessions ADD CONSTRAINT ai_daily_coach_sessions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.ai_evolution_council_reviews ADD CONSTRAINT ai_evolution_council_reviews_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES ai_evolution_proposals(id) ON DELETE CASCADE;
ALTER TABLE public.ai_evolution_council_reviews ADD CONSTRAINT ai_evolution_council_reviews_run_id_fkey FOREIGN KEY (run_id) REFERENCES ai_evolution_runs(id) ON DELETE CASCADE;
ALTER TABLE public.ai_evolution_evaluations ADD CONSTRAINT ai_evolution_evaluations_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES ai_evolution_proposals(id) ON DELETE CASCADE;
ALTER TABLE public.ai_evolution_memory ADD CONSTRAINT ai_evolution_memory_source_run_id_fkey FOREIGN KEY (source_run_id) REFERENCES ai_evolution_runs(id) ON DELETE SET NULL;
ALTER TABLE public.ai_evolution_outcomes ADD CONSTRAINT ai_evolution_outcomes_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES ai_evolution_proposals(id) ON DELETE CASCADE;
ALTER TABLE public.ai_evolution_proposals ADD CONSTRAINT ai_evolution_proposals_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES profiles(id);
ALTER TABLE public.ai_evolution_proposals ADD CONSTRAINT ai_evolution_proposals_run_id_fkey FOREIGN KEY (run_id) REFERENCES ai_evolution_runs(id) ON DELETE CASCADE;
ALTER TABLE public.ai_memory_notes ADD CONSTRAINT ai_memory_notes_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.ai_memory_notes ADD CONSTRAINT ai_memory_notes_source_message_id_fkey FOREIGN KEY (source_message_id) REFERENCES ai_messages(id) ON DELETE SET NULL;
ALTER TABLE public.ai_messages ADD CONSTRAINT ai_messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES ai_conversations(id) ON DELETE CASCADE;
ALTER TABLE public.ai_messages ADD CONSTRAINT ai_messages_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.ai_policy_evaluations ADD CONSTRAINT ai_policy_evaluations_version_fkey FOREIGN KEY (version) REFERENCES ai_policy_versions(version) ON DELETE CASCADE;
ALTER TABLE public.ai_recommendation_outcomes ADD CONSTRAINT ai_recommendation_outcomes_interaction_id_fkey FOREIGN KEY (interaction_id) REFERENCES ai_coach_interactions(id) ON DELETE CASCADE;
ALTER TABLE public.ai_request_reservations ADD CONSTRAINT ai_request_reservations_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.ai_usage_events ADD CONSTRAINT ai_usage_events_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.analytics_daily_metrics ADD CONSTRAINT analytics_daily_metrics_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.analytics_daily_metrics ADD CONSTRAINT analytics_daily_metrics_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.analytics_daily_metrics ADD CONSTRAINT analytics_daily_metrics_seller_profile_id_fkey FOREIGN KEY (seller_profile_id) REFERENCES marketplace_seller_profiles(id) ON DELETE CASCADE;
ALTER TABLE public.analytics_daily_metrics ADD CONSTRAINT analytics_daily_metrics_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE CASCADE;
ALTER TABLE public.analytics_events ADD CONSTRAINT analytics_events_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
ALTER TABLE public.analytics_events ADD CONSTRAINT analytics_events_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.analytics_events ADD CONSTRAINT analytics_events_seller_profile_id_fkey FOREIGN KEY (seller_profile_id) REFERENCES marketplace_seller_profiles(id) ON DELETE SET NULL;
ALTER TABLE public.analytics_events ADD CONSTRAINT analytics_events_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE SET NULL;
ALTER TABLE public.audit_logs ADD CONSTRAINT audit_logs_actor_profile_id_fkey FOREIGN KEY (actor_profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.audit_logs ADD CONSTRAINT audit_logs_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
ALTER TABLE public.billing_entitlements ADD CONSTRAINT billing_entitlements_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.billing_entitlements ADD CONSTRAINT billing_entitlements_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.billing_entitlements ADD CONSTRAINT billing_entitlements_seller_profile_id_fkey FOREIGN KEY (seller_profile_id) REFERENCES marketplace_seller_profiles(id) ON DELETE CASCADE;
ALTER TABLE public.billing_entitlements ADD CONSTRAINT billing_entitlements_subscription_id_fkey FOREIGN KEY (subscription_id) REFERENCES billing_subscriptions(id) ON DELETE CASCADE;
ALTER TABLE public.billing_invoices ADD CONSTRAINT billing_invoices_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
ALTER TABLE public.billing_invoices ADD CONSTRAINT billing_invoices_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.billing_invoices ADD CONSTRAINT billing_invoices_seller_profile_id_fkey FOREIGN KEY (seller_profile_id) REFERENCES marketplace_seller_profiles(id) ON DELETE SET NULL;
ALTER TABLE public.billing_invoices ADD CONSTRAINT billing_invoices_subscription_id_fkey FOREIGN KEY (subscription_id) REFERENCES billing_subscriptions(id) ON DELETE SET NULL;
ALTER TABLE public.billing_plan_features ADD CONSTRAINT billing_plan_features_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES billing_plans(id) ON DELETE CASCADE;
ALTER TABLE public.billing_subscriptions ADD CONSTRAINT billing_subscriptions_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.billing_subscriptions ADD CONSTRAINT billing_subscriptions_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES billing_plans(id) ON DELETE RESTRICT;
ALTER TABLE public.billing_subscriptions ADD CONSTRAINT billing_subscriptions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.billing_subscriptions ADD CONSTRAINT billing_subscriptions_seller_profile_id_fkey FOREIGN KEY (seller_profile_id) REFERENCES marketplace_seller_profiles(id) ON DELETE CASCADE;
ALTER TABLE public.billing_usage_events ADD CONSTRAINT billing_usage_events_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
ALTER TABLE public.billing_usage_events ADD CONSTRAINT billing_usage_events_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.billing_usage_events ADD CONSTRAINT billing_usage_events_seller_profile_id_fkey FOREIGN KEY (seller_profile_id) REFERENCES marketplace_seller_profiles(id) ON DELETE SET NULL;
ALTER TABLE public.billing_usage_events ADD CONSTRAINT billing_usage_events_subscription_id_fkey FOREIGN KEY (subscription_id) REFERENCES billing_subscriptions(id) ON DELETE SET NULL;
ALTER TABLE public.bookable_entities ADD CONSTRAINT bookable_entities_location_id_fkey FOREIGN KEY (location_id) REFERENCES profile_locations(id) ON DELETE SET NULL;
ALTER TABLE public.bookable_entities ADD CONSTRAINT bookable_entities_organization_resource_id_fkey FOREIGN KEY (organization_resource_id) REFERENCES organization_resources(id) ON DELETE RESTRICT;
ALTER TABLE public.bookable_entities ADD CONSTRAINT bookable_entities_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.bookable_entities ADD CONSTRAINT bookable_entities_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE SET NULL;
ALTER TABLE public.booking_availability_rules ADD CONSTRAINT booking_availability_rules_bookable_id_fkey FOREIGN KEY (bookable_id) REFERENCES bookable_entities(id) ON DELETE CASCADE;
ALTER TABLE public.booking_blackouts ADD CONSTRAINT booking_blackouts_bookable_id_fkey FOREIGN KEY (bookable_id) REFERENCES bookable_entities(id) ON DELETE CASCADE;
ALTER TABLE public.booking_dependencies ADD CONSTRAINT booking_dependencies_parent_bookable_id_fkey FOREIGN KEY (parent_bookable_id) REFERENCES bookable_entities(id) ON DELETE CASCADE;
ALTER TABLE public.booking_dependencies ADD CONSTRAINT booking_dependencies_required_bookable_id_fkey FOREIGN KEY (required_bookable_id) REFERENCES bookable_entities(id) ON DELETE CASCADE;
ALTER TABLE public.booking_finance_links ADD CONSTRAINT booking_finance_links_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE;
ALTER TABLE public.booking_finance_links ADD CONSTRAINT booking_finance_links_finance_invoice_id_fkey FOREIGN KEY (finance_invoice_id) REFERENCES finance_invoices(id) ON DELETE SET NULL;
ALTER TABLE public.booking_finance_links ADD CONSTRAINT booking_finance_links_finance_transaction_id_fkey FOREIGN KEY (finance_transaction_id) REFERENCES finance_transactions(id) ON DELETE CASCADE;
ALTER TABLE public.booking_groups ADD CONSTRAINT booking_groups_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES profiles(id) ON DELETE RESTRICT;
ALTER TABLE public.booking_payment_records ADD CONSTRAINT booking_payment_records_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE;
ALTER TABLE public.booking_payment_records ADD CONSTRAINT booking_payment_records_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
ALTER TABLE public.booking_payment_records ADD CONSTRAINT booking_payment_records_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES provider_profiles(id) ON DELETE SET NULL;
ALTER TABLE public.booking_payment_records ADD CONSTRAINT booking_payment_records_provider_service_id_fkey FOREIGN KEY (provider_service_id) REFERENCES provider_services(id) ON DELETE SET NULL;
ALTER TABLE public.booking_policies ADD CONSTRAINT booking_policies_bookable_id_fkey FOREIGN KEY (bookable_id) REFERENCES bookable_entities(id) ON DELETE CASCADE;
ALTER TABLE public.booking_waitlist ADD CONSTRAINT booking_waitlist_bookable_id_fkey FOREIGN KEY (bookable_id) REFERENCES bookable_entities(id) ON DELETE CASCADE;
ALTER TABLE public.booking_waitlist ADD CONSTRAINT booking_waitlist_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_bookable_id_fkey FOREIGN KEY (bookable_id) REFERENCES bookable_entities(id) ON DELETE RESTRICT;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_booked_by_fkey FOREIGN KEY (booked_by) REFERENCES profiles(id) ON DELETE RESTRICT;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_booking_group_id_fkey FOREIGN KEY (booking_group_id) REFERENCES booking_groups(id) ON DELETE CASCADE;
ALTER TABLE public.card_delivery_failures ADD CONSTRAINT card_delivery_failures_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE CASCADE;
ALTER TABLE public.card_delivery_failures ADD CONSTRAINT card_delivery_failures_match_id_fkey FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE;
ALTER TABLE public.challenge_card_stakes ADD CONSTRAINT challenge_card_stakes_card_id_fkey FOREIGN KEY (card_id) REFERENCES dynasty_cards(id) ON DELETE CASCADE;
ALTER TABLE public.challenge_card_stakes ADD CONSTRAINT challenge_card_stakes_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE CASCADE;
ALTER TABLE public.challenge_card_stakes ADD CONSTRAINT challenge_card_stakes_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.challenge_invitations ADD CONSTRAINT challenge_invitations_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE CASCADE;
ALTER TABLE public.challenge_invitations ADD CONSTRAINT challenge_invitations_invitee_id_fkey FOREIGN KEY (invitee_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.challenge_invitations ADD CONSTRAINT challenge_invitations_inviter_id_fkey FOREIGN KEY (inviter_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.challenge_participants ADD CONSTRAINT challenge_participants_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE CASCADE;
ALTER TABLE public.challenge_participants ADD CONSTRAINT challenge_participants_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.challenge_share_links ADD CONSTRAINT challenge_share_links_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE CASCADE;
ALTER TABLE public.challenge_share_links ADD CONSTRAINT challenge_share_links_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.challenges ADD CONSTRAINT challenges_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.challenges ADD CONSTRAINT challenges_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id);
ALTER TABLE public.content_reports ADD CONSTRAINT content_reports_reporter_profile_id_fkey FOREIGN KEY (reporter_profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.content_reports ADD CONSTRAINT content_reports_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.conversation_messages ADD CONSTRAINT conversation_messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE;
ALTER TABLE public.conversation_messages ADD CONSTRAINT conversation_messages_sender_profile_id_fkey FOREIGN KEY (sender_profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.conversation_participants ADD CONSTRAINT conversation_participants_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE;
ALTER TABLE public.conversation_participants ADD CONSTRAINT conversation_participants_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.conversations ADD CONSTRAINT conversations_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.discovery_blocks ADD CONSTRAINT discovery_blocks_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.discovery_controls ADD CONSTRAINT discovery_controls_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.discovery_events ADD CONSTRAINT discovery_events_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.discovery_preferences ADD CONSTRAINT discovery_preferences_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.dynasty_card_transfers ADD CONSTRAINT dynasty_card_transfers_card_id_fkey FOREIGN KEY (card_id) REFERENCES dynasty_cards(id) ON DELETE CASCADE;
ALTER TABLE public.dynasty_card_transfers ADD CONSTRAINT dynasty_card_transfers_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE SET NULL;
ALTER TABLE public.dynasty_card_transfers ADD CONSTRAINT dynasty_card_transfers_from_profile_id_fkey FOREIGN KEY (from_profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.dynasty_card_transfers ADD CONSTRAINT dynasty_card_transfers_match_id_fkey FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE SET NULL;
ALTER TABLE public.dynasty_card_transfers ADD CONSTRAINT dynasty_card_transfers_to_profile_id_fkey FOREIGN KEY (to_profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.dynasty_cards ADD CONSTRAINT dynasty_cards_original_profile_id_fkey FOREIGN KEY (original_profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.dynasty_cards ADD CONSTRAINT dynasty_cards_owner_profile_id_fkey FOREIGN KEY (owner_profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.dynasty_cards ADD CONSTRAINT dynasty_cards_source_match_id_fkey FOREIGN KEY (source_match_id) REFERENCES matches(id) ON DELETE SET NULL;
ALTER TABLE public.dynasty_cards ADD CONSTRAINT dynasty_cards_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id);
ALTER TABLE public.dynasty_mission_rewards ADD CONSTRAINT dynasty_mission_rewards_user_mission_id_fkey FOREIGN KEY (user_mission_id) REFERENCES user_missions(id) ON DELETE CASCADE;
ALTER TABLE public.dynasty_progression_events ADD CONSTRAINT dynasty_progression_events_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.dynasty_progression_events ADD CONSTRAINT dynasty_progression_events_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE SET NULL;
ALTER TABLE public.entity_sports ADD CONSTRAINT entity_sports_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE CASCADE;
ALTER TABLE public.finance_accounts ADD CONSTRAINT finance_accounts_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.finance_accounts ADD CONSTRAINT finance_accounts_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.finance_categories ADD CONSTRAINT finance_categories_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES organization_activities(id) ON DELETE SET NULL;
ALTER TABLE public.finance_categories ADD CONSTRAINT finance_categories_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.finance_categories ADD CONSTRAINT finance_categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES finance_categories(id) ON DELETE SET NULL;
ALTER TABLE public.finance_categories ADD CONSTRAINT finance_categories_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.finance_invoices ADD CONSTRAINT finance_invoices_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES organization_activities(id) ON DELETE SET NULL;
ALTER TABLE public.finance_invoices ADD CONSTRAINT finance_invoices_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.finance_invoices ADD CONSTRAINT finance_invoices_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.finance_recurring_items ADD CONSTRAINT finance_recurring_items_account_id_fkey FOREIGN KEY (account_id) REFERENCES finance_accounts(id) ON DELETE SET NULL;
ALTER TABLE public.finance_recurring_items ADD CONSTRAINT finance_recurring_items_category_id_fkey FOREIGN KEY (category_id) REFERENCES finance_categories(id) ON DELETE SET NULL;
ALTER TABLE public.finance_recurring_items ADD CONSTRAINT finance_recurring_items_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.finance_recurring_items ADD CONSTRAINT finance_recurring_items_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.finance_transactions ADD CONSTRAINT finance_transactions_account_id_fkey FOREIGN KEY (account_id) REFERENCES finance_accounts(id) ON DELETE RESTRICT;
ALTER TABLE public.finance_transactions ADD CONSTRAINT finance_transactions_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES organization_activities(id) ON DELETE SET NULL;
ALTER TABLE public.finance_transactions ADD CONSTRAINT finance_transactions_category_id_fkey FOREIGN KEY (category_id) REFERENCES finance_categories(id) ON DELETE SET NULL;
ALTER TABLE public.finance_transactions ADD CONSTRAINT finance_transactions_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.finance_transactions ADD CONSTRAINT finance_transactions_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.finance_transactions ADD CONSTRAINT finance_transactions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.intelligence_signals ADD CONSTRAINT intelligence_signals_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.intelligence_signals ADD CONSTRAINT intelligence_signals_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE SET NULL;
ALTER TABLE public.locale_translations ADD CONSTRAINT locale_translations_locale_code_fkey FOREIGN KEY (locale_code) REFERENCES supported_locales(code) ON DELETE CASCADE;
ALTER TABLE public.marketplace_item_returns ADD CONSTRAINT marketplace_item_returns_order_item_id_fkey FOREIGN KEY (order_item_id) REFERENCES marketplace_order_items(id) ON DELETE RESTRICT;
ALTER TABLE public.marketplace_listing_analytics_daily ADD CONSTRAINT marketplace_listing_analytics_daily_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES marketplace_listings(id) ON DELETE CASCADE;
ALTER TABLE public.marketplace_listing_delivery_options ADD CONSTRAINT marketplace_listing_delivery_options_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES marketplace_listings(id) ON DELETE CASCADE;
ALTER TABLE public.marketplace_listing_inventory ADD CONSTRAINT marketplace_listing_inventory_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES marketplace_listings(id) ON DELETE CASCADE;
ALTER TABLE public.marketplace_listings ADD CONSTRAINT marketplace_listings_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.marketplace_listings ADD CONSTRAINT marketplace_listings_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES marketplace_seller_profiles(id) ON DELETE SET NULL;
ALTER TABLE public.marketplace_listings ADD CONSTRAINT marketplace_listings_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE SET NULL;
ALTER TABLE public.marketplace_order_items ADD CONSTRAINT marketplace_order_items_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES marketplace_listings(id);
ALTER TABLE public.marketplace_order_items ADD CONSTRAINT marketplace_order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES marketplace_orders(id) ON DELETE CASCADE;
ALTER TABLE public.marketplace_order_items ADD CONSTRAINT marketplace_order_items_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES marketplace_seller_profiles(id);
ALTER TABLE public.marketplace_order_payments ADD CONSTRAINT marketplace_order_payments_order_id_fkey FOREIGN KEY (order_id) REFERENCES marketplace_orders(id) ON DELETE CASCADE;
ALTER TABLE public.marketplace_order_refunds ADD CONSTRAINT marketplace_order_refunds_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES marketplace_order_payments(id) ON DELETE CASCADE;
ALTER TABLE public.marketplace_orders ADD CONSTRAINT marketplace_orders_buyer_id_fkey FOREIGN KEY (buyer_id) REFERENCES profiles(id);
ALTER TABLE public.marketplace_promotions ADD CONSTRAINT marketplace_promotions_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES marketplace_listings(id) ON DELETE CASCADE;
ALTER TABLE public.marketplace_seller_profiles ADD CONSTRAINT marketplace_seller_profiles_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
ALTER TABLE public.marketplace_seller_profiles ADD CONSTRAINT marketplace_seller_profiles_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.marketplace_seller_settlements ADD CONSTRAINT marketplace_seller_settlements_order_id_fkey FOREIGN KEY (order_id) REFERENCES marketplace_orders(id) ON DELETE RESTRICT;
ALTER TABLE public.marketplace_seller_settlements ADD CONSTRAINT marketplace_seller_settlements_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES marketplace_seller_profiles(id) ON DELETE RESTRICT;
ALTER TABLE public.match_results ADD CONSTRAINT match_results_match_id_fkey FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE;
ALTER TABLE public.match_results ADD CONSTRAINT match_results_submitted_by_fkey FOREIGN KEY (submitted_by) REFERENCES profiles(id);
ALTER TABLE public.match_results ADD CONSTRAINT match_results_winner_profile_id_fkey FOREIGN KEY (winner_profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.matches ADD CONSTRAINT matches_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE SET NULL;
ALTER TABLE public.matches ADD CONSTRAINT matches_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id);
ALTER TABLE public.missions ADD CONSTRAINT missions_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE RESTRICT;
ALTER TABLE public.moderation_actions ADD CONSTRAINT moderation_actions_actor_profile_id_fkey FOREIGN KEY (actor_profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.notification_deliveries ADD CONSTRAINT notification_deliveries_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE;
ALTER TABLE public.notification_devices ADD CONSTRAINT notification_devices_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.notification_preferences ADD CONSTRAINT notification_preferences_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.organization_activities ADD CONSTRAINT organization_activities_location_id_fkey FOREIGN KEY (location_id) REFERENCES organization_locations(id) ON DELETE CASCADE;
ALTER TABLE public.organization_activities ADD CONSTRAINT organization_activities_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.organization_activities ADD CONSTRAINT organization_activities_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE SET NULL;
ALTER TABLE public.organization_activity_memberships ADD CONSTRAINT organization_activity_membershi_organization_membership_id_fkey FOREIGN KEY (organization_membership_id) REFERENCES organization_memberships(id) ON DELETE CASCADE;
ALTER TABLE public.organization_activity_memberships ADD CONSTRAINT organization_activity_memberships_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES organization_activities(id) ON DELETE CASCADE;
ALTER TABLE public.organization_locations ADD CONSTRAINT organization_locations_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.organization_member_roles ADD CONSTRAINT organization_member_roles_membership_id_fkey FOREIGN KEY (membership_id) REFERENCES organization_memberships(id) ON DELETE CASCADE;
ALTER TABLE public.organization_member_roles ADD CONSTRAINT organization_member_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES organization_roles(id) ON DELETE CASCADE;
ALTER TABLE public.organization_memberships ADD CONSTRAINT organization_memberships_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.organization_memberships ADD CONSTRAINT organization_memberships_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.organization_resources ADD CONSTRAINT organization_resources_location_id_fkey FOREIGN KEY (location_id) REFERENCES organization_locations(id) ON DELETE SET NULL;
ALTER TABLE public.organization_resources ADD CONSTRAINT organization_resources_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.organization_resources ADD CONSTRAINT organization_resources_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE SET NULL;
ALTER TABLE public.organization_role_permissions ADD CONSTRAINT organization_role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES organization_permissions(id) ON DELETE CASCADE;
ALTER TABLE public.organization_role_permissions ADD CONSTRAINT organization_role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES organization_roles(id) ON DELETE CASCADE;
ALTER TABLE public.organization_roles ADD CONSTRAINT organization_roles_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.organizations ADD CONSTRAINT organizations_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES profiles(id) ON DELETE RESTRICT;
ALTER TABLE public.pair_profiles ADD CONSTRAINT pair_profiles_player_1_fkey FOREIGN KEY (player_1) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.pair_profiles ADD CONSTRAINT pair_profiles_player_2_fkey FOREIGN KEY (player_2) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.pair_profiles ADD CONSTRAINT pair_profiles_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE CASCADE;
ALTER TABLE public.partner_preferences ADD CONSTRAINT partner_preferences_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE CASCADE;
ALTER TABLE public.partner_preferences ADD CONSTRAINT partner_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.partner_requests ADD CONSTRAINT partner_requests_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.partner_requests ADD CONSTRAINT partner_requests_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.partner_requests ADD CONSTRAINT partner_requests_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE CASCADE;
ALTER TABLE public.payment_records ADD CONSTRAINT payment_records_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE RESTRICT;
ALTER TABLE public.payment_records ADD CONSTRAINT payment_records_payer_profile_id_fkey FOREIGN KEY (payer_profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.payment_refunds ADD CONSTRAINT payment_refunds_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES payment_records(id) ON DELETE RESTRICT;
ALTER TABLE public.platform_admins ADD CONSTRAINT platform_admins_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.platform_test_assertions ADD CONSTRAINT platform_test_assertions_run_id_fkey FOREIGN KEY (run_id) REFERENCES platform_test_runs(id) ON DELETE CASCADE;
ALTER TABLE public.player_achievements ADD CONSTRAINT player_achievements_achievement_id_fkey FOREIGN KEY (achievement_id) REFERENCES achievements(id);
ALTER TABLE public.player_achievements ADD CONSTRAINT player_achievements_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.player_availability ADD CONSTRAINT player_availability_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.player_availability ADD CONSTRAINT player_availability_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE CASCADE;
ALTER TABLE public.player_cards ADD CONSTRAINT player_cards_card_definition_id_fkey FOREIGN KEY (card_definition_id) REFERENCES card_definitions(id);
ALTER TABLE public.player_cards ADD CONSTRAINT player_cards_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.player_progression ADD CONSTRAINT player_progression_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.player_rivalries ADD CONSTRAINT player_rivalries_player_one_id_fkey FOREIGN KEY (player_one_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.player_rivalries ADD CONSTRAINT player_rivalries_player_two_id_fkey FOREIGN KEY (player_two_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.player_rivalries ADD CONSTRAINT player_rivalries_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id);
ALTER TABLE public.player_season_progression ADD CONSTRAINT player_season_progression_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.player_season_progression ADD CONSTRAINT player_season_progression_season_id_fkey FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE CASCADE;
ALTER TABLE public.player_season_progression ADD CONSTRAINT player_season_progression_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE SET NULL;
ALTER TABLE public.player_sport_streaks ADD CONSTRAINT player_sport_streaks_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.player_sport_streaks ADD CONSTRAINT player_sport_streaks_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE CASCADE;
ALTER TABLE public.player_sports ADD CONSTRAINT player_sports_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.player_sports ADD CONSTRAINT player_sports_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE RESTRICT;
ALTER TABLE public.profile_locale_preferences ADD CONSTRAINT profile_locale_preferences_locale_code_fkey FOREIGN KEY (locale_code) REFERENCES supported_locales(code);
ALTER TABLE public.profile_locale_preferences ADD CONSTRAINT profile_locale_preferences_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.profile_locations ADD CONSTRAINT profile_locations_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.promotion_events ADD CONSTRAINT promotion_events_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.promotion_events ADD CONSTRAINT promotion_events_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES promotions(id) ON DELETE CASCADE;
ALTER TABLE public.promotions ADD CONSTRAINT promotions_listing_id_fkey FOREIGN KEY (listing_id) REFERENCES marketplace_listings(id) ON DELETE CASCADE;
ALTER TABLE public.provider_availability ADD CONSTRAINT provider_availability_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.provider_availability ADD CONSTRAINT provider_availability_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES provider_profiles(id) ON DELETE CASCADE;
ALTER TABLE public.provider_organization_relationships ADD CONSTRAINT provider_organization_relationships_membership_id_fkey FOREIGN KEY (membership_id) REFERENCES organization_memberships(id) ON DELETE SET NULL;
ALTER TABLE public.provider_organization_relationships ADD CONSTRAINT provider_organization_relationships_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.provider_organization_relationships ADD CONSTRAINT provider_organization_relationships_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES provider_profiles(id) ON DELETE CASCADE;
ALTER TABLE public.provider_profiles ADD CONSTRAINT provider_profiles_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.provider_service_booking_links ADD CONSTRAINT provider_service_booking_links_bookable_id_fkey FOREIGN KEY (bookable_id) REFERENCES bookable_entities(id) ON DELETE CASCADE;
ALTER TABLE public.provider_service_booking_links ADD CONSTRAINT provider_service_booking_links_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
ALTER TABLE public.provider_service_booking_links ADD CONSTRAINT provider_service_booking_links_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES provider_profiles(id) ON DELETE SET NULL;
ALTER TABLE public.provider_service_booking_links ADD CONSTRAINT provider_service_booking_links_provider_service_id_fkey FOREIGN KEY (provider_service_id) REFERENCES provider_services(id) ON DELETE CASCADE;
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES organization_activities(id) ON DELETE SET NULL;
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES provider_profiles(id) ON DELETE CASCADE;
ALTER TABLE public.provider_students ADD CONSTRAINT provider_students_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
ALTER TABLE public.provider_students ADD CONSTRAINT provider_students_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.provider_students ADD CONSTRAINT provider_students_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES provider_profiles(id) ON DELETE CASCADE;
ALTER TABLE public.rating_history ADD CONSTRAINT rating_history_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.rating_history ADD CONSTRAINT rating_history_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE RESTRICT;
ALTER TABLE public.recommendation_candidates ADD CONSTRAINT recommendation_candidates_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE SET NULL;
ALTER TABLE public.recommendation_explanations ADD CONSTRAINT recommendation_explanations_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.recommendation_impressions ADD CONSTRAINT recommendation_impressions_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES recommendation_candidates(id) ON DELETE CASCADE;
ALTER TABLE public.recommendation_impressions ADD CONSTRAINT recommendation_impressions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.recommendation_preferences ADD CONSTRAINT recommendation_preferences_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.referral_codes ADD CONSTRAINT referral_codes_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.referrals ADD CONSTRAINT referrals_referral_code_id_fkey FOREIGN KEY (referral_code_id) REFERENCES referral_codes(id) ON DELETE SET NULL;
ALTER TABLE public.referrals ADD CONSTRAINT referrals_referred_profile_id_fkey FOREIGN KEY (referred_profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.referrals ADD CONSTRAINT referrals_referrer_id_fkey FOREIGN KEY (referrer_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.relevance_feedback ADD CONSTRAINT relevance_feedback_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.search_documents ADD CONSTRAINT search_documents_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE SET NULL;
ALTER TABLE public.seasons ADD CONSTRAINT seasons_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE RESTRICT;
ALTER TABLE public.security_events ADD CONSTRAINT security_events_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.share_event_actions ADD CONSTRAINT share_event_actions_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.share_event_actions ADD CONSTRAINT share_event_actions_shareable_event_id_fkey FOREIGN KEY (shareable_event_id) REFERENCES shareable_events(id) ON DELETE CASCADE;
ALTER TABLE public.shareable_events ADD CONSTRAINT shareable_events_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.shop_cart_items ADD CONSTRAINT shop_cart_items_cart_id_fkey FOREIGN KEY (cart_id) REFERENCES shop_carts(id) ON DELETE CASCADE;
ALTER TABLE public.shop_cart_items ADD CONSTRAINT shop_cart_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES shop_products(id) ON DELETE RESTRICT;
ALTER TABLE public.shop_cart_items ADD CONSTRAINT shop_cart_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES shop_product_variants(id) ON DELETE RESTRICT;
ALTER TABLE public.shop_carts ADD CONSTRAINT shop_carts_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.shop_customers ADD CONSTRAINT shop_customers_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.shop_inventory_adjustments ADD CONSTRAINT shop_inventory_adjustments_location_id_fkey FOREIGN KEY (location_id) REFERENCES shop_locations(id);
ALTER TABLE public.shop_inventory_adjustments ADD CONSTRAINT shop_inventory_adjustments_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES shop_product_variants(id);
ALTER TABLE public.shop_inventory_levels ADD CONSTRAINT shop_inventory_levels_location_id_fkey FOREIGN KEY (location_id) REFERENCES shop_locations(id) ON DELETE CASCADE;
ALTER TABLE public.shop_inventory_levels ADD CONSTRAINT shop_inventory_levels_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES shop_product_variants(id) ON DELETE CASCADE;
ALTER TABLE public.shop_inventory_movements ADD CONSTRAINT shop_inventory_movements_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.shop_inventory_movements ADD CONSTRAINT shop_inventory_movements_location_id_fkey FOREIGN KEY (location_id) REFERENCES shop_locations(id) ON DELETE RESTRICT;
ALTER TABLE public.shop_inventory_movements ADD CONSTRAINT shop_inventory_movements_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES shop_product_variants(id) ON DELETE RESTRICT;
ALTER TABLE public.shop_inventory_reservations ADD CONSTRAINT shop_inventory_reservations_location_id_fkey FOREIGN KEY (location_id) REFERENCES shop_locations(id) ON DELETE RESTRICT;
ALTER TABLE public.shop_inventory_reservations ADD CONSTRAINT shop_inventory_reservations_order_id_fkey FOREIGN KEY (order_id) REFERENCES shop_orders(id) ON DELETE CASCADE;
ALTER TABLE public.shop_inventory_reservations ADD CONSTRAINT shop_inventory_reservations_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES shop_product_variants(id) ON DELETE RESTRICT;
ALTER TABLE public.shop_invoices ADD CONSTRAINT shop_invoices_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES shop_customers(id) ON DELETE SET NULL;
ALTER TABLE public.shop_invoices ADD CONSTRAINT shop_invoices_order_id_fkey FOREIGN KEY (order_id) REFERENCES shop_orders(id) ON DELETE RESTRICT;
ALTER TABLE public.shop_location_inventory ADD CONSTRAINT shop_location_inventory_location_id_fkey FOREIGN KEY (location_id) REFERENCES shop_locations(id) ON DELETE CASCADE;
ALTER TABLE public.shop_location_inventory ADD CONSTRAINT shop_location_inventory_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES shop_product_variants(id) ON DELETE CASCADE;
ALTER TABLE public.shop_order_items ADD CONSTRAINT shop_order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES shop_orders(id) ON DELETE CASCADE;
ALTER TABLE public.shop_order_items ADD CONSTRAINT shop_order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES shop_products(id) ON DELETE SET NULL;
ALTER TABLE public.shop_order_items ADD CONSTRAINT shop_order_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES shop_product_variants(id) ON DELETE SET NULL;
ALTER TABLE public.shop_order_payments ADD CONSTRAINT shop_order_payments_order_id_fkey FOREIGN KEY (order_id) REFERENCES shop_orders(id) ON DELETE CASCADE;
ALTER TABLE public.shop_orders ADD CONSTRAINT shop_orders_fulfillment_location_id_fkey FOREIGN KEY (fulfillment_location_id) REFERENCES shop_locations(id) ON DELETE SET NULL;
ALTER TABLE public.shop_orders ADD CONSTRAINT shop_orders_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.shop_pos_payments ADD CONSTRAINT shop_pos_payments_sale_id_fkey FOREIGN KEY (sale_id) REFERENCES shop_pos_sales(id) ON DELETE CASCADE;
ALTER TABLE public.shop_pos_registers ADD CONSTRAINT shop_pos_registers_location_id_fkey FOREIGN KEY (location_id) REFERENCES shop_locations(id) ON DELETE RESTRICT;
ALTER TABLE public.shop_pos_sale_items ADD CONSTRAINT shop_pos_sale_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES shop_products(id) ON DELETE SET NULL;
ALTER TABLE public.shop_pos_sale_items ADD CONSTRAINT shop_pos_sale_items_sale_id_fkey FOREIGN KEY (sale_id) REFERENCES shop_pos_sales(id) ON DELETE CASCADE;
ALTER TABLE public.shop_pos_sale_items ADD CONSTRAINT shop_pos_sale_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES shop_product_variants(id) ON DELETE SET NULL;
ALTER TABLE public.shop_pos_sales ADD CONSTRAINT shop_pos_sales_channel_location_id_fkey FOREIGN KEY (channel_location_id) REFERENCES shop_locations(id) ON DELETE SET NULL;
ALTER TABLE public.shop_pos_sales ADD CONSTRAINT shop_pos_sales_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.shop_pos_sales ADD CONSTRAINT shop_pos_sales_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES shop_customers(id) ON DELETE SET NULL;
ALTER TABLE public.shop_pos_sales ADD CONSTRAINT shop_pos_sales_invoice_fk FOREIGN KEY (invoice_id) REFERENCES shop_invoices(id) ON DELETE SET NULL;
ALTER TABLE public.shop_pos_sales ADD CONSTRAINT shop_pos_sales_location_id_fkey FOREIGN KEY (location_id) REFERENCES shop_locations(id) ON DELETE RESTRICT;
ALTER TABLE public.shop_pos_sales ADD CONSTRAINT shop_pos_sales_order_id_fkey FOREIGN KEY (order_id) REFERENCES shop_orders(id) ON DELETE RESTRICT;
ALTER TABLE public.shop_pos_sales ADD CONSTRAINT shop_pos_sales_register_id_fkey FOREIGN KEY (register_id) REFERENCES shop_pos_registers(id) ON DELETE RESTRICT;
ALTER TABLE public.shop_product_variants ADD CONSTRAINT shop_product_variants_product_id_fkey FOREIGN KEY (product_id) REFERENCES shop_products(id) ON DELETE CASCADE;
ALTER TABLE public.shop_products ADD CONSTRAINT shop_products_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE SET NULL;
ALTER TABLE public.shop_registers ADD CONSTRAINT shop_registers_closed_by_fkey FOREIGN KEY (closed_by) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.shop_registers ADD CONSTRAINT shop_registers_location_id_fkey FOREIGN KEY (location_id) REFERENCES shop_locations(id) ON DELETE RESTRICT;
ALTER TABLE public.shop_registers ADD CONSTRAINT shop_registers_opened_by_fkey FOREIGN KEY (opened_by) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.shop_return_items ADD CONSTRAINT shop_return_items_return_id_fkey FOREIGN KEY (return_id) REFERENCES shop_returns(id) ON DELETE CASCADE;
ALTER TABLE public.shop_return_items ADD CONSTRAINT shop_return_items_sale_item_id_fkey FOREIGN KEY (sale_item_id) REFERENCES shop_pos_sale_items(id) ON DELETE SET NULL;
ALTER TABLE public.shop_return_items ADD CONSTRAINT shop_return_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES shop_product_variants(id) ON DELETE SET NULL;
ALTER TABLE public.shop_returns ADD CONSTRAINT shop_returns_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES shop_customers(id) ON DELETE SET NULL;
ALTER TABLE public.shop_returns ADD CONSTRAINT shop_returns_location_id_fkey FOREIGN KEY (location_id) REFERENCES shop_locations(id) ON DELETE RESTRICT;
ALTER TABLE public.shop_returns ADD CONSTRAINT shop_returns_sale_id_fkey FOREIGN KEY (sale_id) REFERENCES shop_pos_sales(id) ON DELETE RESTRICT;
ALTER TABLE public.shop_staff ADD CONSTRAINT shop_staff_location_id_fkey FOREIGN KEY (location_id) REFERENCES shop_locations(id) ON DELETE CASCADE;
ALTER TABLE public.shop_staff ADD CONSTRAINT shop_staff_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.skill_challenges ADD CONSTRAINT skill_challenges_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.skill_challenges ADD CONSTRAINT skill_challenges_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE CASCADE;
ALTER TABLE public.skill_comments ADD CONSTRAINT skill_comments_submission_id_fkey FOREIGN KEY (submission_id) REFERENCES skill_submissions(id) ON DELETE CASCADE;
ALTER TABLE public.skill_comments ADD CONSTRAINT skill_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.skill_submissions ADD CONSTRAINT skill_submissions_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES skill_challenges(id) ON DELETE CASCADE;
ALTER TABLE public.skill_submissions ADD CONSTRAINT skill_submissions_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.skill_votes ADD CONSTRAINT skill_votes_submission_id_fkey FOREIGN KEY (submission_id) REFERENCES skill_submissions(id) ON DELETE CASCADE;
ALTER TABLE public.skill_votes ADD CONSTRAINT skill_votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.social_comments ADD CONSTRAINT social_comments_author_profile_id_fkey FOREIGN KEY (author_profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.social_comments ADD CONSTRAINT social_comments_parent_comment_id_fkey FOREIGN KEY (parent_comment_id) REFERENCES social_comments(id) ON DELETE CASCADE;
ALTER TABLE public.social_comments ADD CONSTRAINT social_comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES social_posts(id) ON DELETE CASCADE;
ALTER TABLE public.social_follows ADD CONSTRAINT social_follows_followed_profile_id_fkey FOREIGN KEY (followed_profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.social_follows ADD CONSTRAINT social_follows_follower_profile_id_fkey FOREIGN KEY (follower_profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.social_posts ADD CONSTRAINT social_posts_author_profile_id_fkey FOREIGN KEY (author_profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.social_posts ADD CONSTRAINT social_posts_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE SET NULL;
ALTER TABLE public.social_reactions ADD CONSTRAINT social_reactions_post_id_fkey FOREIGN KEY (post_id) REFERENCES social_posts(id) ON DELETE CASCADE;
ALTER TABLE public.social_reactions ADD CONSTRAINT social_reactions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.social_share_actions ADD CONSTRAINT social_share_actions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.social_share_actions ADD CONSTRAINT social_share_actions_share_card_id_fkey FOREIGN KEY (share_card_id) REFERENCES social_share_cards(id) ON DELETE CASCADE;
ALTER TABLE public.social_share_cards ADD CONSTRAINT social_share_cards_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.social_share_events ADD CONSTRAINT social_share_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.social_share_events ADD CONSTRAINT social_share_events_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE CASCADE;
ALTER TABLE public.social_share_events ADD CONSTRAINT social_share_events_share_link_id_fkey FOREIGN KEY (share_link_id) REFERENCES challenge_share_links(id) ON DELETE CASCADE;
ALTER TABLE public.sport_rankings ADD CONSTRAINT sport_rankings_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.sport_rankings ADD CONSTRAINT sport_rankings_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE RESTRICT;
ALTER TABLE public.support_ticket_messages ADD CONSTRAINT support_ticket_messages_author_profile_id_fkey FOREIGN KEY (author_profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.support_ticket_messages ADD CONSTRAINT support_ticket_messages_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES support_tickets(id) ON DELETE CASCADE;
ALTER TABLE public.support_tickets ADD CONSTRAINT support_tickets_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.support_tickets ADD CONSTRAINT support_tickets_requester_profile_id_fkey FOREIGN KEY (requester_profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_categories ADD CONSTRAINT tournament_categories_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_checkins ADD CONSTRAINT tournament_checkins_checked_in_by_fkey FOREIGN KEY (checked_in_by) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.tournament_checkins ADD CONSTRAINT tournament_checkins_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES tournament_entries(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_checkins ADD CONSTRAINT tournament_checkins_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.tournament_entries ADD CONSTRAINT tournament_entries_captain_profile_id_fkey FOREIGN KEY (captain_profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.tournament_entries ADD CONSTRAINT tournament_entries_category_id_fkey FOREIGN KEY (category_id) REFERENCES tournament_categories(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_entries ADD CONSTRAINT tournament_entries_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_entry_members ADD CONSTRAINT tournament_entry_members_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES tournament_entries(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_entry_members ADD CONSTRAINT tournament_entry_members_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_fixtures ADD CONSTRAINT tournament_fixtures_category_id_fkey FOREIGN KEY (category_id) REFERENCES tournament_categories(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_fixtures ADD CONSTRAINT tournament_fixtures_group_id_fkey FOREIGN KEY (group_id) REFERENCES tournament_groups(id) ON DELETE SET NULL;
ALTER TABLE public.tournament_fixtures ADD CONSTRAINT tournament_fixtures_match_id_fkey FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_fixtures ADD CONSTRAINT tournament_fixtures_next_fixture_id_fkey FOREIGN KEY (next_fixture_id) REFERENCES tournament_fixtures(id) ON DELETE SET NULL;
ALTER TABLE public.tournament_fixtures ADD CONSTRAINT tournament_fixtures_side_a_entry_id_fkey FOREIGN KEY (side_a_entry_id) REFERENCES tournament_entries(id) ON DELETE SET NULL;
ALTER TABLE public.tournament_fixtures ADD CONSTRAINT tournament_fixtures_side_b_entry_id_fkey FOREIGN KEY (side_b_entry_id) REFERENCES tournament_entries(id) ON DELETE SET NULL;
ALTER TABLE public.tournament_fixtures ADD CONSTRAINT tournament_fixtures_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES tournament_stages(id) ON DELETE SET NULL;
ALTER TABLE public.tournament_fixtures ADD CONSTRAINT tournament_fixtures_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_fixtures ADD CONSTRAINT tournament_fixtures_winner_entry_id_fkey FOREIGN KEY (winner_entry_id) REFERENCES tournament_entries(id) ON DELETE SET NULL;
ALTER TABLE public.tournament_group_entries ADD CONSTRAINT tournament_group_entries_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES tournament_entries(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_group_entries ADD CONSTRAINT tournament_group_entries_group_id_fkey FOREIGN KEY (group_id) REFERENCES tournament_groups(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_groups ADD CONSTRAINT tournament_groups_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES tournament_stages(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_prizes ADD CONSTRAINT tournament_prizes_category_id_fkey FOREIGN KEY (category_id) REFERENCES tournament_categories(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_prizes ADD CONSTRAINT tournament_prizes_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_registration_payments ADD CONSTRAINT tournament_registration_payments_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES tournament_entries(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_sponsors ADD CONSTRAINT tournament_sponsors_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_stages ADD CONSTRAINT tournament_stages_category_id_fkey FOREIGN KEY (category_id) REFERENCES tournament_categories(id) ON DELETE CASCADE;
ALTER TABLE public.tournament_stages ADD CONSTRAINT tournament_stages_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE;
ALTER TABLE public.tournaments ADD CONSTRAINT tournaments_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
ALTER TABLE public.tournaments ADD CONSTRAINT tournaments_organizer_profile_id_fkey FOREIGN KEY (organizer_profile_id) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public.tournaments ADD CONSTRAINT tournaments_sport_id_fkey FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE RESTRICT;
ALTER TABLE public.user_blocks ADD CONSTRAINT user_blocks_blocked_profile_id_fkey FOREIGN KEY (blocked_profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.user_blocks ADD CONSTRAINT user_blocks_blocker_profile_id_fkey FOREIGN KEY (blocker_profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.user_missions ADD CONSTRAINT user_missions_mission_id_fkey FOREIGN KEY (mission_id) REFERENCES missions(id) ON DELETE CASCADE;
ALTER TABLE public.user_missions ADD CONSTRAINT user_missions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public.weekly_challenge_submissions ADD CONSTRAINT weekly_challenge_submissions_participant_id_fkey FOREIGN KEY (participant_id) REFERENCES weekly_challenge_participants(participant_id) ON DELETE CASCADE;
ALTER TABLE public.xp_events ADD CONSTRAINT xp_events_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- ============================================================================
-- RESTRICCIONES CHECK (360)
-- ============================================================================

ALTER TABLE public.account_security_events ADD CONSTRAINT account_security_events_risk_level_check CHECK ((risk_level = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text])));
ALTER TABLE public.achievements ADD CONSTRAINT achievements_xp_reward_check CHECK ((xp_reward >= 0));
ALTER TABLE public.ai_coach_interactions ADD CONSTRAINT ai_coach_interactions_mode_check CHECK ((mode = ANY (ARRAY['daily'::text, 'match'::text, 'training'::text, 'rival'::text, 'tournament'::text, 'deep'::text])));
ALTER TABLE public.ai_conversations ADD CONSTRAINT ai_conversations_mode_check CHECK ((mode = ANY (ARRAY['coach'::text, 'fitness'::text, 'club'::text, 'coach_business'::text, 'tournament'::text, 'commerce'::text])));
ALTER TABLE public.ai_daily_coach_sessions ADD CONSTRAINT ai_daily_coach_sessions_mode_check CHECK ((mode = ANY (ARRAY['coach'::text, 'fitness'::text, 'tournament'::text])));
ALTER TABLE public.ai_evolution_council_reviews ADD CONSTRAINT ai_evolution_council_reviews_score_check CHECK (((score >= 0) AND (score <= 100)));
ALTER TABLE public.ai_evolution_council_reviews ADD CONSTRAINT ai_evolution_council_reviews_verdict_check CHECK ((verdict = ANY (ARRAY['pass'::text, 'fail'::text, 'blocked'::text])));
ALTER TABLE public.ai_evolution_evaluations ADD CONSTRAINT ai_evolution_evaluations_score_check CHECK (((score >= (0)::numeric) AND (score <= (100)::numeric)));
ALTER TABLE public.ai_evolution_evaluations ADD CONSTRAINT ai_evolution_evaluations_stage_check CHECK ((stage = ANY (ARRAY['critic'::text, 'simulation'::text, 'test'::text, 'post_apply'::text])));
ALTER TABLE public.ai_evolution_evaluations ADD CONSTRAINT ai_evolution_evaluations_verdict_check CHECK ((verdict = ANY (ARRAY['pass'::text, 'fail'::text, 'blocked'::text])));
ALTER TABLE public.ai_evolution_memory ADD CONSTRAINT ai_evolution_memory_confidence_check CHECK (((confidence >= (0)::numeric) AND (confidence <= (1)::numeric)));
ALTER TABLE public.ai_evolution_outcomes ADD CONSTRAINT ai_evolution_outcomes_impact_score_check CHECK (((impact_score >= ('-100'::integer)::numeric) AND (impact_score <= (100)::numeric)));
ALTER TABLE public.ai_evolution_outcomes ADD CONSTRAINT ai_evolution_outcomes_outcome_check CHECK ((outcome = ANY (ARRAY['success'::text, 'failure'::text, 'mixed'::text, 'inconclusive'::text])));
ALTER TABLE public.ai_evolution_outcomes ADD CONSTRAINT ai_evolution_outcomes_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'measured'::text, 'rolled_back'::text, 'inconclusive'::text])));
ALTER TABLE public.ai_evolution_proposals ADD CONSTRAINT ai_evolution_proposals_risk_level_check CHECK ((risk_level = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text])));
ALTER TABLE public.ai_evolution_proposals ADD CONSTRAINT ai_evolution_proposals_score_check CHECK (((score >= (0)::numeric) AND (score <= (100)::numeric)));
ALTER TABLE public.ai_evolution_proposals ADD CONSTRAINT ai_evolution_proposals_status_check CHECK ((status = ANY (ARRAY['proposed'::text, 'approved'::text, 'rejected'::text, 'simulated'::text, 'tested'::text, 'applied'::text])));
ALTER TABLE public.ai_evolution_runs ADD CONSTRAINT ai_evolution_runs_risk_level_check CHECK ((risk_level = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text])));
ALTER TABLE public.ai_evolution_runs ADD CONSTRAINT ai_evolution_runs_status_check CHECK ((status = ANY (ARRAY['started'::text, 'completed'::text, 'failed'::text, 'blocked'::text])));
ALTER TABLE public.ai_memory_notes ADD CONSTRAINT ai_memory_notes_confidence_check CHECK (((confidence >= (0)::numeric) AND (confidence <= (1)::numeric)));
ALTER TABLE public.ai_messages ADD CONSTRAINT ai_messages_role_check CHECK ((role = ANY (ARRAY['user'::text, 'assistant'::text, 'system'::text])));
ALTER TABLE public.ai_policy_events ADD CONSTRAINT ai_policy_events_event_type_check CHECK ((event_type = ANY (ARRAY['created'::text, 'canary_started'::text, 'promoted'::text, 'retired'::text, 'rejected'::text])));
ALTER TABLE public.ai_policy_versions ADD CONSTRAINT ai_policy_versions_status_check CHECK ((status = ANY (ARRAY['candidate'::text, 'canary'::text, 'active'::text, 'retired'::text])));
ALTER TABLE public.ai_recommendation_outcomes ADD CONSTRAINT ai_recommendation_outcomes_outcome_check CHECK ((outcome = ANY (ARRAY['accepted'::text, 'completed'::text, 'dismissed'::text, 'ignored'::text, 'failed'::text])));
ALTER TABLE public.analytics_daily_metrics ADD CONSTRAINT analytics_daily_metrics_metric_scope_check CHECK ((metric_scope = ANY (ARRAY['platform'::text, 'profile'::text, 'organization'::text, 'seller'::text, 'sport'::text])));
ALTER TABLE public.background_job_runs ADD CONSTRAINT background_job_runs_status_check CHECK ((status = ANY (ARRAY['started'::text, 'completed'::text, 'failed'::text, 'skipped'::text])));
ALTER TABLE public.billing_entitlements ADD CONSTRAINT billing_entitlements_check CHECK ((((((profile_id IS NOT NULL))::integer + ((organization_id IS NOT NULL))::integer) + ((seller_profile_id IS NOT NULL))::integer) = 1));
ALTER TABLE public.billing_invoices ADD CONSTRAINT billing_invoices_amount_due_check CHECK ((amount_due >= (0)::numeric));
ALTER TABLE public.billing_invoices ADD CONSTRAINT billing_invoices_check CHECK (((amount_paid >= (0)::numeric) AND (amount_paid <= amount_due)));
ALTER TABLE public.billing_invoices ADD CONSTRAINT billing_invoices_check1 CHECK ((((((profile_id IS NOT NULL))::integer + ((organization_id IS NOT NULL))::integer) + ((seller_profile_id IS NOT NULL))::integer) <= 1));
ALTER TABLE public.billing_invoices ADD CONSTRAINT billing_invoices_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'open'::text, 'paid'::text, 'void'::text, 'uncollectible'::text, 'refunded'::text])));
ALTER TABLE public.billing_plans ADD CONSTRAINT billing_plans_audience_type_check CHECK ((audience_type = ANY (ARRAY['player'::text, 'provider'::text, 'organization'::text, 'seller'::text, 'all'::text])));
ALTER TABLE public.billing_plans ADD CONSTRAINT billing_plans_billing_interval_check CHECK ((billing_interval = ANY (ARRAY['monthly'::text, 'yearly'::text, 'one_time'::text])));
ALTER TABLE public.billing_plans ADD CONSTRAINT billing_plans_price_check CHECK ((price >= (0)::numeric));
ALTER TABLE public.billing_subscriptions ADD CONSTRAINT billing_subscriptions_check CHECK ((((((profile_id IS NOT NULL))::integer + ((organization_id IS NOT NULL))::integer) + ((seller_profile_id IS NOT NULL))::integer) = 1));
ALTER TABLE public.billing_subscriptions ADD CONSTRAINT billing_subscriptions_status_check CHECK ((status = ANY (ARRAY['trialing'::text, 'active'::text, 'past_due'::text, 'paused'::text, 'cancelled'::text, 'expired'::text])));
ALTER TABLE public.billing_usage_events ADD CONSTRAINT billing_usage_events_check CHECK ((((((profile_id IS NOT NULL))::integer + ((organization_id IS NOT NULL))::integer) + ((seller_profile_id IS NOT NULL))::integer) <= 1));
ALTER TABLE public.billing_usage_events ADD CONSTRAINT billing_usage_events_quantity_check CHECK ((quantity >= (0)::numeric));
ALTER TABLE public.bookable_entities ADD CONSTRAINT bookable_entities_booking_mode_check CHECK ((booking_mode = ANY (ARRAY['instant'::text, 'approval_required'::text])));
ALTER TABLE public.bookable_entities ADD CONSTRAINT bookable_entities_capacity_check CHECK ((capacity > 0));
ALTER TABLE public.bookable_entities ADD CONSTRAINT bookable_entities_duration_minutes_check CHECK (((duration_minutes IS NULL) OR (duration_minutes > 0)));
ALTER TABLE public.bookable_entities ADD CONSTRAINT bookable_entities_entity_type_check CHECK ((entity_type = ANY (ARRAY['resource'::text, 'person'::text, 'class'::text, 'event'::text, 'service'::text])));
ALTER TABLE public.bookable_entities ADD CONSTRAINT bookable_entities_price_check CHECK ((price >= (0)::numeric));
ALTER TABLE public.bookable_entities ADD CONSTRAINT bookable_entities_status_check CHECK ((status = ANY (ARRAY['active'::text, 'paused'::text, 'archived'::text])));
ALTER TABLE public.bookable_entities ADD CONSTRAINT bookable_nonnegative_price CHECK ((price >= (0)::numeric));
ALTER TABLE public.bookable_entities ADD CONSTRAINT bookable_positive_capacity CHECK ((capacity > 0));
ALTER TABLE public.bookable_entities ADD CONSTRAINT bookable_positive_duration CHECK ((duration_minutes > 0));
ALTER TABLE public.booking_availability_rules ADD CONSTRAINT booking_availability_rules_check CHECK (((end_time IS NULL) OR (start_time IS NULL) OR (end_time > start_time)));
ALTER TABLE public.booking_availability_rules ADD CONSTRAINT booking_availability_rules_day_of_week_check CHECK (((day_of_week >= 0) AND (day_of_week <= 6)));
ALTER TABLE public.booking_blackouts ADD CONSTRAINT booking_blackouts_check CHECK ((ends_at > starts_at));
ALTER TABLE public.booking_dependencies ADD CONSTRAINT booking_dependencies_check CHECK ((parent_bookable_id <> required_bookable_id));
ALTER TABLE public.booking_dependencies ADD CONSTRAINT booking_dependencies_quantity_check CHECK ((quantity > 0));
ALTER TABLE public.booking_groups ADD CONSTRAINT booking_groups_check CHECK ((ends_at > starts_at));
ALTER TABLE public.booking_groups ADD CONSTRAINT booking_groups_payment_status_check CHECK ((payment_status = ANY (ARRAY['not_required'::text, 'pending'::text, 'paid'::text, 'refunded'::text, 'failed'::text])));
ALTER TABLE public.booking_groups ADD CONSTRAINT booking_groups_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'failed'::text, 'cancelled'::text, 'completed'::text])));
ALTER TABLE public.booking_groups ADD CONSTRAINT booking_groups_total_amount_check CHECK ((total_amount >= (0)::numeric));
ALTER TABLE public.booking_payment_records ADD CONSTRAINT booking_payment_records_amount_due_check CHECK ((amount_due >= (0)::numeric));
ALTER TABLE public.booking_payment_records ADD CONSTRAINT booking_payment_records_check CHECK (((amount_paid >= (0)::numeric) AND (amount_paid <= amount_due)));
ALTER TABLE public.booking_payment_records ADD CONSTRAINT booking_payment_records_check1 CHECK (((deposit_amount >= (0)::numeric) AND (deposit_amount <= amount_due)));
ALTER TABLE public.booking_payment_records ADD CONSTRAINT booking_payment_records_check2 CHECK ((((payment_owner_type = 'provider'::text) AND (provider_id IS NOT NULL) AND (organization_id IS NULL)) OR ((payment_owner_type = 'organization'::text) AND (organization_id IS NOT NULL) AND (provider_id IS NULL))));
ALTER TABLE public.booking_payment_records ADD CONSTRAINT booking_payment_records_payment_owner_type_check CHECK ((payment_owner_type = ANY (ARRAY['provider'::text, 'organization'::text])));
ALTER TABLE public.booking_payment_records ADD CONSTRAINT booking_payment_records_payment_status_check CHECK ((payment_status = ANY (ARRAY['unpaid'::text, 'deposit_paid'::text, 'partially_paid'::text, 'paid'::text, 'refunded'::text, 'waived'::text])));
ALTER TABLE public.booking_policies ADD CONSTRAINT booking_policies_cancellation_deadline_minutes_check CHECK (((cancellation_deadline_minutes IS NULL) OR (cancellation_deadline_minutes >= 0)));
ALTER TABLE public.booking_policies ADD CONSTRAINT booking_policies_max_active_bookings_per_user_check CHECK (((max_active_bookings_per_user IS NULL) OR (max_active_bookings_per_user > 0)));
ALTER TABLE public.booking_policies ADD CONSTRAINT booking_policies_min_notice_minutes_check CHECK ((min_notice_minutes >= 0));
ALTER TABLE public.booking_policies ADD CONSTRAINT booking_policies_no_show_grace_minutes_check CHECK ((no_show_grace_minutes >= 0));
ALTER TABLE public.booking_policies ADD CONSTRAINT booking_policy_nonnegative_notice CHECK (((min_notice_minutes >= 0) AND (cancellation_deadline_minutes >= 0) AND (no_show_grace_minutes >= 0)));
ALTER TABLE public.booking_policies ADD CONSTRAINT booking_policy_positive_active_limit CHECK (((max_active_bookings_per_user IS NULL) OR (max_active_bookings_per_user > 0)));
ALTER TABLE public.booking_policies ADD CONSTRAINT booking_policy_positive_payment_hold CHECK ((payment_hold_minutes > 0));
ALTER TABLE public.booking_waitlist ADD CONSTRAINT booking_waitlist_check CHECK ((requested_ends_at > requested_starts_at));
ALTER TABLE public.booking_waitlist ADD CONSTRAINT booking_waitlist_quantity_check CHECK ((quantity > 0));
ALTER TABLE public.booking_waitlist ADD CONSTRAINT booking_waitlist_status_check CHECK ((status = ANY (ARRAY['waiting'::text, 'offered'::text, 'accepted'::text, 'expired'::text, 'cancelled'::text])));
ALTER TABLE public.bookings ADD CONSTRAINT bookings_amount_check CHECK ((amount >= (0)::numeric));
ALTER TABLE public.bookings ADD CONSTRAINT bookings_check CHECK ((ends_at > starts_at));
ALTER TABLE public.bookings ADD CONSTRAINT bookings_nonnegative_amount CHECK ((amount >= (0)::numeric));
ALTER TABLE public.bookings ADD CONSTRAINT bookings_payment_status_check CHECK ((payment_status = ANY (ARRAY['not_required'::text, 'pending'::text, 'paid'::text, 'refunded'::text, 'partially_refunded'::text, 'failed'::text])));
ALTER TABLE public.bookings ADD CONSTRAINT bookings_positive_quantity CHECK ((quantity > 0));
ALTER TABLE public.bookings ADD CONSTRAINT bookings_quantity_check CHECK ((quantity > 0));
ALTER TABLE public.bookings ADD CONSTRAINT bookings_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'waitlisted'::text, 'cancelled'::text, 'completed'::text, 'no_show'::text, 'expired'::text])));
ALTER TABLE public.bookings ADD CONSTRAINT bookings_valid_time_range CHECK ((ends_at > starts_at));
ALTER TABLE public.card_definitions ADD CONSTRAINT card_definitions_rarity_check CHECK ((rarity = ANY (ARRAY['common'::text, 'rare'::text, 'epic'::text, 'legendary'::text, 'secret'::text])));
ALTER TABLE public.card_definitions ADD CONSTRAINT card_definitions_xp_reward_check CHECK ((xp_reward >= 0));
ALTER TABLE public.challenge_card_stakes ADD CONSTRAINT challenge_card_stakes_status_check CHECK ((status = ANY (ARRAY['locked'::text, 'settled'::text, 'released'::text])));
ALTER TABLE public.challenge_invitations ADD CONSTRAINT challenge_invitations_check CHECK (((invitee_id IS NULL) OR (invitee_id <> inviter_id)));
ALTER TABLE public.challenge_invitations ADD CONSTRAINT challenge_invitations_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text, 'expired'::text, 'cancelled'::text])));
ALTER TABLE public.challenge_participants ADD CONSTRAINT challenge_participants_role_check CHECK ((role = ANY (ARRAY['creator'::text, 'participant'::text, 'opponent'::text, 'team_member'::text])));
ALTER TABLE public.challenge_participants ADD CONSTRAINT challenge_participants_status_check CHECK ((status = ANY (ARRAY['invited'::text, 'accepted'::text, 'declined'::text, 'withdrawn'::text])));
ALTER TABLE public.challenge_share_links ADD CONSTRAINT challenge_share_links_max_uses_check CHECK (((max_uses IS NULL) OR (max_uses > 0)));
ALTER TABLE public.challenge_share_links ADD CONSTRAINT challenge_share_links_uses_count_check CHECK ((uses_count >= 0));
ALTER TABLE public.challenges ADD CONSTRAINT challenges_challenge_type_check CHECK ((challenge_type = ANY (ARRAY['match'::text, 'skill'::text, 'distance'::text, 'time'::text, 'custom'::text])));
ALTER TABLE public.challenges ADD CONSTRAINT challenges_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'open'::text, 'accepted'::text, 'active'::text, 'completed'::text, 'cancelled'::text])));
ALTER TABLE public.content_reports ADD CONSTRAINT content_reports_status_check CHECK ((status = ANY (ARRAY['open'::text, 'reviewing'::text, 'resolved'::text, 'dismissed'::text])));
ALTER TABLE public.conversation_messages ADD CONSTRAINT conversation_messages_status_check CHECK ((status = ANY (ARRAY['sent'::text, 'edited'::text, 'deleted'::text, 'flagged'::text])));
ALTER TABLE public.conversations ADD CONSTRAINT conversations_status_check CHECK ((status = ANY (ARRAY['open'::text, 'closed'::text, 'archived'::text])));
ALTER TABLE public.discovery_blocks ADD CONSTRAINT discovery_blocks_block_scope_check CHECK ((block_scope = ANY (ARRAY['entity'::text, 'type'::text, 'source'::text])));
ALTER TABLE public.discovery_controls ADD CONSTRAINT discovery_controls_custom_radius_km_check CHECK (((custom_radius_km IS NULL) OR ((custom_radius_km >= (1)::numeric) AND (custom_radius_km <= (500)::numeric))));
ALTER TABLE public.discovery_controls ADD CONSTRAINT discovery_controls_distance_mode_check CHECK ((distance_mode = ANY (ARRAY['same_city'::text, 'nearby'::text, 'custom'::text, 'national'::text, 'global'::text])));
ALTER TABLE public.discovery_events ADD CONSTRAINT discovery_events_entity_type_check CHECK ((entity_type = ANY (ARRAY['player'::text, 'challenge'::text, 'listing'::text, 'promotion'::text, 'club'::text, 'tournament'::text, 'coach'::text, 'academy'::text, 'brand'::text, 'product'::text])));
ALTER TABLE public.discovery_events ADD CONSTRAINT discovery_events_event_type_check CHECK ((event_type = ANY (ARRAY['impression'::text, 'open'::text, 'click'::text, 'dismiss'::text, 'conversion'::text])));
ALTER TABLE public.discovery_events ADD CONSTRAINT discovery_events_surface_check CHECK ((surface = ANY (ARRAY['home'::text, 'search'::text, 'nearby'::text, 'recommended'::text, 'feed'::text, 'marketplace'::text, 'notification'::text])));
ALTER TABLE public.discovery_preferences ADD CONSTRAINT discovery_preferences_discovery_radius_km_check CHECK (((discovery_radius_km >= (1)::numeric) AND (discovery_radius_km <= (500)::numeric)));
ALTER TABLE public.dynasty_card_transfers ADD CONSTRAINT dynasty_card_transfers_reason_check CHECK ((reason = 'challenge_stake'::text));
ALTER TABLE public.dynasty_cards ADD CONSTRAINT dynasty_cards_base_is_protected CHECK (((origin = 'base'::text) = is_protected));
ALTER TABLE public.dynasty_cards ADD CONSTRAINT dynasty_cards_origin_check CHECK ((origin = ANY (ARRAY['base'::text, 'win_reward'::text])));
ALTER TABLE public.dynasty_cards ADD CONSTRAINT dynasty_cards_rarity_check CHECK ((rarity = ANY (ARRAY['common'::text, 'rare'::text, 'epic'::text, 'legendary'::text])));
ALTER TABLE public.entity_availability ADD CONSTRAINT entity_availability_availability_status_check CHECK ((availability_status = ANY (ARRAY['available'::text, 'limited'::text, 'waitlist'::text, 'unavailable'::text, 'closed'::text, 'ended'::text])));
ALTER TABLE public.entity_availability ADD CONSTRAINT entity_availability_check CHECK (((ends_at IS NULL) OR (starts_at IS NULL) OR (ends_at > starts_at)));
ALTER TABLE public.entity_availability ADD CONSTRAINT entity_availability_entity_type_check CHECK ((entity_type = ANY (ARRAY['listing'::text, 'profile'::text, 'challenge'::text, 'tournament'::text, 'club'::text, 'coach'::text, 'academy'::text])));
ALTER TABLE public.entity_sports ADD CONSTRAINT entity_sports_entity_type_check CHECK ((entity_type = ANY (ARRAY['listing'::text, 'challenge'::text, 'club'::text, 'tournament'::text, 'coach'::text, 'academy'::text, 'promotion'::text, 'product'::text, 'event'::text])));
ALTER TABLE public.finance_accounts ADD CONSTRAINT finance_accounts_account_type_check CHECK ((account_type = ANY (ARRAY['cash'::text, 'bank'::text, 'digital_wallet'::text, 'accounts_receivable'::text, 'accounts_payable'::text, 'revenue'::text, 'expense'::text, 'equity'::text, 'other'::text])));
ALTER TABLE public.finance_accounts ADD CONSTRAINT finance_accounts_check CHECK (((((organization_id IS NOT NULL))::integer + ((profile_id IS NOT NULL))::integer) = 1));
ALTER TABLE public.finance_categories ADD CONSTRAINT finance_categories_category_type_check CHECK ((category_type = ANY (ARRAY['income'::text, 'expense'::text, 'asset'::text, 'liability'::text, 'equity'::text, 'transfer'::text])));
ALTER TABLE public.finance_categories ADD CONSTRAINT finance_categories_check CHECK (((((organization_id IS NOT NULL))::integer + ((profile_id IS NOT NULL))::integer) = 1));
ALTER TABLE public.finance_invoices ADD CONSTRAINT finance_invoices_check CHECK ((paid_amount <= total_amount));
ALTER TABLE public.finance_invoices ADD CONSTRAINT finance_invoices_check1 CHECK (((((organization_id IS NOT NULL))::integer + ((profile_id IS NOT NULL))::integer) = 1));
ALTER TABLE public.finance_invoices ADD CONSTRAINT finance_invoices_direction_check CHECK ((direction = ANY (ARRAY['receivable'::text, 'payable'::text])));
ALTER TABLE public.finance_invoices ADD CONSTRAINT finance_invoices_paid_amount_check CHECK ((paid_amount >= (0)::numeric));
ALTER TABLE public.finance_invoices ADD CONSTRAINT finance_invoices_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'open'::text, 'partial'::text, 'paid'::text, 'overdue'::text, 'cancelled'::text])));
ALTER TABLE public.finance_invoices ADD CONSTRAINT finance_invoices_total_amount_check CHECK ((total_amount >= (0)::numeric));
ALTER TABLE public.finance_recurring_items ADD CONSTRAINT finance_recurring_items_amount_check CHECK ((amount > (0)::numeric));
ALTER TABLE public.finance_recurring_items ADD CONSTRAINT finance_recurring_items_check CHECK (((((organization_id IS NOT NULL))::integer + ((profile_id IS NOT NULL))::integer) = 1));
ALTER TABLE public.finance_recurring_items ADD CONSTRAINT finance_recurring_items_frequency_check CHECK ((frequency = ANY (ARRAY['weekly'::text, 'monthly'::text, 'quarterly'::text, 'yearly'::text])));
ALTER TABLE public.finance_recurring_items ADD CONSTRAINT finance_recurring_items_transaction_type_check CHECK ((transaction_type = ANY (ARRAY['income'::text, 'expense'::text])));
ALTER TABLE public.finance_transactions ADD CONSTRAINT finance_nonnegative_amount CHECK ((amount >= (0)::numeric));
ALTER TABLE public.finance_transactions ADD CONSTRAINT finance_transactions_amount_check CHECK ((amount > (0)::numeric));
ALTER TABLE public.finance_transactions ADD CONSTRAINT finance_transactions_check CHECK (((((organization_id IS NOT NULL))::integer + ((profile_id IS NOT NULL))::integer) = 1));
ALTER TABLE public.finance_transactions ADD CONSTRAINT finance_transactions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'posted'::text, 'void'::text])));
ALTER TABLE public.finance_transactions ADD CONSTRAINT finance_transactions_transaction_type_check CHECK ((transaction_type = ANY (ARRAY['income'::text, 'expense'::text, 'transfer'::text, 'adjustment'::text])));
ALTER TABLE public.marketplace_item_returns ADD CONSTRAINT marketplace_item_returns_quantity_check CHECK ((quantity > 0));
ALTER TABLE public.marketplace_item_returns ADD CONSTRAINT marketplace_item_returns_refund_amount_check CHECK ((refund_amount >= (0)::numeric));
ALTER TABLE public.marketplace_item_returns ADD CONSTRAINT marketplace_item_returns_status_check CHECK ((status = ANY (ARRAY['requested'::text, 'approved'::text, 'refunded'::text, 'rejected'::text])));
ALTER TABLE public.marketplace_listing_delivery_options ADD CONSTRAINT marketplace_listing_delivery_options_base_price_check CHECK ((base_price >= (0)::numeric));
ALTER TABLE public.marketplace_listing_delivery_options ADD CONSTRAINT marketplace_listing_delivery_options_delivery_type_check CHECK ((delivery_type = ANY (ARRAY['shipping'::text, 'pickup'::text, 'digital'::text, 'in_person'::text, 'online'::text])));
ALTER TABLE public.marketplace_listing_inventory ADD CONSTRAINT marketplace_inventory_nonnegative_guard CHECK (((quantity_available >= 0) AND (reserved_quantity >= 0) AND (reserved_quantity <= quantity_available)));
ALTER TABLE public.marketplace_listing_inventory ADD CONSTRAINT marketplace_listing_inventory_low_stock_threshold_check CHECK ((low_stock_threshold >= 0));
ALTER TABLE public.marketplace_listing_inventory ADD CONSTRAINT marketplace_listing_inventory_quantity_available_check CHECK ((quantity_available >= 0));
ALTER TABLE public.marketplace_listing_inventory ADD CONSTRAINT marketplace_listing_inventory_reserved_quantity_check CHECK ((reserved_quantity >= 0));
ALTER TABLE public.marketplace_listings ADD CONSTRAINT marketplace_listings_audience_scope_check CHECK ((audience_scope = ANY (ARRAY['sport_specific'::text, 'multi_sport'::text, 'universal'::text])));
ALTER TABLE public.marketplace_listings ADD CONSTRAINT marketplace_listings_listing_type_check CHECK ((listing_type = ANY (ARRAY['tournament'::text, 'club'::text, 'academy'::text, 'coach'::text, 'brand'::text, 'event'::text, 'other'::text])));
ALTER TABLE public.marketplace_listings ADD CONSTRAINT marketplace_listings_location_scope_check CHECK ((location_scope = ANY (ARRAY['local'::text, 'regional'::text, 'national'::text, 'global'::text, 'online'::text])));
ALTER TABLE public.marketplace_listings ADD CONSTRAINT marketplace_listings_service_radius_km_check CHECK (((service_radius_km IS NULL) OR (service_radius_km >= (1)::numeric)));
ALTER TABLE public.marketplace_listings ADD CONSTRAINT marketplace_listings_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'pending'::text, 'published'::text, 'rejected'::text, 'archived'::text])));
ALTER TABLE public.marketplace_order_items ADD CONSTRAINT marketplace_order_items_delivery_amount_check CHECK ((delivery_amount >= (0)::numeric));
ALTER TABLE public.marketplace_order_items ADD CONSTRAINT marketplace_order_items_quantity_check CHECK ((quantity > 0));
ALTER TABLE public.marketplace_order_items ADD CONSTRAINT marketplace_order_items_seller_fee_check CHECK ((seller_fee >= (0)::numeric));
ALTER TABLE public.marketplace_order_items ADD CONSTRAINT marketplace_order_items_unit_price_check CHECK ((unit_price >= (0)::numeric));
ALTER TABLE public.marketplace_order_payments ADD CONSTRAINT marketplace_order_payments_amount_check CHECK ((amount >= (0)::numeric));
ALTER TABLE public.marketplace_order_payments ADD CONSTRAINT marketplace_order_payments_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text, 'refunded'::text, 'partially_refunded'::text])));
ALTER TABLE public.marketplace_order_refunds ADD CONSTRAINT marketplace_order_refunds_amount_check CHECK ((amount > (0)::numeric));
ALTER TABLE public.marketplace_order_refunds ADD CONSTRAINT marketplace_order_refunds_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'succeeded'::text, 'failed'::text])));
ALTER TABLE public.marketplace_orders ADD CONSTRAINT marketplace_order_amounts_nonnegative CHECK (((subtotal >= (0)::numeric) AND (delivery_amount >= (0)::numeric) AND (platform_fee >= (0)::numeric) AND (total_amount >= (0)::numeric)));
ALTER TABLE public.marketplace_orders ADD CONSTRAINT marketplace_orders_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'reserved'::text, 'paid'::text, 'cancelled'::text, 'fulfilled'::text, 'refunded'::text, 'partially_refunded'::text])));
ALTER TABLE public.marketplace_promotions ADD CONSTRAINT marketplace_promotions_promotion_type_check CHECK ((promotion_type = ANY (ARRAY['featured'::text, 'boost'::text, 'discount'::text, 'local_campaign'::text])));
ALTER TABLE public.marketplace_promotions ADD CONSTRAINT marketplace_promotions_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'paused'::text, 'ended'::text])));
ALTER TABLE public.marketplace_seller_profiles ADD CONSTRAINT marketplace_seller_profiles_premium_status_check CHECK ((premium_status = ANY (ARRAY['free'::text, 'premium'::text, 'suspended'::text])));
ALTER TABLE public.marketplace_seller_profiles ADD CONSTRAINT marketplace_seller_profiles_seller_type_check CHECK ((seller_type = ANY (ARRAY['individual'::text, 'coach'::text, 'club'::text, 'organization'::text, 'brand'::text, 'store'::text])));
ALTER TABLE public.marketplace_seller_profiles ADD CONSTRAINT marketplace_seller_profiles_status_check CHECK ((status = ANY (ARRAY['active'::text, 'paused'::text, 'suspended'::text])));
ALTER TABLE public.marketplace_seller_profiles ADD CONSTRAINT marketplace_seller_profiles_verification_status_check CHECK ((verification_status = ANY (ARRAY['unverified'::text, 'pending'::text, 'verified'::text, 'rejected'::text])));
ALTER TABLE public.marketplace_seller_settlements ADD CONSTRAINT marketplace_seller_settlements_gross_amount_check CHECK ((gross_amount >= (0)::numeric));
ALTER TABLE public.marketplace_seller_settlements ADD CONSTRAINT marketplace_seller_settlements_platform_fee_check CHECK ((platform_fee >= (0)::numeric));
ALTER TABLE public.marketplace_seller_settlements ADD CONSTRAINT marketplace_seller_settlements_refunds_amount_check CHECK ((refunds_amount >= (0)::numeric));
ALTER TABLE public.marketplace_seller_settlements ADD CONSTRAINT marketplace_seller_settlements_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'ready'::text, 'paid'::text, 'void'::text])));
ALTER TABLE public.match_results ADD CONSTRAINT match_results_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'disputed'::text])));
ALTER TABLE public.matches ADD CONSTRAINT matches_status_check CHECK ((status = ANY (ARRAY['scheduled'::text, 'in_progress'::text, 'completed'::text, 'cancelled'::text])));
ALTER TABLE public.moderation_actions ADD CONSTRAINT moderation_actions_action_type_check CHECK ((action_type = ANY (ARRAY['warn'::text, 'hide'::text, 'remove'::text, 'suspend'::text, 'restore'::text, 'restrict'::text])));
ALTER TABLE public.notification_deliveries ADD CONSTRAINT notification_deliveries_channel_check CHECK ((channel = ANY (ARRAY['in_app'::text, 'push'::text, 'email'::text, 'sms'::text])));
ALTER TABLE public.notification_deliveries ADD CONSTRAINT notification_deliveries_status_check CHECK ((status = ANY (ARRAY['queued'::text, 'sent'::text, 'delivered'::text, 'failed'::text, 'suppressed'::text])));
ALTER TABLE public.notification_devices ADD CONSTRAINT notification_devices_platform_check CHECK ((platform = ANY (ARRAY['ios'::text, 'android'::text, 'web'::text])));
ALTER TABLE public.notifications ADD CONSTRAINT notifications_priority_check CHECK ((priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'urgent'::text])));
ALTER TABLE public.organization_activities ADD CONSTRAINT organization_activities_activity_type_check CHECK ((activity_type = ANY (ARRAY['sport'::text, 'fitness'::text, 'wellness'::text, 'recreation'::text, 'hybrid'::text])));
ALTER TABLE public.organization_activity_memberships ADD CONSTRAINT organization_activity_memberships_role_in_activity_check CHECK ((role_in_activity = ANY (ARRAY['manager'::text, 'coach'::text, 'instructor'::text, 'participant'::text])));
ALTER TABLE public.organization_activity_memberships ADD CONSTRAINT organization_activity_memberships_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text])));
ALTER TABLE public.organization_locations ADD CONSTRAINT organization_locations_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text])));
ALTER TABLE public.organization_memberships ADD CONSTRAINT organization_memberships_membership_type_check CHECK ((membership_type = ANY (ARRAY['owner'::text, 'admin'::text, 'manager'::text, 'coach'::text, 'staff'::text, 'member'::text])));
ALTER TABLE public.organization_memberships ADD CONSTRAINT organization_memberships_status_check CHECK ((status = ANY (ARRAY['invited'::text, 'active'::text, 'suspended'::text, 'left'::text])));
ALTER TABLE public.organization_resources ADD CONSTRAINT organization_resources_capacity_check CHECK ((capacity > 0));
ALTER TABLE public.organization_resources ADD CONSTRAINT organization_resources_status_check CHECK ((status = ANY (ARRAY['active'::text, 'maintenance'::text, 'inactive'::text])));
ALTER TABLE public.organizations ADD CONSTRAINT organizations_organization_type_check CHECK ((organization_type = ANY (ARRAY['club'::text, 'academy'::text, 'fitness_center'::text, 'sports_center'::text, 'organizer'::text, 'business'::text])));
ALTER TABLE public.organizations ADD CONSTRAINT organizations_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'suspended'::text, 'archived'::text])));
ALTER TABLE public.pair_profiles ADD CONSTRAINT pair_profiles_check CHECK ((player_1 <> player_2));
ALTER TABLE public.pair_profiles ADD CONSTRAINT pair_profiles_reputation_score_check CHECK (((reputation_score >= 0) AND (reputation_score <= 100)));
ALTER TABLE public.partner_preferences ADD CONSTRAINT partner_preferences_max_distance_km_check CHECK ((max_distance_km > (0)::numeric));
ALTER TABLE public.partner_requests ADD CONSTRAINT partner_requests_check CHECK ((requester_id <> recipient_id));
ALTER TABLE public.partner_requests ADD CONSTRAINT partner_requests_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'ACCEPTED'::text, 'REJECTED'::text, 'CANCELLED'::text])));
ALTER TABLE public.payment_records ADD CONSTRAINT payment_records_amount_check CHECK ((amount >= (0)::numeric));
ALTER TABLE public.payment_records ADD CONSTRAINT payment_records_refunded_amount_valid CHECK (((refunded_amount >= (0)::numeric) AND (refunded_amount <= amount)));
ALTER TABLE public.payment_records ADD CONSTRAINT payment_records_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'authorized'::text, 'paid'::text, 'failed'::text, 'refunded'::text, 'partially_refunded'::text, 'cancelled'::text])));
ALTER TABLE public.payment_refunds ADD CONSTRAINT payment_refunds_amount_check CHECK ((amount > (0)::numeric));
ALTER TABLE public.payment_refunds ADD CONSTRAINT payment_refunds_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'succeeded'::text, 'failed'::text, 'cancelled'::text])));
ALTER TABLE public.platform_test_runs ADD CONSTRAINT platform_test_runs_status_check CHECK ((status = ANY (ARRAY['running'::text, 'passed'::text, 'failed'::text, 'cancelled'::text])));
ALTER TABLE public.player_availability ADD CONSTRAINT player_availability_check CHECK ((ends_at > starts_at));
ALTER TABLE public.player_availability ADD CONSTRAINT player_availability_intent_check CHECK ((intent = ANY (ARRAY['match'::text, 'rival'::text, 'partner'::text, 'training'::text])));
ALTER TABLE public.player_progression ADD CONSTRAINT player_progression_level_check CHECK ((level >= 1));
ALTER TABLE public.player_progression ADD CONSTRAINT player_progression_total_xp_check CHECK ((total_xp >= 0));
ALTER TABLE public.player_rivalries ADD CONSTRAINT player_rivalries_check CHECK ((player_one_id <> player_two_id));
ALTER TABLE public.player_rivalries ADD CONSTRAINT player_rivalries_matches_count_check CHECK ((matches_count >= 0));
ALTER TABLE public.player_rivalries ADD CONSTRAINT player_rivalries_player_one_wins_check CHECK ((player_one_wins >= 0));
ALTER TABLE public.player_rivalries ADD CONSTRAINT player_rivalries_player_two_wins_check CHECK ((player_two_wins >= 0));
ALTER TABLE public.player_season_progression ADD CONSTRAINT player_season_progression_best_win_streak_check CHECK ((best_win_streak >= 0));
ALTER TABLE public.player_season_progression ADD CONSTRAINT player_season_progression_losses_check CHECK ((losses >= 0));
ALTER TABLE public.player_season_progression ADD CONSTRAINT player_season_progression_matches_played_check CHECK ((matches_played >= 0));
ALTER TABLE public.player_season_progression ADD CONSTRAINT player_season_progression_wins_check CHECK ((wins >= 0));
ALTER TABLE public.player_season_progression ADD CONSTRAINT player_season_progression_xp_earned_check CHECK ((xp_earned >= 0));
ALTER TABLE public.player_sport_streaks ADD CONSTRAINT player_sport_streaks_best_win_streak_check CHECK ((best_win_streak >= 0));
ALTER TABLE public.player_sport_streaks ADD CONSTRAINT player_sport_streaks_current_win_streak_check CHECK ((current_win_streak >= 0));
ALTER TABLE public.player_sports ADD CONSTRAINT player_sports_relationship_check CHECK ((relationship = ANY (ARRAY['active'::text, 'primary'::text, 'secondary'::text, 'learning'::text, 'following'::text, 'discover'::text])));
ALTER TABLE public.profile_locations ADD CONSTRAINT profile_locations_precision_mode_check CHECK ((precision_mode = ANY (ARRAY['exact'::text, 'approximate'::text, 'city'::text, 'hidden'::text])));
ALTER TABLE public.profile_locations ADD CONSTRAINT profile_locations_search_radius_km_check CHECK (((search_radius_km >= (1)::numeric) AND (search_radius_km <= (500)::numeric)));
ALTER TABLE public.profiles ADD CONSTRAINT profiles_player_status_check CHECK ((player_status = ANY (ARRAY['active'::text, 'inactive'::text, 'suspended'::text])));
ALTER TABLE public.profiles ADD CONSTRAINT username_length CHECK (((username IS NULL) OR ((char_length(username) >= 3) AND (char_length(username) <= 30))));
ALTER TABLE public.promotion_events ADD CONSTRAINT promotion_events_event_type_check CHECK ((event_type = ANY (ARRAY['impression'::text, 'open'::text, 'click'::text, 'conversion'::text, 'registration'::text])));
ALTER TABLE public.promotions ADD CONSTRAINT promotions_check CHECK (((ends_at IS NULL) OR (starts_at IS NULL) OR (ends_at > starts_at)));
ALTER TABLE public.promotions ADD CONSTRAINT promotions_promotion_type_check CHECK ((promotion_type = ANY (ARRAY['featured'::text, 'boost'::text, 'sponsored_card'::text, 'sponsored_feed'::text, 'notification_campaign'::text])));
ALTER TABLE public.promotions ADD CONSTRAINT promotions_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'scheduled'::text, 'active'::text, 'paused'::text, 'completed'::text, 'cancelled'::text])));
ALTER TABLE public.provider_availability ADD CONSTRAINT provider_availability_check CHECK ((end_time > start_time));
ALTER TABLE public.provider_availability ADD CONSTRAINT provider_availability_day_of_week_check CHECK (((day_of_week >= 0) AND (day_of_week <= 6)));
ALTER TABLE public.provider_availability ADD CONSTRAINT provider_availability_valid_day CHECK (((day_of_week >= 0) AND (day_of_week <= 6)));
ALTER TABLE public.provider_availability ADD CONSTRAINT provider_availability_valid_time CHECK ((end_time > start_time));
ALTER TABLE public.provider_organization_relationships ADD CONSTRAINT provider_organization_relationships_relationship_type_check CHECK ((relationship_type = ANY (ARRAY['employee'::text, 'contractor'::text, 'partner'::text, 'guest'::text])));
ALTER TABLE public.provider_organization_relationships ADD CONSTRAINT provider_organization_relationships_status_check CHECK ((status = ANY (ARRAY['invited'::text, 'active'::text, 'inactive'::text, 'ended'::text])));
ALTER TABLE public.provider_profiles ADD CONSTRAINT provider_profiles_provider_type_check CHECK ((provider_type = ANY (ARRAY['coach'::text, 'instructor'::text, 'trainer'::text, 'consultant'::text, 'creator'::text])));
ALTER TABLE public.provider_profiles ADD CONSTRAINT provider_profiles_status_check CHECK ((status = ANY (ARRAY['active'::text, 'paused'::text, 'suspended'::text])));
ALTER TABLE public.provider_profiles ADD CONSTRAINT provider_profiles_verification_status_check CHECK ((verification_status = ANY (ARRAY['unverified'::text, 'pending'::text, 'verified'::text, 'rejected'::text])));
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_capacity_check CHECK ((capacity > 0));
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_check CHECK (((provider_id IS NOT NULL) OR (organization_id IS NOT NULL)));
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_duration_minutes_check CHECK (((duration_minutes IS NULL) OR (duration_minutes > 0)));
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_nonnegative_price CHECK ((price >= (0)::numeric));
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_operational_owner_type_check CHECK ((operational_owner_type = ANY (ARRAY['provider'::text, 'organization'::text])));
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_ownership_type_check CHECK ((ownership_type = ANY (ARRAY['provider'::text, 'organization'::text])));
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_payment_owner_type_check CHECK ((payment_owner_type = ANY (ARRAY['provider'::text, 'organization'::text])));
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_positive_capacity CHECK ((capacity > 0));
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_positive_duration CHECK ((duration_minutes > 0));
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_price_check CHECK ((price >= (0)::numeric));
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_service_mode_check CHECK ((service_mode = ANY (ARRAY['in_person'::text, 'online'::text, 'hybrid'::text])));
ALTER TABLE public.provider_services ADD CONSTRAINT provider_services_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'paused'::text, 'archived'::text])));
ALTER TABLE public.provider_students ADD CONSTRAINT provider_students_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'archived'::text])));
ALTER TABLE public.referrals ADD CONSTRAINT referrals_check CHECK ((referrer_id <> referred_profile_id));
ALTER TABLE public.referrals ADD CONSTRAINT referrals_status_check CHECK ((status = ANY (ARRAY['registered'::text, 'qualified'::text, 'rewarded'::text, 'rejected'::text])));
ALTER TABLE public.referrals ADD CONSTRAINT referrals_xp_reward_check CHECK ((xp_reward >= 0));
ALTER TABLE public.relevance_feedback ADD CONSTRAINT relevance_feedback_feedback_type_check CHECK ((feedback_type = ANY (ARRAY['interested'::text, 'not_interested'::text, 'hide'::text, 'save'::text, 'report_irrelevant'::text])));
ALTER TABLE public.relevance_rules ADD CONSTRAINT relevance_rules_rule_type_check CHECK ((rule_type = ANY (ARRAY['hard_filter'::text, 'score'::text, 'penalty'::text, 'boost'::text])));
ALTER TABLE public.seasons ADD CONSTRAINT seasons_check CHECK (((ends_at IS NULL) OR (starts_at IS NULL) OR (ends_at > starts_at)));
ALTER TABLE public.seasons ADD CONSTRAINT seasons_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'completed'::text, 'cancelled'::text])));
ALTER TABLE public.security_events ADD CONSTRAINT security_events_severity_check CHECK ((severity = ANY (ARRAY['info'::text, 'low'::text, 'medium'::text, 'high'::text, 'critical'::text])));
ALTER TABLE public.security_events ADD CONSTRAINT security_events_status_check CHECK ((status = ANY (ARRAY['open'::text, 'reviewing'::text, 'resolved'::text, 'dismissed'::text])));
ALTER TABLE public.security_rate_limits ADD CONSTRAINT security_rate_limits_request_count_check CHECK ((request_count >= 0));
ALTER TABLE public.security_rate_limits ADD CONSTRAINT security_rate_limits_scope_type_check CHECK ((scope_type = ANY (ARRAY['ip'::text, 'profile'::text, 'session'::text, 'organization'::text, 'endpoint'::text, 'operation'::text])));
ALTER TABLE public.share_event_actions ADD CONSTRAINT share_event_actions_action_type_check CHECK ((action_type = ANY (ARRAY['shared'::text, 'opened'::text, 'copied'::text, 'downloaded'::text])));
ALTER TABLE public.share_event_actions ADD CONSTRAINT share_event_actions_platform_check CHECK ((platform = ANY (ARRAY['whatsapp'::text, 'instagram'::text, 'tiktok'::text, 'facebook'::text, 'x'::text, 'copy_link'::text, 'download'::text, 'native_share'::text, 'other'::text])));
ALTER TABLE public.share_event_templates ADD CONSTRAINT share_event_templates_weight_check CHECK ((weight > 0));
ALTER TABLE public.shareable_events ADD CONSTRAINT shareable_events_event_type_check CHECK ((event_type = ANY (ARRAY['challenge'::text, 'challenge_accepted'::text, 'victory'::text, 'defeat'::text, 'card'::text, 'achievement'::text, 'level_up'::text, 'ranking_change'::text, 'streak'::text, 'tournament'::text, 'other'::text])));
ALTER TABLE public.shareable_events ADD CONSTRAINT shareable_events_visibility_check CHECK ((visibility = ANY (ARRAY['public'::text, 'unlisted'::text, 'private'::text])));
ALTER TABLE public.shop_cart_items ADD CONSTRAINT shop_cart_items_quantity_check CHECK (((quantity > 0) AND (quantity <= 100)));
ALTER TABLE public.shop_carts ADD CONSTRAINT shop_carts_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'CHECKOUT'::text, 'CONVERTED'::text, 'ABANDONED'::text])));
ALTER TABLE public.shop_coupons ADD CONSTRAINT shop_coupons_discount_type_check CHECK ((discount_type = ANY (ARRAY['percentage'::text, 'fixed'::text])));
ALTER TABLE public.shop_coupons ADD CONSTRAINT shop_coupons_discount_value_check CHECK ((discount_value >= (0)::numeric));
ALTER TABLE public.shop_coupons ADD CONSTRAINT shop_coupons_usage_limit_check CHECK (((usage_limit IS NULL) OR (usage_limit > 0)));
ALTER TABLE public.shop_inventory_adjustments ADD CONSTRAINT shop_inventory_adjustments_counted_quantity_check CHECK ((counted_quantity >= 0));
ALTER TABLE public.shop_inventory_adjustments ADD CONSTRAINT shop_inventory_adjustments_reason_check CHECK (((length(TRIM(BOTH FROM reason)) >= 3) AND (length(TRIM(BOTH FROM reason)) <= 500)));
ALTER TABLE public.shop_inventory_levels ADD CONSTRAINT shop_inventory_levels_reserved_le_stock CHECK ((reserved_quantity <= stock_quantity));
ALTER TABLE public.shop_inventory_levels ADD CONSTRAINT shop_inventory_levels_reserved_quantity_check CHECK ((reserved_quantity >= 0));
ALTER TABLE public.shop_inventory_levels ADD CONSTRAINT shop_inventory_levels_stock_quantity_check CHECK ((stock_quantity >= 0));
ALTER TABLE public.shop_inventory_movements ADD CONSTRAINT shop_inventory_movements_movement_type_check CHECK ((movement_type = ANY (ARRAY['sale'::text, 'purchase'::text, 'adjustment_in'::text, 'adjustment_out'::text, 'transfer_in'::text, 'transfer_out'::text, 'return'::text, 'reservation_release'::text, 'reservation_consume'::text])));
ALTER TABLE public.shop_inventory_movements ADD CONSTRAINT shop_inventory_movements_quantity_check CHECK ((quantity <> 0));
ALTER TABLE public.shop_inventory_reservations ADD CONSTRAINT shop_inventory_reservation_expiry_guard CHECK ((expires_at IS NOT NULL));
ALTER TABLE public.shop_inventory_reservations ADD CONSTRAINT shop_inventory_reservations_quantity_check CHECK ((quantity > 0));
ALTER TABLE public.shop_inventory_reservations ADD CONSTRAINT shop_inventory_reservations_status_check CHECK ((status = ANY (ARRAY['active'::text, 'released'::text, 'consumed'::text, 'expired'::text])));
ALTER TABLE public.shop_invoices ADD CONSTRAINT shop_invoices_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'issued'::text, 'cancelled'::text, 'refunded'::text])));
ALTER TABLE public.shop_location_inventory ADD CONSTRAINT shop_location_inventory_check CHECK (((reserved_quantity >= 0) AND (reserved_quantity <= quantity)));
ALTER TABLE public.shop_location_inventory ADD CONSTRAINT shop_location_inventory_quantity_check CHECK ((quantity >= 0));
ALTER TABLE public.shop_location_inventory ADD CONSTRAINT shop_location_inventory_reorder_level_check CHECK ((reorder_level >= 0));
ALTER TABLE public.shop_locations ADD CONSTRAINT shop_locations_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text])));
ALTER TABLE public.shop_locations ADD CONSTRAINT shop_locations_type_check CHECK ((location_type = ANY (ARRAY['physical'::text, 'online'::text])));
ALTER TABLE public.shop_order_items ADD CONSTRAINT shop_order_items_line_total_check CHECK ((line_total >= (0)::numeric));
ALTER TABLE public.shop_order_items ADD CONSTRAINT shop_order_items_quantity_check CHECK ((quantity > 0));
ALTER TABLE public.shop_order_items ADD CONSTRAINT shop_order_items_unit_price_check CHECK ((unit_price >= (0)::numeric));
ALTER TABLE public.shop_order_payments ADD CONSTRAINT shop_order_payments_amount_check CHECK ((amount >= (0)::numeric));
ALTER TABLE public.shop_order_payments ADD CONSTRAINT shop_order_payments_amount_nonnegative CHECK ((amount >= (0)::numeric));
ALTER TABLE public.shop_order_payments ADD CONSTRAINT shop_order_payments_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text, 'refunded'::text, 'partially_refunded'::text])));
ALTER TABLE public.shop_orders ADD CONSTRAINT shop_orders_discount_amount_check CHECK ((discount_amount >= (0)::numeric));
ALTER TABLE public.shop_orders ADD CONSTRAINT shop_orders_sales_channel_check CHECK ((sales_channel = ANY (ARRAY['online'::text, 'physical'::text])));
ALTER TABLE public.shop_orders ADD CONSTRAINT shop_orders_shipping_amount_check CHECK ((shipping_amount >= (0)::numeric));
ALTER TABLE public.shop_orders ADD CONSTRAINT shop_orders_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'payment_pending'::text, 'paid'::text, 'processing'::text, 'shipped'::text, 'delivered'::text, 'cancelled'::text, 'refunded'::text])));
ALTER TABLE public.shop_orders ADD CONSTRAINT shop_orders_subtotal_check CHECK ((subtotal >= (0)::numeric));
ALTER TABLE public.shop_orders ADD CONSTRAINT shop_orders_total_amount_check CHECK ((total_amount >= (0)::numeric));
ALTER TABLE public.shop_pos_payments ADD CONSTRAINT shop_pos_payments_amount_check CHECK ((amount > (0)::numeric));
ALTER TABLE public.shop_pos_payments ADD CONSTRAINT shop_pos_payments_payment_method_check CHECK ((payment_method = ANY (ARRAY['cash'::text, 'card'::text, 'transfer'::text, 'mixed'::text, 'other'::text])));
ALTER TABLE public.shop_pos_registers ADD CONSTRAINT shop_pos_registers_status_check CHECK ((status = ANY (ARRAY['open'::text, 'closed'::text, 'disabled'::text])));
ALTER TABLE public.shop_pos_sale_items ADD CONSTRAINT shop_pos_sale_items_line_discount_check CHECK ((line_discount >= (0)::numeric));
ALTER TABLE public.shop_pos_sale_items ADD CONSTRAINT shop_pos_sale_items_line_total_check CHECK ((line_total >= (0)::numeric));
ALTER TABLE public.shop_pos_sale_items ADD CONSTRAINT shop_pos_sale_items_quantity_check CHECK ((quantity > 0));
ALTER TABLE public.shop_pos_sale_items ADD CONSTRAINT shop_pos_sale_items_unit_price_check CHECK ((unit_price >= (0)::numeric));
ALTER TABLE public.shop_pos_sales ADD CONSTRAINT shop_pos_sales_sale_channel_check CHECK ((sale_channel = ANY (ARRAY['physical'::text, 'online'::text])));
ALTER TABLE public.shop_pos_sales ADD CONSTRAINT shop_pos_sales_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'completed'::text, 'cancelled'::text, 'refunded'::text])));
ALTER TABLE public.shop_product_variants ADD CONSTRAINT shop_product_variants_price_check CHECK ((price >= (0)::numeric));
ALTER TABLE public.shop_product_variants ADD CONSTRAINT shop_product_variants_reserved_quantity_check CHECK (((reserved_quantity >= 0) AND (reserved_quantity <= stock_quantity)));
ALTER TABLE public.shop_product_variants ADD CONSTRAINT shop_product_variants_stock_quantity_check CHECK ((stock_quantity >= 0));
ALTER TABLE public.shop_products ADD CONSTRAINT shop_products_base_price_check CHECK ((base_price >= (0)::numeric));
ALTER TABLE public.shop_products ADD CONSTRAINT shop_products_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'archived'::text])));
ALTER TABLE public.shop_registers ADD CONSTRAINT shop_registers_closing_cash_check CHECK ((closing_cash >= (0)::numeric));
ALTER TABLE public.shop_registers ADD CONSTRAINT shop_registers_opening_cash_check CHECK ((opening_cash >= (0)::numeric));
ALTER TABLE public.shop_registers ADD CONSTRAINT shop_registers_status_check CHECK ((status = ANY (ARRAY['open'::text, 'closed'::text, 'suspended'::text])));
ALTER TABLE public.shop_return_items ADD CONSTRAINT shop_return_items_line_refund_check CHECK ((line_refund >= (0)::numeric));
ALTER TABLE public.shop_return_items ADD CONSTRAINT shop_return_items_quantity_check CHECK ((quantity > 0));
ALTER TABLE public.shop_return_items ADD CONSTRAINT shop_return_items_unit_refund_check CHECK ((unit_refund >= (0)::numeric));
ALTER TABLE public.shop_returns ADD CONSTRAINT shop_returns_refund_amount_check CHECK ((refund_amount >= (0)::numeric));
ALTER TABLE public.shop_returns ADD CONSTRAINT shop_returns_refund_method_check CHECK ((refund_method = ANY (ARRAY['cash'::text, 'card'::text, 'transfer'::text, 'store_credit'::text, 'original_method'::text, 'other'::text])));
ALTER TABLE public.shop_returns ADD CONSTRAINT shop_returns_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'completed'::text, 'cancelled'::text])));
ALTER TABLE public.shop_staff ADD CONSTRAINT shop_staff_role_check CHECK ((role = ANY (ARRAY['owner'::text, 'manager'::text, 'cashier'::text, 'inventory'::text])));
ALTER TABLE public.shop_staff ADD CONSTRAINT shop_staff_status_check CHECK ((status = ANY (ARRAY['active'::text, 'suspended'::text, 'revoked'::text])));
ALTER TABLE public.skill_challenges ADD CONSTRAINT skill_challenges_difficulty_check CHECK ((difficulty = ANY (ARRAY['BEGINNER'::text, 'INTERMEDIATE'::text, 'ADVANCED'::text, 'PRO'::text, 'ELITE'::text])));
ALTER TABLE public.skill_challenges ADD CONSTRAINT skill_challenges_points_check CHECK ((points >= 0));
ALTER TABLE public.skill_challenges ADD CONSTRAINT skill_challenges_status_check CHECK ((status = ANY (ARRAY['OPEN'::text, 'SUBMITTED'::text, 'VOTING'::text, 'COMPLETED'::text])));
ALTER TABLE public.skill_challenges ADD CONSTRAINT skill_challenges_target_votes_check CHECK ((target_votes > 0));
ALTER TABLE public.skill_comments ADD CONSTRAINT skill_comments_content_check CHECK ((length(TRIM(BOTH FROM content)) > 0));
ALTER TABLE public.skill_submissions ADD CONSTRAINT skill_submissions_skill_points_awarded_check CHECK ((skill_points_awarded >= 0));
ALTER TABLE public.skill_submissions ADD CONSTRAINT skill_submissions_votes_check CHECK ((votes >= 0));
ALTER TABLE public.skill_votes ADD CONSTRAINT skill_votes_value_check CHECK (((value >= 1) AND (value <= 5)));
ALTER TABLE public.social_comments ADD CONSTRAINT social_comments_status_check CHECK ((status = ANY (ARRAY['visible'::text, 'hidden'::text, 'deleted'::text, 'reported'::text])));
ALTER TABLE public.social_follows ADD CONSTRAINT social_follows_check CHECK ((follower_profile_id <> followed_profile_id));
ALTER TABLE public.social_posts ADD CONSTRAINT social_posts_post_type_check CHECK ((post_type = ANY (ARRAY['text'::text, 'image'::text, 'achievement'::text, 'challenge'::text, 'match'::text, 'tournament'::text, 'marketplace'::text, 'share_card'::text])));
ALTER TABLE public.social_posts ADD CONSTRAINT social_posts_visibility_check CHECK ((visibility = ANY (ARRAY['public'::text, 'followers'::text, 'private'::text])));
ALTER TABLE public.social_reactions ADD CONSTRAINT social_reactions_reaction_type_check CHECK ((reaction_type = ANY (ARRAY['like'::text, 'fire'::text, 'clap'::text, 'wow'::text, 'support'::text])));
ALTER TABLE public.social_share_actions ADD CONSTRAINT social_share_actions_channel_check CHECK ((channel = ANY (ARRAY['system'::text, 'instagram'::text, 'facebook'::text, 'whatsapp'::text, 'x'::text, 'tiktok'::text, 'copy_link'::text, 'other'::text])));
ALTER TABLE public.social_share_events ADD CONSTRAINT social_share_events_event_type_check CHECK ((event_type = ANY (ARRAY['shared'::text, 'opened'::text, 'accepted'::text])));
ALTER TABLE public.social_share_events ADD CONSTRAINT social_share_events_platform_check CHECK ((platform = ANY (ARRAY['whatsapp'::text, 'instagram'::text, 'tiktok'::text, 'facebook'::text, 'x'::text, 'copy_link'::text, 'other'::text])));
ALTER TABLE public.support_tickets ADD CONSTRAINT support_tickets_priority_check CHECK ((priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'urgent'::text])));
ALTER TABLE public.support_tickets ADD CONSTRAINT support_tickets_status_check CHECK ((status = ANY (ARRAY['open'::text, 'pending'::text, 'resolved'::text, 'closed'::text])));
ALTER TABLE public.system_health_checks ADD CONSTRAINT system_health_checks_status_check CHECK ((status = ANY (ARRAY['healthy'::text, 'degraded'::text, 'down'::text])));
ALTER TABLE public.tournament_categories ADD CONSTRAINT tournament_categories_capacity_check CHECK (((capacity IS NULL) OR (capacity > 0)));
ALTER TABLE public.tournament_categories ADD CONSTRAINT tournament_categories_entry_fee_check CHECK (((entry_fee IS NULL) OR (entry_fee >= (0)::numeric)));
ALTER TABLE public.tournament_categories ADD CONSTRAINT tournament_categories_participant_mode_check CHECK ((participant_mode = ANY (ARRAY['individual'::text, 'pair'::text, 'team'::text])));
ALTER TABLE public.tournament_categories ADD CONSTRAINT tournament_categories_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'open'::text, 'closed'::text, 'in_progress'::text, 'completed'::text, 'cancelled'::text])));
ALTER TABLE public.tournament_checkins ADD CONSTRAINT tournament_checkins_method_check CHECK ((method = ANY (ARRAY['manual'::text, 'qr'::text, 'self'::text])));
ALTER TABLE public.tournament_entries ADD CONSTRAINT tournament_entries_entry_type_check CHECK ((entry_type = ANY (ARRAY['individual'::text, 'pair'::text, 'team'::text])));
ALTER TABLE public.tournament_entries ADD CONSTRAINT tournament_entries_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'waitlisted'::text, 'withdrawn'::text, 'rejected'::text, 'cancelled'::text])));
ALTER TABLE public.tournament_entry_members ADD CONSTRAINT tournament_entry_members_role_check CHECK ((role = ANY (ARRAY['captain'::text, 'member'::text, 'substitute'::text])));
ALTER TABLE public.tournament_entry_members ADD CONSTRAINT tournament_entry_members_status_check CHECK ((status = ANY (ARRAY['invited'::text, 'confirmed'::text, 'declined'::text, 'removed'::text])));
ALTER TABLE public.tournament_fixtures ADD CONSTRAINT tournament_fixtures_status_check CHECK ((status = ANY (ARRAY['scheduled'::text, 'ready'::text, 'in_progress'::text, 'completed'::text, 'walkover'::text, 'cancelled'::text])));
ALTER TABLE public.tournament_prizes ADD CONSTRAINT tournament_prizes_position_check CHECK (("position" > 0));
ALTER TABLE public.tournament_prizes ADD CONSTRAINT tournament_prizes_prize_type_check CHECK ((prize_type = ANY (ARRAY['cash'::text, 'product'::text, 'service'::text, 'trophy'::text, 'points'::text, 'other'::text])));
ALTER TABLE public.tournament_registration_payments ADD CONSTRAINT tournament_registration_payments_amount_due_check CHECK ((amount_due >= (0)::numeric));
ALTER TABLE public.tournament_registration_payments ADD CONSTRAINT tournament_registration_payments_check CHECK (((amount_paid >= (0)::numeric) AND (amount_paid <= amount_due)));
ALTER TABLE public.tournament_registration_payments ADD CONSTRAINT tournament_registration_payments_status_check CHECK ((status = ANY (ARRAY['unpaid'::text, 'deposit_paid'::text, 'partial'::text, 'paid'::text, 'refunded'::text, 'waived'::text])));
ALTER TABLE public.tournament_stages ADD CONSTRAINT tournament_stages_stage_type_check CHECK ((stage_type = ANY (ARRAY['group'::text, 'round_robin'::text, 'single_elimination'::text, 'double_elimination'::text, 'ladder'::text, 'custom'::text])));
ALTER TABLE public.tournament_stages ADD CONSTRAINT tournament_stages_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'completed'::text, 'cancelled'::text])));
ALTER TABLE public.tournaments ADD CONSTRAINT tournaments_capacity_check CHECK (((capacity IS NULL) OR (capacity > 0)));
ALTER TABLE public.tournaments ADD CONSTRAINT tournaments_check CHECK (((organization_id IS NOT NULL) OR (organizer_profile_id IS NOT NULL)));
ALTER TABLE public.tournaments ADD CONSTRAINT tournaments_entry_fee_check CHECK ((entry_fee >= (0)::numeric));
ALTER TABLE public.tournaments ADD CONSTRAINT tournaments_format_type_check CHECK ((format_type = ANY (ARRAY['single_elimination'::text, 'double_elimination'::text, 'round_robin'::text, 'groups_then_knockout'::text, 'ladder'::text, 'custom'::text])));
ALTER TABLE public.tournaments ADD CONSTRAINT tournaments_participant_mode_check CHECK ((participant_mode = ANY (ARRAY['individual'::text, 'pair'::text, 'team'::text])));
ALTER TABLE public.tournaments ADD CONSTRAINT tournaments_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'published'::text, 'registration_open'::text, 'registration_closed'::text, 'in_progress'::text, 'completed'::text, 'cancelled'::text])));
ALTER TABLE public.tournaments ADD CONSTRAINT tournaments_visibility_check CHECK ((visibility = ANY (ARRAY['public'::text, 'private'::text, 'unlisted'::text])));
ALTER TABLE public.user_blocks ADD CONSTRAINT user_blocks_check CHECK ((blocker_profile_id <> blocked_profile_id));
ALTER TABLE public.user_missions ADD CONSTRAINT user_missions_status_check CHECK ((status = ANY (ARRAY['active'::text, 'completed'::text, 'claimed'::text, 'expired'::text])));
ALTER TABLE public.weekly_challenge_participants ADD CONSTRAINT weekly_challenge_participants_completion_percentage_check CHECK (((completion_percentage >= 0) AND (completion_percentage <= 100)));
ALTER TABLE public.weekly_challenge_participants ADD CONSTRAINT weekly_challenge_participants_status_check CHECK ((status = ANY (ARRAY['active'::text, 'complete'::text])));
ALTER TABLE public.weekly_challenge_submissions ADD CONSTRAINT weekly_challenge_submissions_day_check CHECK (((day >= 1) AND (day <= 7)));
ALTER TABLE public.weekly_challenge_submissions ADD CONSTRAINT weekly_challenge_submissions_note_check CHECK ((char_length(TRIM(BOTH FROM note)) > 0));
ALTER TABLE public.xp_events ADD CONSTRAINT xp_events_amount_check CHECK ((amount <> 0));

-- ============================================================================
-- INDICES (458)
-- ============================================================================

CREATE INDEX dyn_fk_7103ce72d90a7cac7e5e ON public.account_security_devices USING btree (profile_id);
CREATE INDEX dyn_fk_3dcd0c0a2559330e9b3d ON public.account_security_events USING btree (device_id);
CREATE INDEX dyn_fk_6a20539d4eedaaf21799 ON public.account_security_events USING btree (profile_id);
CREATE INDEX idx_ai_coach_interactions_profile_created ON public.ai_coach_interactions USING btree (profile_id, created_at DESC);
CREATE INDEX ai_conversations_profile_updated_idx ON public.ai_conversations USING btree (profile_id, updated_at DESC);
CREATE INDEX ai_daily_coach_profile_date_idx ON public.ai_daily_coach_sessions USING btree (profile_id, session_date DESC);
CREATE INDEX idx_ai_evolution_council_role ON public.ai_evolution_council_reviews USING btree (role, created_at DESC);
CREATE INDEX idx_ai_evolution_council_run ON public.ai_evolution_council_reviews USING btree (run_id);
CREATE INDEX idx_ai_evolution_evaluations_proposal ON public.ai_evolution_evaluations USING btree (proposal_id, created_at DESC);
CREATE INDEX idx_ai_evolution_memory_source_run_id ON public.ai_evolution_memory USING btree (source_run_id);
CREATE INDEX idx_ai_evolution_memory_updated_at ON public.ai_evolution_memory USING btree (updated_at DESC);
CREATE UNIQUE INDEX uq_ai_evolution_memory_key ON public.ai_evolution_memory USING btree (memory_key);
CREATE INDEX idx_ai_evolution_outcomes_learning_applied_at ON public.ai_evolution_outcomes USING btree (learning_applied_at);
CREATE INDEX idx_ai_evolution_outcomes_observed_at ON public.ai_evolution_outcomes USING btree (observed_at DESC);
CREATE INDEX idx_ai_evolution_outcomes_status ON public.ai_evolution_outcomes USING btree (status);
CREATE INDEX idx_ai_evolution_proposals_approved_by ON public.ai_evolution_proposals USING btree (approved_by);
CREATE INDEX idx_ai_evolution_proposals_run_id ON public.ai_evolution_proposals USING btree (run_id);
CREATE INDEX idx_ai_evolution_proposals_status ON public.ai_evolution_proposals USING btree (status);
CREATE INDEX idx_ai_evolution_runs_created_at ON public.ai_evolution_runs USING btree (created_at DESC);
CREATE INDEX idx_ai_evolution_runs_status ON public.ai_evolution_runs USING btree (status);
CREATE INDEX ai_memory_notes_profile_scope_idx ON public.ai_memory_notes USING btree (profile_id, scope, active);
CREATE INDEX ai_memory_notes_profile_updated_idx ON public.ai_memory_notes USING btree (profile_id, updated_at DESC);
CREATE INDEX ai_memory_notes_source_message_id_idx ON public.ai_memory_notes USING btree (source_message_id);
CREATE INDEX ai_messages_conversation_created_idx ON public.ai_messages USING btree (conversation_id, created_at);
CREATE INDEX ai_messages_profile_id_idx ON public.ai_messages USING btree (profile_id);
CREATE INDEX idx_ai_policy_evaluations_version_created_at ON public.ai_policy_evaluations USING btree (version, created_at DESC);
CREATE INDEX idx_ai_recommendation_outcomes_interaction_id ON public.ai_recommendation_outcomes USING btree (interaction_id);
CREATE INDEX idx_ai_recommendation_outcomes_key_created ON public.ai_recommendation_outcomes USING btree (recommendation_key, created_at DESC);
CREATE INDEX ai_request_reservations_profile_created_idx ON public.ai_request_reservations USING btree (profile_id, created_at DESC);
CREATE INDEX ai_usage_events_profile_created_idx ON public.ai_usage_events USING btree (profile_id, created_at DESC);
CREATE INDEX analytics_daily_scope_idx ON public.analytics_daily_metrics USING btree (metric_scope, metric_date DESC);
CREATE INDEX dyn_fk_3e0c39e34bac522e52e9 ON public.analytics_daily_metrics USING btree (organization_id);
CREATE INDEX dyn_fk_594d566ac871adb7a8e7 ON public.analytics_daily_metrics USING btree (seller_profile_id);
CREATE INDEX dyn_fk_9f5d026378d99993d59a ON public.analytics_daily_metrics USING btree (sport_id);
CREATE INDEX dyn_fk_b4f596c98899181d7da5 ON public.analytics_daily_metrics USING btree (profile_id);
CREATE INDEX analytics_events_name_idx ON public.analytics_events USING btree (event_name, occurred_at DESC);
CREATE INDEX analytics_events_profile_idx ON public.analytics_events USING btree (profile_id, occurred_at DESC);
CREATE INDEX dyn_fk_0004b8de7641383bd994 ON public.analytics_events USING btree (seller_profile_id);
CREATE INDEX dyn_fk_430d88ea28e7e297b6a0 ON public.analytics_events USING btree (sport_id);
CREATE INDEX dyn_fk_846bf224cd9c0367d006 ON public.analytics_events USING btree (profile_id);
CREATE INDEX dyn_fk_b8dcce93dfb4a2d96935 ON public.analytics_events USING btree (organization_id);
CREATE INDEX audit_logs_action_idx ON public.audit_logs USING btree (action, occurred_at DESC);
CREATE INDEX audit_logs_actor_idx ON public.audit_logs USING btree (actor_profile_id, occurred_at DESC);
CREATE INDEX audit_logs_target_idx ON public.audit_logs USING btree (target_type, target_id, occurred_at DESC);
CREATE INDEX dyn_fk_6e22c05e57dea0b85259 ON public.audit_logs USING btree (actor_profile_id);
CREATE INDEX dyn_fk_9d8590ae7b9261367c59 ON public.audit_logs USING btree (organization_id);
CREATE INDEX background_job_runs_idx ON public.background_job_runs USING btree (job_key, started_at DESC);
CREATE INDEX billing_entitlements_feature_idx ON public.billing_entitlements USING btree (feature_key, ends_at);
CREATE INDEX dyn_fk_7df7b30eadcd07ba2080 ON public.billing_entitlements USING btree (seller_profile_id);
CREATE INDEX dyn_fk_956120a4cb654007a030 ON public.billing_entitlements USING btree (organization_id);
CREATE INDEX dyn_fk_a16b3a978546db9f665b ON public.billing_entitlements USING btree (subscription_id);
CREATE INDEX dyn_fk_b76dfc9b32116a1f1fd7 ON public.billing_entitlements USING btree (profile_id);
CREATE INDEX dyn_fk_4074fecbcd831ffa2ad7 ON public.billing_invoices USING btree (organization_id);
CREATE INDEX dyn_fk_83a6a858225c34c78e12 ON public.billing_invoices USING btree (subscription_id);
CREATE INDEX dyn_fk_afb6abd2efa85fe47ae7 ON public.billing_invoices USING btree (seller_profile_id);
CREATE INDEX dyn_fk_dc35f1df3ffcbbb7731c ON public.billing_invoices USING btree (profile_id);
CREATE INDEX dyn_fk_daefc23bb493072250fc ON public.billing_plan_features USING btree (plan_id);
CREATE INDEX billing_subscriptions_status_idx ON public.billing_subscriptions USING btree (status, current_period_end);
CREATE INDEX dyn_fk_3592cb87157016cb3fa6 ON public.billing_subscriptions USING btree (plan_id);
CREATE INDEX dyn_fk_cd82aefe137219d9a162 ON public.billing_subscriptions USING btree (organization_id);
CREATE INDEX dyn_fk_d82384112a4dd0298554 ON public.billing_subscriptions USING btree (seller_profile_id);
CREATE INDEX dyn_fk_f8ede6433c70a87cd8f5 ON public.billing_subscriptions USING btree (profile_id);
CREATE INDEX billing_usage_events_feature_idx ON public.billing_usage_events USING btree (feature_key, occurred_at DESC);
CREATE INDEX dyn_fk_3295e4cd1ebddd53bdc2 ON public.billing_usage_events USING btree (organization_id);
CREATE INDEX dyn_fk_7cb51aaa78f82143faff ON public.billing_usage_events USING btree (profile_id);
CREATE INDEX dyn_fk_7d0227e50a108ee45995 ON public.billing_usage_events USING btree (subscription_id);
CREATE INDEX dyn_fk_fa936c50b251ff8463b8 ON public.billing_usage_events USING btree (seller_profile_id);
CREATE INDEX bookable_entities_resource_idx ON public.bookable_entities USING btree (organization_resource_id);
CREATE INDEX dyn_fk_49a17c7a1b5e4070f953 ON public.bookable_entities USING btree (sport_id);
CREATE INDEX dyn_fk_609112501b37768c9bd1 ON public.bookable_entities USING btree (owner_id);
CREATE INDEX dyn_fk_c5d362e365ab6f5b7ccc ON public.bookable_entities USING btree (location_id);
CREATE INDEX dyn_fk_1c34d88380fdfa1e5e69 ON public.booking_availability_rules USING btree (bookable_id);
CREATE INDEX dyn_fk_3053f075a97e0367f7b8 ON public.booking_blackouts USING btree (bookable_id);
CREATE INDEX booking_dependencies_required_bookable_idx ON public.booking_dependencies USING btree (required_bookable_id);
CREATE INDEX dyn_fk_5a4766c1fc899ff5c8cd ON public.booking_dependencies USING btree (parent_bookable_id);
CREATE INDEX booking_finance_links_transaction_idx ON public.booking_finance_links USING btree (finance_transaction_id);
CREATE INDEX dyn_fk_2f35a6ec5d08e8394e03 ON public.booking_finance_links USING btree (booking_id);
CREATE INDEX dyn_fk_686b78b47135ee0104d0 ON public.booking_finance_links USING btree (finance_invoice_id);
CREATE INDEX dyn_fk_ee1896d6378cb82543ca ON public.booking_groups USING btree (requested_by);
CREATE INDEX booking_payment_records_status_idx ON public.booking_payment_records USING btree (payment_status);
CREATE INDEX dyn_fk_15e9ee28cfaf256f8193 ON public.booking_payment_records USING btree (organization_id);
CREATE INDEX dyn_fk_460a7722cefd561fc4fe ON public.booking_payment_records USING btree (provider_id);
CREATE INDEX dyn_fk_733632bfc5bf608c5e9b ON public.booking_payment_records USING btree (provider_service_id);
CREATE INDEX dyn_fk_e207149a506777a60189 ON public.booking_payment_records USING btree (booking_id);
CREATE INDEX dyn_fk_a2f768d725cf48778a58 ON public.booking_policies USING btree (bookable_id);
CREATE INDEX booking_waitlist_lookup_idx ON public.booking_waitlist USING btree (bookable_id, requested_starts_at, status, priority DESC, created_at);
CREATE INDEX booking_waitlist_profile_fk_idx ON public.booking_waitlist USING btree (profile_id);
CREATE INDEX dyn_fk_4f1423ff2f92c80c0bf0 ON public.booking_waitlist USING btree (bookable_id);
CREATE INDEX bookings_conflict_lookup_idx ON public.bookings USING btree (bookable_id, starts_at, ends_at) WHERE (status = ANY (ARRAY['pending'::text, 'confirmed'::text]));
CREATE INDEX bookings_user_idx ON public.bookings USING btree (booked_by, starts_at DESC);
CREATE INDEX dyn_fk_88ab13f83a2d1bd2f471 ON public.bookings USING btree (booked_by);
CREATE INDEX dyn_fk_98dd3b684a5011385b73 ON public.bookings USING btree (bookable_id);
CREATE INDEX dyn_fk_bbdf7dbb70e590e37089 ON public.bookings USING btree (booking_group_id);
CREATE INDEX card_delivery_failures_pending_idx ON public.card_delivery_failures USING btree (resolved, attempts) WHERE (NOT resolved);
CREATE INDEX challenge_card_stakes_card_idx ON public.challenge_card_stakes USING btree (card_id);
CREATE INDEX challenge_card_stakes_challenge_idx ON public.challenge_card_stakes USING btree (challenge_id);
CREATE UNIQUE INDEX challenge_card_stakes_one_locked_per_card ON public.challenge_card_stakes USING btree (card_id) WHERE (status = 'locked'::text);
CREATE UNIQUE INDEX challenge_card_stakes_one_locked_per_player ON public.challenge_card_stakes USING btree (challenge_id, profile_id) WHERE (status = 'locked'::text);
CREATE INDEX challenge_card_stakes_profile_idx ON public.challenge_card_stakes USING btree (profile_id);
CREATE INDEX challenge_invitations_challenge_idx ON public.challenge_invitations USING btree (challenge_id, created_at DESC);
CREATE INDEX challenge_invitations_invitee_idx ON public.challenge_invitations USING btree (invitee_id, status, created_at DESC);
CREATE INDEX dyn_fk_247e8240cf4a4cbb0e97 ON public.challenge_invitations USING btree (invitee_id);
CREATE INDEX dyn_fk_9477f2bd0f1d47417130 ON public.challenge_invitations USING btree (inviter_id);
CREATE INDEX dyn_fk_9f55f750a43e53dcd33e ON public.challenge_invitations USING btree (challenge_id);
CREATE INDEX challenge_participants_profile_fk_idx ON public.challenge_participants USING btree (profile_id);
CREATE INDEX dyn_fk_258f82ff03ebabaa6dd0 ON public.challenge_participants USING btree (challenge_id);
CREATE INDEX challenge_share_links_challenge_idx ON public.challenge_share_links USING btree (challenge_id) WHERE is_active;
CREATE INDEX dyn_fk_1dbbdcec9ab45b6dd1f7 ON public.challenge_share_links USING btree (created_by);
CREATE INDEX dyn_fk_90ab30b6b9e1bc0c122d ON public.challenge_share_links USING btree (challenge_id);
CREATE INDEX challenges_sport_status_idx ON public.challenges USING btree (sport_id, status);
CREATE INDEX dyn_fk_7d6580f908ba227a6f2e ON public.challenges USING btree (creator_id);
CREATE INDEX dyn_fk_b435c8780d26d1510bc9 ON public.challenges USING btree (sport_id);
CREATE INDEX content_reports_status_idx ON public.content_reports USING btree (status, created_at);
CREATE INDEX dyn_fk_30781d2c91f7aeeb5c5e ON public.content_reports USING btree (reporter_profile_id);
CREATE INDEX dyn_fk_8e085656d9f926a30404 ON public.content_reports USING btree (resolved_by);
CREATE INDEX conversation_messages_idx ON public.conversation_messages USING btree (conversation_id, created_at DESC);
CREATE INDEX dyn_fk_3503cead368a50299a48 ON public.conversation_messages USING btree (conversation_id);
CREATE INDEX dyn_fk_bd98549c75aa08a268d9 ON public.conversation_messages USING btree (sender_profile_id);
CREATE INDEX conversation_participants_profile_fk_idx ON public.conversation_participants USING btree (profile_id);
CREATE INDEX dyn_fk_536438a541f93945d600 ON public.conversation_participants USING btree (conversation_id);
CREATE INDEX dyn_fk_3bdb1998bd5ae393148e ON public.conversations USING btree (created_by);
CREATE INDEX dyn_fk_cc000d3d8261ec73a4c2 ON public.discovery_blocks USING btree (profile_id);
CREATE INDEX dyn_fk_4fb8f1e74a0a8bde17bd ON public.discovery_controls USING btree (profile_id);
CREATE INDEX discovery_events_reporting_idx ON public.discovery_events USING btree (entity_type, entity_id, event_type, created_at DESC);
CREATE INDEX dyn_fk_7dfd1961c43d861ffc1f ON public.discovery_events USING btree (profile_id);
CREATE INDEX dyn_fk_54b9433e10b0bcfb4afb ON public.discovery_preferences USING btree (profile_id);
CREATE INDEX dynasty_card_transfers_card_idx ON public.dynasty_card_transfers USING btree (card_id);
CREATE UNIQUE INDEX dynasty_card_transfers_card_match_uq ON public.dynasty_card_transfers USING btree (card_id, match_id) WHERE (match_id IS NOT NULL);
CREATE INDEX dynasty_card_transfers_challenge_idx ON public.dynasty_card_transfers USING btree (challenge_id);
CREATE INDEX dynasty_card_transfers_from_idx ON public.dynasty_card_transfers USING btree (from_profile_id);
CREATE INDEX dynasty_card_transfers_match_idx ON public.dynasty_card_transfers USING btree (match_id);
CREATE INDEX dynasty_card_transfers_to_idx ON public.dynasty_card_transfers USING btree (to_profile_id);
CREATE UNIQUE INDEX dynasty_cards_one_base_per_player_sport ON public.dynasty_cards USING btree (original_profile_id, sport_id) WHERE (origin = 'base'::text);
CREATE UNIQUE INDEX dynasty_cards_one_reward_per_match ON public.dynasty_cards USING btree (source_match_id) WHERE (origin = 'win_reward'::text);
CREATE INDEX dynasty_cards_original_idx ON public.dynasty_cards USING btree (original_profile_id);
CREATE INDEX dynasty_cards_owner_idx ON public.dynasty_cards USING btree (owner_profile_id);
CREATE INDEX dynasty_cards_source_match_idx ON public.dynasty_cards USING btree (source_match_id);
CREATE INDEX dynasty_cards_sport_idx ON public.dynasty_cards USING btree (sport_id);
CREATE INDEX idx_dynasty_progression_events_profile_created ON public.dynasty_progression_events USING btree (profile_id, created_at DESC);
CREATE INDEX idx_dynasty_progression_events_sport_id ON public.dynasty_progression_events USING btree (sport_id);
CREATE INDEX entity_availability_lookup_idx ON public.entity_availability USING btree (entity_type, entity_id, availability_status);
CREATE INDEX dyn_fk_f53e39e1528b3c3250f2 ON public.entity_sports USING btree (sport_id);
CREATE UNIQUE INDEX entity_one_primary_sport_idx ON public.entity_sports USING btree (entity_type, entity_id) WHERE is_primary;
CREATE INDEX entity_sports_lookup_idx ON public.entity_sports USING btree (sport_id, entity_type, entity_id);
CREATE INDEX dyn_fk_1634c7094a868bea8f25 ON public.finance_accounts USING btree (organization_id);
CREATE INDEX dyn_fk_610b9b30c9ee8510ed65 ON public.finance_accounts USING btree (profile_id);
CREATE INDEX dyn_fk_1da7a36b44f239b69a88 ON public.finance_categories USING btree (parent_id);
CREATE INDEX dyn_fk_99e0b870b9496e2cc5ef ON public.finance_categories USING btree (activity_id);
CREATE INDEX dyn_fk_c49463e870f6c36884c5 ON public.finance_categories USING btree (profile_id);
CREATE INDEX dyn_fk_cebb7b72e35422fb0f82 ON public.finance_categories USING btree (organization_id);
CREATE INDEX dyn_fk_6e2cb9bdedeb6ef335a7 ON public.finance_invoices USING btree (profile_id);
CREATE INDEX dyn_fk_d65d09f10697e0f69ee9 ON public.finance_invoices USING btree (activity_id);
CREATE INDEX dyn_fk_e56bbd0fc524aa610c87 ON public.finance_invoices USING btree (organization_id);
CREATE INDEX finance_invoices_org_status_idx ON public.finance_invoices USING btree (organization_id, status, due_date);
CREATE INDEX dyn_fk_2816dce63a285b5829c5 ON public.finance_recurring_items USING btree (account_id);
CREATE INDEX dyn_fk_8d1398362a5f3a9457b8 ON public.finance_recurring_items USING btree (category_id);
CREATE INDEX dyn_fk_92bccb07f6748b6e5c38 ON public.finance_recurring_items USING btree (profile_id);
CREATE INDEX dyn_fk_9691fa1cf4442b5ebf3c ON public.finance_recurring_items USING btree (organization_id);
CREATE INDEX dyn_fk_11e9e6e0cae2cdb083ce ON public.finance_transactions USING btree (created_by);
CREATE INDEX dyn_fk_2d7a4bb1aa4ea5e5d3a6 ON public.finance_transactions USING btree (organization_id);
CREATE INDEX dyn_fk_376e052d275882dc359d ON public.finance_transactions USING btree (profile_id);
CREATE INDEX dyn_fk_8e1348f981df3a27aefc ON public.finance_transactions USING btree (account_id);
CREATE INDEX dyn_fk_a5f2199ef902ad1adef9 ON public.finance_transactions USING btree (activity_id);
CREATE INDEX dyn_fk_a89d6565f36073be65ea ON public.finance_transactions USING btree (category_id);
CREATE INDEX finance_transactions_org_date_idx ON public.finance_transactions USING btree (organization_id, occurred_at DESC);
CREATE INDEX finance_transactions_profile_date_idx ON public.finance_transactions USING btree (profile_id, occurred_at DESC);
CREATE UNIQUE INDEX finance_transactions_unique_payment_income ON public.finance_transactions USING btree (source_type, source_id, transaction_type) WHERE ((source_type = 'payment'::text) AND (transaction_type = 'income'::text));
CREATE UNIQUE INDEX finance_transactions_unique_refund_record ON public.finance_transactions USING btree (source_type, source_id, transaction_type) WHERE ((source_type = 'payment_refund'::text) AND (transaction_type = 'expense'::text));
CREATE INDEX dyn_fk_7e0be4df295563b16ab1 ON public.intelligence_signals USING btree (sport_id);
CREATE INDEX dyn_fk_9032aea9e3eead9d0c00 ON public.intelligence_signals USING btree (profile_id);
CREATE INDEX intelligence_signals_profile_idx ON public.intelligence_signals USING btree (profile_id, occurred_at DESC);
CREATE INDEX dyn_fk_d3b4343fb1ccef1a8371 ON public.locale_translations USING btree (locale_code);
CREATE INDEX marketplace_item_returns_order_item_id_idx ON public.marketplace_item_returns USING btree (order_item_id);
CREATE UNIQUE INDEX marketplace_item_returns_provider_refund_uq ON public.marketplace_item_returns USING btree (provider_refund_id) WHERE (provider_refund_id IS NOT NULL);
CREATE INDEX dyn_fk_1348e0744e554f7b1780 ON public.marketplace_listing_analytics_daily USING btree (listing_id);
CREATE INDEX dyn_fk_63a7874ddbf1a1049a81 ON public.marketplace_listing_delivery_options USING btree (listing_id);
CREATE INDEX marketplace_delivery_listing_idx ON public.marketplace_listing_delivery_options USING btree (listing_id, is_active);
CREATE INDEX dyn_fk_e34e77858ebc4b89b6c3 ON public.marketplace_listing_inventory USING btree (listing_id);
CREATE INDEX dyn_fk_287ebcf30fb1108094cd ON public.marketplace_listings USING btree (sport_id);
CREATE INDEX dyn_fk_64cf299504bd2851cb47 ON public.marketplace_listings USING btree (owner_id);
CREATE INDEX dyn_fk_f728d52ae8151736c951 ON public.marketplace_listings USING btree (seller_id);
CREATE INDEX marketplace_geo_idx ON public.marketplace_listings USING gist (coordinates) WHERE ((coordinates IS NOT NULL) AND (status = 'published'::text));
CREATE INDEX marketplace_listings_discovery_idx ON public.marketplace_listings USING btree (listing_type, status, sport_id, city);
CREATE INDEX marketplace_listings_location_idx ON public.marketplace_listings USING btree (country_code, city, sport_id, status);
CREATE INDEX marketplace_listings_seller_idx ON public.marketplace_listings USING btree (seller_id, status);
CREATE INDEX idx_marketplace_order_items_order ON public.marketplace_order_items USING btree (order_id);
CREATE INDEX idx_marketplace_order_items_seller ON public.marketplace_order_items USING btree (seller_id, created_at DESC);
CREATE INDEX marketplace_order_items_listing_id_idx ON public.marketplace_order_items USING btree (listing_id);
CREATE INDEX idx_marketplace_order_payments_order ON public.marketplace_order_payments USING btree (order_id);
CREATE UNIQUE INDEX marketplace_order_refunds_provider_refund_uidx ON public.marketplace_order_refunds USING btree (provider_refund_id);
CREATE INDEX idx_marketplace_orders_buyer ON public.marketplace_orders USING btree (buyer_id, created_at DESC);
CREATE INDEX dyn_fk_722e4371319d5d3584c9 ON public.marketplace_promotions USING btree (listing_id);
CREATE INDEX marketplace_promotions_listing_idx ON public.marketplace_promotions USING btree (listing_id, status);
CREATE INDEX dyn_fk_125fbcbd851e57b4d598 ON public.marketplace_seller_profiles USING btree (organization_id);
CREATE INDEX dyn_fk_93068a03e26e70661bd7 ON public.marketplace_seller_profiles USING btree (owner_id);
CREATE UNIQUE INDEX marketplace_seller_settlements_payout_uq ON public.marketplace_seller_settlements USING btree (provider_payout_id) WHERE (provider_payout_id IS NOT NULL);
CREATE INDEX marketplace_seller_settlements_seller_id_idx ON public.marketplace_seller_settlements USING btree (seller_id);
CREATE INDEX dyn_fk_65d4d191163cdb35b8fc ON public.match_results USING btree (winner_profile_id);
CREATE INDEX dyn_fk_a2f5d0c53ad96035b5fd ON public.match_results USING btree (match_id);
CREATE INDEX dyn_fk_da62cade8a761357c80f ON public.match_results USING btree (submitted_by);
CREATE UNIQUE INDEX match_results_match_id_uidx ON public.match_results USING btree (match_id);
CREATE INDEX dyn_fk_1b2ba950bbab5fc0a51c ON public.matches USING btree (sport_id);
CREATE INDEX dyn_fk_7d800754c8e4d95575d4 ON public.matches USING btree (challenge_id);
CREATE INDEX matches_sport_status_idx ON public.matches USING btree (sport_id, status);
CREATE INDEX idx_missions_sport_id ON public.missions USING btree (sport_id);
CREATE INDEX dyn_fk_9ff4e8b8b745a94b82b0 ON public.moderation_actions USING btree (actor_profile_id);
CREATE INDEX dyn_fk_6eb856b8171010d74d84 ON public.notification_deliveries USING btree (notification_id);
CREATE INDEX notification_deliveries_status_idx ON public.notification_deliveries USING btree (status, created_at DESC);
CREATE INDEX dyn_fk_52aa0e9d2169a38d138a ON public.notification_devices USING btree (profile_id);
CREATE INDEX dyn_fk_037a5b337be63e65032e ON public.notification_preferences USING btree (profile_id);
CREATE INDEX dyn_fk_b4591befb7e2ba473c03 ON public.notifications USING btree (profile_id);
CREATE UNIQUE INDEX notifications_booking_event_unique ON public.notifications USING btree (profile_id, source_type, source_id, type) WHERE (source_type = 'booking'::text);
CREATE INDEX notifications_profile_idx ON public.notifications USING btree (profile_id, created_at DESC);
CREATE INDEX dyn_fk_9a115fcba201a8cfeccb ON public.organization_activities USING btree (sport_id);
CREATE INDEX dyn_fk_dc4290efc16e5ade6765 ON public.organization_activities USING btree (organization_id);
CREATE INDEX organization_activities_location_fk_idx ON public.organization_activities USING btree (location_id);
CREATE INDEX organization_activities_org_idx ON public.organization_activities USING btree (organization_id, is_active);
CREATE INDEX dyn_fk_a1efc6f66b968c3f5505 ON public.organization_activity_memberships USING btree (organization_membership_id);
CREATE INDEX organization_activity_memberships_activity_fk_idx ON public.organization_activity_memberships USING btree (activity_id);
CREATE INDEX dyn_fk_b43b09cdf3b6a9e24599 ON public.organization_locations USING btree (organization_id);
CREATE INDEX dyn_fk_3be10e49f7a81ca09247 ON public.organization_member_roles USING btree (membership_id);
CREATE INDEX organization_member_roles_role_fk_idx ON public.organization_member_roles USING btree (role_id);
CREATE INDEX dyn_fk_e12d44dc768a735d7566 ON public.organization_memberships USING btree (organization_id);
CREATE INDEX organization_memberships_profile_idx ON public.organization_memberships USING btree (profile_id, status);
CREATE INDEX idx_organization_resources_sport_id ON public.organization_resources USING btree (sport_id);
CREATE INDEX organization_resources_location_idx ON public.organization_resources USING btree (location_id, status);
CREATE INDEX organization_resources_org_idx ON public.organization_resources USING btree (organization_id, status);
CREATE INDEX dyn_fk_d68acc1d883177dc0fa1 ON public.organization_role_permissions USING btree (role_id);
CREATE INDEX organization_role_permissions_permission_fk_idx ON public.organization_role_permissions USING btree (permission_id);
CREATE INDEX dyn_fk_8e1e2674f9f6f0de3e49 ON public.organization_roles USING btree (organization_id);
CREATE INDEX dyn_fk_2d17f0a47ac46c9b37df ON public.organizations USING btree (owner_id);
CREATE INDEX pair_profiles_player_1_idx ON public.pair_profiles USING btree (player_1);
CREATE INDEX pair_profiles_player_2_idx ON public.pair_profiles USING btree (player_2);
CREATE INDEX partner_preferences_sport_id_idx ON public.partner_preferences USING btree (sport_id);
CREATE INDEX idx_partner_requests_recipient_status ON public.partner_requests USING btree (recipient_id, status, created_at DESC);
CREATE INDEX idx_partner_requests_requester_status ON public.partner_requests USING btree (requester_id, status, created_at DESC);
CREATE INDEX idx_payment_records_booking_id ON public.payment_records USING btree (booking_id);
CREATE INDEX idx_payment_records_payer_profile_id ON public.payment_records USING btree (payer_profile_id);
CREATE UNIQUE INDEX payment_records_provider_event_uidx ON public.payment_records USING btree (provider_event_id) WHERE (provider_event_id IS NOT NULL);
CREATE UNIQUE INDEX payment_records_provider_payment_uidx ON public.payment_records USING btree (provider_payment_id);
CREATE UNIQUE INDEX payment_refunds_provider_refund_uidx ON public.payment_refunds USING btree (provider_refund_id) WHERE (provider_refund_id IS NOT NULL);
CREATE INDEX idx_platform_test_assertions_run ON public.platform_test_assertions USING btree (run_id);
CREATE UNIQUE INDEX uq_platform_test_assertion ON public.platform_test_assertions USING btree (run_id, assertion_key);
CREATE INDEX dyn_fk_e5d6df3d08db44e93887 ON public.player_achievements USING btree (profile_id);
CREATE INDEX player_achievements_achievement_fk_idx ON public.player_achievements USING btree (achievement_id);
CREATE INDEX dyn_fk_5cc82046df76fa15600e ON public.player_availability USING btree (sport_id);
CREATE INDEX dyn_fk_db080ba9265c8670b745 ON public.player_availability USING btree (profile_id);
CREATE INDEX player_availability_active_idx ON public.player_availability USING btree (sport_id, starts_at) WHERE is_active;
CREATE INDEX player_availability_profile_idx ON public.player_availability USING btree (profile_id, starts_at DESC);
CREATE INDEX dyn_fk_5f82d40124a3c87dc133 ON public.player_cards USING btree (card_definition_id);
CREATE INDEX dyn_fk_daca5349bdf10ee1c81a ON public.player_cards USING btree (profile_id);
CREATE INDEX player_cards_profile_earned_idx ON public.player_cards USING btree (profile_id, earned_at DESC);
CREATE INDEX dyn_fk_b553659eeaf5954a040e ON public.player_progression USING btree (profile_id);
CREATE INDEX dyn_fk_644e725d92e14724b47e ON public.player_rivalries USING btree (sport_id);
CREATE INDEX dyn_fk_8fa9770099b6d0661a3b ON public.player_rivalries USING btree (player_two_id);
CREATE INDEX player_rivalries_player_one_fk_idx ON public.player_rivalries USING btree (player_one_id);
CREATE INDEX idx_player_season_progression_season ON public.player_season_progression USING btree (season_id, xp_earned DESC, wins DESC);
CREATE INDEX idx_player_season_progression_sport_id ON public.player_season_progression USING btree (sport_id);
CREATE INDEX idx_player_sport_streaks_sport_id ON public.player_sport_streaks USING btree (sport_id);
CREATE INDEX dyn_fk_82f092e6ea26faba3b83 ON public.player_sports USING btree (profile_id);
CREATE UNIQUE INDEX player_one_primary_sport_idx ON public.player_sports USING btree (profile_id) WHERE is_primary;
CREATE INDEX player_sports_discovery_idx ON public.player_sports USING btree (sport_id, relationship) WHERE is_discoverable;
CREATE INDEX dyn_fk_53d85c7e77a685bc5433 ON public.profile_locale_preferences USING btree (profile_id);
CREATE INDEX dyn_fk_66384e723c7d5ff94699 ON public.profile_locale_preferences USING btree (locale_code);
CREATE INDEX dyn_fk_4657e1aceca1dfb54c62 ON public.profile_locations USING btree (profile_id);
CREATE INDEX profile_locations_city_idx ON public.profile_locations USING btree (country_code, city) WHERE is_discoverable;
CREATE INDEX profile_locations_geo_idx ON public.profile_locations USING gist (coordinates) WHERE ((coordinates IS NOT NULL) AND is_discoverable);
CREATE INDEX dyn_fk_75089c065e00f2e8272c ON public.profiles USING btree (id);
CREATE INDEX dyn_fk_5a9b45b68cc8d4f8d277 ON public.promotion_events USING btree (promotion_id);
CREATE INDEX dyn_fk_88711de4385ce1bf2bb1 ON public.promotion_events USING btree (profile_id);
CREATE INDEX promotion_events_reporting_idx ON public.promotion_events USING btree (promotion_id, event_type, created_at DESC);
CREATE INDEX dyn_fk_941854bb076d36536e11 ON public.promotions USING btree (listing_id);
CREATE INDEX dyn_fk_14132e2c96bd518a9319 ON public.provider_availability USING btree (provider_id);
CREATE INDEX dyn_fk_fa0e5120eb69503e6cf9 ON public.provider_availability USING btree (organization_id);
CREATE INDEX dyn_fk_6511e399b47e13eead11 ON public.provider_organization_relationships USING btree (membership_id);
CREATE INDEX dyn_fk_94b7c191dbf837e06031 ON public.provider_organization_relationships USING btree (provider_id);
CREATE INDEX provider_relationships_org_idx ON public.provider_organization_relationships USING btree (organization_id, status);
CREATE INDEX dyn_fk_f834aff35fc09d2900a1 ON public.provider_profiles USING btree (profile_id);
CREATE INDEX dyn_fk_3a59f11f1e350763604c ON public.provider_service_booking_links USING btree (provider_id);
CREATE INDEX dyn_fk_6436e38e4a4cac9b94d5 ON public.provider_service_booking_links USING btree (organization_id);
CREATE INDEX dyn_fk_d7e574bb16ff5b748e5d ON public.provider_service_booking_links USING btree (provider_service_id);
CREATE INDEX dyn_fk_ff067a0da0437cfefa3f ON public.provider_service_booking_links USING btree (bookable_id);
CREATE INDEX dyn_fk_233aca884f68e6dfeb2b ON public.provider_services USING btree (provider_id);
CREATE INDEX dyn_fk_48df043c7c0944894464 ON public.provider_services USING btree (organization_id);
CREATE INDEX dyn_fk_b56951ebc805bcd4867f ON public.provider_services USING btree (activity_id);
CREATE INDEX provider_services_org_idx ON public.provider_services USING btree (organization_id, status);
CREATE INDEX provider_services_provider_idx ON public.provider_services USING btree (provider_id, status);
CREATE INDEX dyn_fk_df7526376718e6f2e76d ON public.provider_students USING btree (organization_id);
CREATE INDEX dyn_fk_f1cb40ec43e0ce17c585 ON public.provider_students USING btree (provider_id);
CREATE INDEX provider_students_profile_fk_idx ON public.provider_students USING btree (profile_id);
CREATE INDEX provider_students_provider_idx ON public.provider_students USING btree (provider_id, status);
CREATE INDEX rate_limit_hits_bucket_created_idx ON public.rate_limit_hits USING btree (bucket, created_at DESC);
CREATE INDEX idx_rating_history_sport_id ON public.rating_history USING btree (sport_id);
CREATE UNIQUE INDEX rating_history_match_profile_once_idx ON public.rating_history USING btree (source_match_id, profile_id) WHERE (source_match_id IS NOT NULL);
CREATE UNIQUE INDEX rating_history_profile_match_uidx ON public.rating_history USING btree (profile_id, source_match_id) WHERE (source_match_id IS NOT NULL);
CREATE INDEX rating_history_profile_sport_created_idx ON public.rating_history USING btree (profile_id, sport_id, created_at DESC);
CREATE UNIQUE INDEX rating_history_profile_sport_match_unique ON public.rating_history USING btree (profile_id, sport_id, source_match_id) WHERE (source_match_id IS NOT NULL);
CREATE INDEX dyn_fk_3c4eb8b2febf2913cc35 ON public.recommendation_candidates USING btree (sport_id);
CREATE INDEX recommendation_candidates_location_idx ON public.recommendation_candidates USING btree (country_code, region, city, sport_id, status);
CREATE INDEX dyn_fk_4c9f98a7b8c3521c838b ON public.recommendation_explanations USING btree (profile_id);
CREATE INDEX recommendation_explanations_lookup_idx ON public.recommendation_explanations USING btree (profile_id, entity_type, entity_id, created_at DESC);
CREATE INDEX dyn_fk_3afa2c055a7bad7791ae ON public.recommendation_impressions USING btree (profile_id);
CREATE INDEX dyn_fk_c8dc392db5463e31ea27 ON public.recommendation_impressions USING btree (candidate_id);
CREATE INDEX recommendation_impressions_profile_idx ON public.recommendation_impressions USING btree (profile_id, created_at DESC);
CREATE INDEX dyn_fk_662e9c7edfe6ef500830 ON public.recommendation_preferences USING btree (profile_id);
CREATE INDEX dyn_fk_ae28bce797a3f395ad5c ON public.referral_codes USING btree (profile_id);
CREATE INDEX dyn_fk_06c1c49b048399e8faaa ON public.referrals USING btree (referrer_id);
CREATE INDEX dyn_fk_67f4aa3f7f0fdba1d170 ON public.referrals USING btree (referred_profile_id);
CREATE INDEX dyn_fk_bc9c99b70acae98bd5b3 ON public.referrals USING btree (referral_code_id);
CREATE INDEX referrals_referrer_idx ON public.referrals USING btree (referrer_id, status, created_at DESC);
CREATE INDEX dyn_fk_6aa747eb58f153e446d8 ON public.relevance_feedback USING btree (profile_id);
CREATE INDEX relevance_feedback_profile_idx ON public.relevance_feedback USING btree (profile_id, entity_type, created_at DESC);
CREATE INDEX dyn_fk_97dace732146f8fb2625 ON public.search_documents USING btree (sport_id);
CREATE INDEX search_documents_context_idx ON public.search_documents USING btree (sport_id, country_code, city, status);
CREATE INDEX search_documents_text_idx ON public.search_documents USING gin (to_tsvector('simple'::regconfig, search_text));
CREATE INDEX idx_seasons_sport_id ON public.seasons USING btree (sport_id);
CREATE INDEX dyn_fk_ec3a0dc4c07237379c7b ON public.security_events USING btree (profile_id);
CREATE INDEX security_events_status_idx ON public.security_events USING btree (status, severity, created_at DESC);
CREATE INDEX dyn_fk_1864918c091a203edc02 ON public.share_event_actions USING btree (actor_id);
CREATE INDEX dyn_fk_b8e8ca374fab7f5257c7 ON public.share_event_actions USING btree (shareable_event_id);
CREATE INDEX share_event_actions_event_idx ON public.share_event_actions USING btree (shareable_event_id, created_at DESC);
CREATE INDEX dyn_fk_49e2a0a0cf699118be8b ON public.shareable_events USING btree (profile_id);
CREATE INDEX shareable_events_profile_idx ON public.shareable_events USING btree (profile_id, created_at DESC);
CREATE INDEX shareable_events_type_idx ON public.shareable_events USING btree (event_type, created_at DESC);
CREATE INDEX idx_shop_cart_items_product_id ON public.shop_cart_items USING btree (product_id);
CREATE INDEX idx_shop_cart_items_variant_id ON public.shop_cart_items USING btree (variant_id);
CREATE UNIQUE INDEX shop_cart_items_unique_variant ON public.shop_cart_items USING btree (cart_id, product_id, variant_id);
CREATE UNIQUE INDEX shop_carts_one_active_per_profile ON public.shop_carts USING btree (profile_id) WHERE (status = 'ACTIVE'::text);
CREATE INDEX idx_shop_customers_profile_id ON public.shop_customers USING btree (profile_id);
CREATE INDEX shop_customers_email_idx ON public.shop_customers USING btree (email);
CREATE INDEX shop_customers_phone_idx ON public.shop_customers USING btree (phone);
CREATE INDEX idx_shop_inventory_adjustments_location_id ON public.shop_inventory_adjustments USING btree (location_id);
CREATE INDEX idx_shop_inventory_adjustments_variant_id ON public.shop_inventory_adjustments USING btree (variant_id);
CREATE INDEX shop_inventory_levels_variant_idx ON public.shop_inventory_levels USING btree (variant_id);
CREATE INDEX idx_shop_inventory_movements_created_by ON public.shop_inventory_movements USING btree (created_by);
CREATE INDEX ix_shop_inventory_movements_location_created ON public.shop_inventory_movements USING btree (location_id, created_at DESC);
CREATE INDEX shop_inventory_movements_variant_idx ON public.shop_inventory_movements USING btree (variant_id, created_at DESC);
CREATE INDEX idx_shop_inventory_reservations_variant_id ON public.shop_inventory_reservations USING btree (variant_id);
CREATE INDEX shop_inventory_reservations_location_idx ON public.shop_inventory_reservations USING btree (location_id, variant_id, status);
CREATE INDEX idx_shop_invoices_customer_id ON public.shop_invoices USING btree (customer_id);
CREATE INDEX shop_location_inventory_variant_idx ON public.shop_location_inventory USING btree (variant_id);
CREATE UNIQUE INDEX shop_locations_one_online_idx ON public.shop_locations USING btree (location_type) WHERE (location_type = 'online'::text);
CREATE INDEX dyn_fk_7f69a159a9da0c0ddccc ON public.shop_order_items USING btree (variant_id);
CREATE INDEX dyn_fk_9617dbb8d2a0e427a615 ON public.shop_order_items USING btree (product_id);
CREATE INDEX dyn_fk_b1b60df75f7a4bbb12d1 ON public.shop_order_items USING btree (order_id);
CREATE INDEX idx_shop_order_payments_order_id ON public.shop_order_payments USING btree (order_id);
CREATE UNIQUE INDEX shop_order_payments_provider_event_uidx ON public.shop_order_payments USING btree (provider, provider_event_id) WHERE (provider_event_id IS NOT NULL);
CREATE UNIQUE INDEX shop_order_payments_provider_payment_uidx ON public.shop_order_payments USING btree (provider, provider_payment_id) WHERE (provider_payment_id IS NOT NULL);
CREATE INDEX dyn_fk_2f18648bc1af0dedb961 ON public.shop_orders USING btree (profile_id);
CREATE INDEX idx_shop_orders_fulfillment_location_id ON public.shop_orders USING btree (fulfillment_location_id);
CREATE INDEX ix_shop_orders_channel_created ON public.shop_orders USING btree (sales_channel, created_at DESC);
CREATE INDEX ix_shop_orders_profile_created ON public.shop_orders USING btree (profile_id, created_at DESC);
CREATE INDEX shop_orders_channel_location_idx ON public.shop_orders USING btree (sales_channel, fulfillment_location_id, created_at DESC);
CREATE INDEX shop_pos_payments_sale_idx ON public.shop_pos_payments USING btree (sale_id);
CREATE UNIQUE INDEX shop_pos_registers_one_open_per_location ON public.shop_pos_registers USING btree (location_id) WHERE (status = 'open'::text);
CREATE INDEX idx_shop_pos_sale_items_product_id ON public.shop_pos_sale_items USING btree (product_id);
CREATE INDEX idx_shop_pos_sale_items_variant_id ON public.shop_pos_sale_items USING btree (variant_id);
CREATE INDEX shop_pos_sale_items_sale_idx ON public.shop_pos_sale_items USING btree (sale_id);
CREATE INDEX idx_shop_pos_sales_created_by ON public.shop_pos_sales USING btree (created_by);
CREATE INDEX idx_shop_pos_sales_invoice_id ON public.shop_pos_sales USING btree (invoice_id);
CREATE INDEX idx_shop_pos_sales_register_id ON public.shop_pos_sales USING btree (register_id);
CREATE INDEX ix_shop_pos_sales_customer_created ON public.shop_pos_sales USING btree (customer_id, created_at DESC);
CREATE INDEX ix_shop_pos_sales_location_created ON public.shop_pos_sales USING btree (location_id, created_at DESC);
CREATE INDEX shop_pos_sales_channel_location_id_idx ON public.shop_pos_sales USING btree (channel_location_id);
CREATE INDEX dyn_fk_9dbd97a55331d2352738 ON public.shop_product_variants USING btree (product_id);
CREATE INDEX dyn_fk_15d1050094d2dfd6ca0e ON public.shop_products USING btree (sport_id);
CREATE INDEX shop_products_active_idx ON public.shop_products USING btree (status, featured);
CREATE INDEX shop_products_sport_idx ON public.shop_products USING btree (sport_id, status);
CREATE INDEX idx_shop_registers_closed_by ON public.shop_registers USING btree (closed_by);
CREATE INDEX idx_shop_registers_location_id ON public.shop_registers USING btree (location_id);
CREATE INDEX idx_shop_registers_opened_by ON public.shop_registers USING btree (opened_by);
CREATE INDEX idx_shop_return_items_sale_item_id ON public.shop_return_items USING btree (sale_item_id);
CREATE INDEX idx_shop_return_items_variant_id ON public.shop_return_items USING btree (variant_id);
CREATE INDEX shop_return_items_return_idx ON public.shop_return_items USING btree (return_id);
CREATE INDEX idx_shop_returns_customer_id ON public.shop_returns USING btree (customer_id);
CREATE INDEX idx_shop_returns_location_id ON public.shop_returns USING btree (location_id);
CREATE INDEX shop_returns_sale_idx ON public.shop_returns USING btree (sale_id);
CREATE INDEX shop_staff_profile_idx ON public.shop_staff USING btree (profile_id);
CREATE INDEX idx_skill_challenges_sport_created ON public.skill_challenges USING btree (sport_id, created_at DESC);
CREATE INDEX skill_challenges_creator_id_idx ON public.skill_challenges USING btree (creator_id);
CREATE INDEX skill_comments_submission_id_idx ON public.skill_comments USING btree (submission_id);
CREATE INDEX skill_comments_user_id_idx ON public.skill_comments USING btree (user_id);
CREATE INDEX idx_skill_submissions_challenge ON public.skill_submissions USING btree (challenge_id, created_at DESC);
CREATE INDEX skill_submissions_user_id_idx ON public.skill_submissions USING btree (user_id);
CREATE INDEX skill_votes_user_id_idx ON public.skill_votes USING btree (user_id);
CREATE INDEX dyn_fk_9f124d33386d4514b125 ON public.social_comments USING btree (post_id);
CREATE INDEX dyn_fk_da91d655f50d5d6ae251 ON public.social_comments USING btree (author_profile_id);
CREATE INDEX dyn_fk_e3231db33de42306d5cf ON public.social_comments USING btree (parent_comment_id);
CREATE INDEX social_comments_post_idx ON public.social_comments USING btree (post_id, created_at);
CREATE INDEX dyn_fk_8269bf4b05d31e1b4fcf ON public.social_follows USING btree (follower_profile_id);
CREATE INDEX social_follows_followed_idx ON public.social_follows USING btree (followed_profile_id, created_at DESC);
CREATE INDEX dyn_fk_2dae241c19e6da7bf08c ON public.social_posts USING btree (author_profile_id);
CREATE INDEX dyn_fk_899b4feab652ba1dead1 ON public.social_posts USING btree (sport_id);
CREATE INDEX social_posts_author_idx ON public.social_posts USING btree (author_profile_id, created_at DESC);
CREATE INDEX social_posts_sport_idx ON public.social_posts USING btree (sport_id, created_at DESC);
CREATE INDEX dyn_fk_7b8b34e38798fb5795c5 ON public.social_reactions USING btree (post_id);
CREATE INDEX social_reactions_profile_fk_idx ON public.social_reactions USING btree (profile_id);
CREATE INDEX dyn_fk_d0e91303eb9652e303f8 ON public.social_share_actions USING btree (profile_id);
CREATE INDEX dyn_fk_f2fc51edcfaf5446622e ON public.social_share_actions USING btree (share_card_id);
CREATE INDEX dyn_fk_f90e8506d2e5b8f4085d ON public.social_share_cards USING btree (profile_id);
CREATE INDEX dyn_fk_234f1df4127e55b0185a ON public.social_share_events USING btree (challenge_id);
CREATE INDEX dyn_fk_a2194b5311bdef5756cd ON public.social_share_events USING btree (share_link_id);
CREATE INDEX dyn_fk_c0fe374633a83bf528f4 ON public.social_share_events USING btree (actor_id);
CREATE INDEX social_share_events_challenge_idx ON public.social_share_events USING btree (challenge_id, created_at DESC);
CREATE INDEX sport_rankings_sport_rating_idx ON public.sport_rankings USING btree (sport_id, rating DESC, profile_id);
CREATE INDEX dyn_fk_66fcf49d7dbdd86f88af ON public.support_ticket_messages USING btree (ticket_id);
CREATE INDEX dyn_fk_c7e47c0385807bcc2818 ON public.support_ticket_messages USING btree (author_profile_id);
CREATE INDEX dyn_fk_009987fc047898edc86d ON public.support_tickets USING btree (assigned_to);
CREATE INDEX dyn_fk_aaa1a3079ce294d22258 ON public.support_tickets USING btree (requester_profile_id);
CREATE INDEX support_tickets_status_idx ON public.support_tickets USING btree (status, priority, created_at);
CREATE UNIQUE INDEX supported_locales_one_default ON public.supported_locales USING btree (is_default) WHERE (is_default = true);
CREATE INDEX dyn_fk_88c4954cb794e88f7293 ON public.tournament_categories USING btree (tournament_id);
CREATE INDEX dyn_fk_b1168b29bd5c403c67bb ON public.tournament_checkins USING btree (checked_in_by);
CREATE INDEX dyn_fk_d3160ff49bcd3595f529 ON public.tournament_checkins USING btree (entry_id);
CREATE INDEX idx_tournament_checkins_entry_profile ON public.tournament_checkins USING btree (entry_id, profile_id);
CREATE INDEX tournament_checkins_profile_fk_idx ON public.tournament_checkins USING btree (profile_id);
CREATE INDEX dyn_fk_8cb11d7b9d47e7259490 ON public.tournament_entries USING btree (tournament_id);
CREATE INDEX dyn_fk_9a22d90031a4cbd20a8e ON public.tournament_entries USING btree (captain_profile_id);
CREATE INDEX dyn_fk_c08ff91c3a31190561be ON public.tournament_entries USING btree (category_id);
CREATE INDEX idx_tournament_entries_tournament_status ON public.tournament_entries USING btree (tournament_id, status);
CREATE INDEX tournament_entries_category_status_idx ON public.tournament_entries USING btree (category_id, status);
CREATE INDEX dyn_fk_55ec943c284a12342bda ON public.tournament_entry_members USING btree (entry_id);
CREATE INDEX tournament_entry_members_profile_fk_idx ON public.tournament_entry_members USING btree (profile_id);
CREATE INDEX dyn_fk_29e0f7fa70999a7bd8c2 ON public.tournament_fixtures USING btree (stage_id);
CREATE INDEX dyn_fk_3c85a7bc9b43c85d9aa7 ON public.tournament_fixtures USING btree (winner_entry_id);
CREATE INDEX dyn_fk_715b7e5820434f47aa63 ON public.tournament_fixtures USING btree (category_id);
CREATE INDEX dyn_fk_778249115a48eaa5f675 ON public.tournament_fixtures USING btree (next_fixture_id);
CREATE INDEX dyn_fk_b69376bd7a1175f252d3 ON public.tournament_fixtures USING btree (side_a_entry_id);
CREATE INDEX dyn_fk_bed3cec367cc3c90e3ed ON public.tournament_fixtures USING btree (side_b_entry_id);
CREATE INDEX dyn_fk_c2b550f50d083ed82177 ON public.tournament_fixtures USING btree (match_id);
CREATE INDEX dyn_fk_ceb029996037327f8eca ON public.tournament_fixtures USING btree (group_id);
CREATE INDEX dyn_fk_eb1ae31bea7baa9d05cb ON public.tournament_fixtures USING btree (tournament_id);
CREATE INDEX idx_tournament_fixtures_tournament_status ON public.tournament_fixtures USING btree (tournament_id, status);
CREATE INDEX tournament_fixtures_stage_idx ON public.tournament_fixtures USING btree (stage_id, round_number);
CREATE INDEX dyn_fk_9dd3d5086f55f58d27b1 ON public.tournament_group_entries USING btree (group_id);
CREATE INDEX tournament_group_entries_entry_fk_idx ON public.tournament_group_entries USING btree (entry_id);
CREATE INDEX dyn_fk_210a16eb6cdc28a4a5c8 ON public.tournament_groups USING btree (stage_id);
CREATE INDEX dyn_fk_425390a13688427ebe46 ON public.tournament_prizes USING btree (tournament_id);
CREATE INDEX dyn_fk_fb649832b2aa672c7ce3 ON public.tournament_prizes USING btree (category_id);
CREATE INDEX dyn_fk_03570c32e2dfd99f0016 ON public.tournament_registration_payments USING btree (entry_id);
CREATE INDEX dyn_fk_7f663bfe8b757ecd49e6 ON public.tournament_sponsors USING btree (tournament_id);
CREATE INDEX dyn_fk_bdfa140c9093b1ce158f ON public.tournament_stages USING btree (tournament_id);
CREATE INDEX tournament_stages_category_fk_idx ON public.tournament_stages USING btree (category_id);
CREATE INDEX dyn_fk_9e6de53fb5324a83d709 ON public.tournaments USING btree (sport_id);
CREATE INDEX dyn_fk_d591c9fef4cb38f4cffe ON public.tournaments USING btree (organizer_profile_id);
CREATE INDEX dyn_fk_f55b203f7bed22e42653 ON public.tournaments USING btree (organization_id);
CREATE INDEX tournaments_status_idx ON public.tournaments USING btree (status, starts_at);
CREATE INDEX dyn_fk_daf1942f9f2bc3d7d442 ON public.user_blocks USING btree (blocker_profile_id);
CREATE INDEX user_blocks_blocked_profile_fk_idx ON public.user_blocks USING btree (blocked_profile_id);
CREATE INDEX idx_user_missions_mission_id ON public.user_missions USING btree (mission_id);
CREATE INDEX weekly_challenge_participants_challenge_id_idx ON public.weekly_challenge_participants USING btree (challenge_id);
CREATE INDEX weekly_challenge_participants_status_idx ON public.weekly_challenge_participants USING btree (status);
CREATE INDEX weekly_challenge_submissions_challenge_day_idx ON public.weekly_challenge_submissions USING btree (challenge_id, day);
CREATE INDEX weekly_challenge_submissions_participant_id_idx ON public.weekly_challenge_submissions USING btree (participant_id);
CREATE INDEX dyn_fk_072e995904d355de332c ON public.xp_events USING btree (profile_id);
CREATE UNIQUE INDEX xp_events_match_result_once_idx ON public.xp_events USING btree (profile_id, source_type, source_id) WHERE ((source_type = 'MATCH_RESULT_CONFIRMED'::text) AND (source_id IS NOT NULL));
CREATE INDEX xp_events_profile_created_idx ON public.xp_events USING btree (profile_id, created_at DESC);
CREATE UNIQUE INDEX xp_events_profile_source_unique ON public.xp_events USING btree (profile_id, source_type, source_id) WHERE (source_id IS NOT NULL);

-- ============================================================================
-- VISTAS (5)
-- ============================================================================

CREATE OR REPLACE VIEW public.shop_inventory_dashboard AS
 SELECT v.id AS variant_id,
    p.id AS product_id,
    p.title AS product_title,
    v.title AS variant_title,
    v.sku,
    l.id AS location_id,
    l.name AS location_name,
    l.location_type,
    COALESCE(li.quantity, v.stock_quantity) AS stock_quantity,
    COALESCE(li.reserved_quantity, v.reserved_quantity) AS reserved_quantity,
    GREATEST(0, COALESCE(li.quantity, v.stock_quantity) - COALESCE(li.reserved_quantity, v.reserved_quantity)) AS available_quantity,
    COALESCE(li.reorder_level, 0) AS reorder_level
   FROM shop_product_variants v
     JOIN shop_products p ON p.id = v.product_id
     CROSS JOIN shop_locations l
     LEFT JOIN shop_location_inventory li ON li.variant_id = v.id AND li.location_id = l.id
  WHERE p.status = 'ACTIVE'::text AND v.is_active = true;

CREATE OR REPLACE VIEW public.shop_inventory_alerts AS
 SELECT variant_id,
    product_id,
    product_title,
    variant_title,
    sku,
    location_id,
    location_name,
    location_type,
    stock_quantity,
    reserved_quantity,
    available_quantity,
    reorder_level,
        CASE
            WHEN available_quantity = 0 THEN 'OUT_OF_STOCK'::text
            WHEN available_quantity <= reorder_level THEN 'LOW_STOCK'::text
            ELSE 'OK'::text
        END AS alert_level
   FROM shop_inventory_dashboard
  WHERE available_quantity <= reorder_level;

CREATE OR REPLACE VIEW public.shop_low_stock AS
 SELECT variant_id,
    product_id,
    product_title,
    variant_title,
    sku,
    location_id,
    location_name,
    location_type,
    stock_quantity,
    reserved_quantity,
    available_quantity,
    reorder_level
   FROM shop_inventory_dashboard
  WHERE available_quantity <= reorder_level;

CREATE OR REPLACE VIEW public.shop_customer_purchase_summary AS
 SELECT c.id AS customer_id,
    c.profile_id,
    c.full_name,
    c.phone,
    c.email,
    count(o.id) FILTER (WHERE o.status = ANY (ARRAY['paid'::text, 'processing'::text, 'shipped'::text, 'delivered'::text])) AS orders_count,
    COALESCE(sum(o.total_amount) FILTER (WHERE o.status = ANY (ARRAY['paid'::text, 'processing'::text, 'shipped'::text, 'delivered'::text])), 0::numeric) AS lifetime_value,
    max(o.created_at) FILTER (WHERE o.status = ANY (ARRAY['paid'::text, 'processing'::text, 'shipped'::text, 'delivered'::text])) AS last_purchase_at
   FROM shop_customers c
     LEFT JOIN shop_orders o ON o.profile_id = c.profile_id
  GROUP BY c.id, c.profile_id, c.full_name, c.phone, c.email;

CREATE OR REPLACE VIEW public.shop_sales_daily AS
 SELECT date_trunc('day'::text, created_at)::date AS sale_date,
    sale_channel,
    location_id,
    count(*) AS sales_count,
    COALESCE(sum(total_amount), 0::numeric) AS gross_sales,
    COALESCE(sum(discount_amount), 0::numeric) AS discounts,
    COALESCE(sum(tax_amount), 0::numeric) AS taxes
   FROM shop_pos_sales
  WHERE status = 'completed'::text
  GROUP BY (date_trunc('day'::text, created_at)::date), sale_channel, location_id;


-- ============================================================================
-- FUNCIONES (139)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.adjust_shop_inventory(p_location_id uuid, p_variant_id uuid, p_counted_quantity integer, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_user uuid:=auth.uid(); v_previous integer; v_reserved integer; v_delta integer; v_adjustment uuid; begin if v_user is null then raise exception 'AUTH_REQUIRED'; end if; if not public.has_shop_permission(p_location_id,'manage_inventory',v_user) then raise exception 'SHOP_PERMISSION_DENIED'; end if; if p_counted_quantity < 0 then raise exception 'INVALID_COUNT'; end if; if p_reason is null or length(trim(p_reason))<3 or length(trim(p_reason))>500 then raise exception 'INVALID_REASON'; end if; insert into public.shop_inventory_levels(location_id,variant_id,stock_quantity) values(p_location_id,p_variant_id,0) on conflict do nothing; select stock_quantity,reserved_quantity into v_previous,v_reserved from public.shop_inventory_levels where location_id=p_location_id and variant_id=p_variant_id for update; if p_counted_quantity<coalesce(v_reserved,0) then raise exception 'COUNT_BELOW_RESERVED_STOCK'; end if; v_delta:=p_counted_quantity-coalesce(v_previous,0); update public.shop_inventory_levels set stock_quantity=p_counted_quantity,updated_at=now() where location_id=p_location_id and variant_id=p_variant_id; insert into public.shop_inventory_adjustments(location_id,variant_id,previous_quantity,counted_quantity,delta_quantity,reason,created_by) values(p_location_id,p_variant_id,coalesce(v_previous,0),p_counted_quantity,v_delta,trim(p_reason),v_user) returning id into v_adjustment; if v_delta<>0 then insert into public.shop_inventory_movements(location_id,variant_id,movement_type,quantity,source_type,source_id,created_by,notes) values(p_location_id,p_variant_id,case when v_delta>0 then 'ADJUSTMENT_IN' else 'ADJUSTMENT_OUT' end,v_delta,'STOCK_COUNT',v_adjustment,v_user,trim(p_reason)); end if; return jsonb_build_object('ok',true,'adjustment_id',v_adjustment,'previous_quantity',v_previous,'reserved_quantity',v_reserved,'counted_quantity',p_counted_quantity,'delta_quantity',v_delta); end; $function$
;

CREATE OR REPLACE FUNCTION public.advance_marketplace_order_status(p_order_id uuid, p_next_status text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_status text; v_total numeric; v_refunded numeric;
begin
 if auth.role()<>'service_role' then raise exception 'service_role_required'; end if;
 if p_next_status not in ('fulfilled','refunded','partially_refunded') then raise exception 'invalid_state_transition'; end if;
 select status,total_amount into v_status,v_total from public.marketplace_orders where id=p_order_id for update;
 if not found then raise exception 'order_not_found'; end if;
 if v_status='paid' and p_next_status='fulfilled' then
   update public.marketplace_orders set status='fulfilled',updated_at=now() where id=p_order_id;
   return true;
 end if;
 if v_status='fulfilled' and p_next_status in ('refunded','partially_refunded') then
   select coalesce(sum(case when status='succeeded' then amount else 0 end),0) into v_refunded from public.marketplace_payment_refunds where order_id=p_order_id;
   if p_next_status='refunded' and v_refunded<>v_total then raise exception 'REFUND_TOTAL_MISMATCH'; end if;
   if p_next_status='partially_refunded' and (v_refunded<=0 or v_refunded>=v_total) then raise exception 'PARTIAL_REFUND_AMOUNT_INVALID'; end if;
   update public.marketplace_orders set status=p_next_status,updated_at=now() where id=p_order_id;
   return true;
 end if;
 raise exception 'invalid_state_transition';
end; $function$
;

CREATE OR REPLACE FUNCTION public.ai_evolution_acquire_lock(p_lock_key text DEFAULT 'platform'::text, p_run_id uuid DEFAULT NULL::uuid, p_ttl_minutes integer DEFAULT 45)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  insert into public.ai_evolution_locks(lock_key, locked_at, run_id, updated_at)
  values (p_lock_key, now(), p_run_id, now())
  on conflict (lock_key) do update
    set locked_at = now(),
        run_id = excluded.run_id,
        updated_at = now()
  where public.ai_evolution_locks.locked_at < now() - make_interval(mins => greatest(1, p_ttl_minutes));

  return exists (
    select 1 from public.ai_evolution_locks
    where lock_key = p_lock_key
      and run_id is not distinct from p_run_id
      and locked_at > now() - make_interval(mins => greatest(1, p_ttl_minutes))
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.ai_evolution_release_lock(p_lock_key text DEFAULT 'platform'::text, p_run_id uuid DEFAULT NULL::uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare deleted_count integer;
begin
  delete from public.ai_evolution_locks
  where lock_key = p_lock_key
    and run_id is not distinct from p_run_id;
  get diagnostics deleted_count = row_count;
  return deleted_count > 0;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.apply_confirmed_match_progression()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_match public.matches; v_sport uuid; r record; v_rating_before numeric; v_opp_avg numeric; v_expected numeric; v_score numeric; v_delta numeric;
begin
  if new.status<>'confirmed' or (tg_op='UPDATE' and coalesce(old.status,'')='confirmed') then return new; end if;
  select * into v_match from public.matches where id=new.match_id for update;
  if not found or v_match.challenge_id is null then return new; end if;
  v_sport:=v_match.sport_id;
  if (select count(*) from public.challenge_participants where challenge_id=v_match.challenge_id and status='accepted')<2 or new.winner_profile_id is null then return new; end if;
  if not exists(select 1 from public.challenge_participants where challenge_id=v_match.challenge_id and profile_id=new.winner_profile_id and status='accepted') then raise exception 'WINNER_NOT_PARTICIPANT'; end if;
  create temp table if not exists pg_temp.dynasty_match_rating_snapshot(profile_id uuid primary key,rating numeric) on commit drop;
  truncate pg_temp.dynasty_match_rating_snapshot;
  insert into pg_temp.dynasty_match_rating_snapshot(profile_id,rating)
  select cp.profile_id,coalesce(sr.rating,1000) from public.challenge_participants cp left join public.sport_rankings sr on sr.profile_id=cp.profile_id and sr.sport_id=v_sport where cp.challenge_id=v_match.challenge_id and cp.status='accepted';
  for r in select profile_id from pg_temp.dynasty_match_rating_snapshot order by profile_id loop
    select rating into v_rating_before from pg_temp.dynasty_match_rating_snapshot where profile_id=r.profile_id;
    select avg(s.rating) into v_opp_avg from pg_temp.dynasty_match_rating_snapshot s where s.profile_id<>r.profile_id;
    v_expected:=1/(1+power(10,(coalesce(v_opp_avg,1000)-v_rating_before)/400));
    v_score:=case when r.profile_id=new.winner_profile_id then 1 else 0 end;
    v_delta:=round((32*(v_score-v_expected))::numeric,2);
    insert into public.sport_rankings(profile_id,sport_id,rating,wins,losses,matches_played,rank,updated_at)
    values(r.profile_id,v_sport,v_rating_before+v_delta,case when v_score=1 then 1 else 0 end,case when v_score=0 then 1 else 0 end,1,null,now())
    on conflict(profile_id,sport_id) do update set rating=round(public.sport_rankings.rating+v_delta,2),wins=public.sport_rankings.wins+case when v_score=1 then 1 else 0 end,losses=public.sport_rankings.losses+case when v_score=0 then 1 else 0 end,matches_played=public.sport_rankings.matches_played+1,updated_at=now();
    insert into public.rating_history(profile_id,sport_id,source_match_id,rating_before,rating_after,delta) values(r.profile_id,v_sport,v_match.id,v_rating_before,v_rating_before+v_delta,v_delta) on conflict do nothing;
    perform public.award_xp_system(r.profile_id,case when v_score=1 then 100 else 50 end,'MATCH_RESULT_CONFIRMED',v_match.id,jsonb_build_object('winner',new.winner_profile_id,'sport_id',v_sport));
    perform public.process_dynasty_progression(r.profile_id,v_sport,'MATCH_RESULT_CONFIRMED',v_match.id,(v_score=1));
  end loop;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.apply_confirmed_tournament_progression()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_fixture_id uuid; v_fixture public.tournament_fixtures; v_t public.tournaments; v_sport uuid; r record; v_rating_before numeric; v_opp_avg numeric; v_expected numeric; v_score numeric; v_delta numeric; v_xp integer; begin if new.status <> 'confirmed' or (tg_op='UPDATE' and coalesce(old.status,'')='confirmed') then return new; end if; v_fixture_id:=nullif(new.result_data->>'tournament_fixture_id','')::uuid; if v_fixture_id is null then return new; end if; select * into v_fixture from public.tournament_fixtures where id=v_fixture_id for update; if not found then return new; end if; select * into v_t from public.tournaments where id=v_fixture.tournament_id; if not found then return new; end if; v_sport:=v_t.sport_id; if not exists(select 1 from public.tournament_entry_members tem where tem.entry_id in(v_fixture.side_a_entry_id,v_fixture.side_b_entry_id) and tem.profile_id=new.winner_profile_id and tem.status='confirmed') then return new; end if; create temp table if not exists pg_temp.dynasty_tournament_rating_snapshot(profile_id uuid primary key,rating numeric) on commit drop; truncate pg_temp.dynasty_tournament_rating_snapshot; insert into pg_temp.dynasty_tournament_rating_snapshot(profile_id,rating) select distinct tem.profile_id,coalesce(sr.rating,1000) from public.tournament_entry_members tem left join public.sport_rankings sr on sr.profile_id=tem.profile_id and sr.sport_id=v_sport where tem.entry_id in(v_fixture.side_a_entry_id,v_fixture.side_b_entry_id) and tem.status='confirmed'; for r in select profile_id,entry_id from public.tournament_entry_members where entry_id in(v_fixture.side_a_entry_id,v_fixture.side_b_entry_id) and status='confirmed' order by profile_id loop select rating into v_rating_before from pg_temp.dynasty_tournament_rating_snapshot where profile_id=r.profile_id; select avg(s.rating) into v_opp_avg from pg_temp.dynasty_tournament_rating_snapshot s join public.tournament_entry_members tem2 on tem2.profile_id=s.profile_id where tem2.entry_id=case when r.entry_id=v_fixture.side_a_entry_id then v_fixture.side_b_entry_id else v_fixture.side_a_entry_id end and tem2.status='confirmed'; v_opp_avg:=coalesce(v_opp_avg,1000); v_expected:=1/(1+power(10,(v_opp_avg-v_rating_before)/400)); v_score:=case when r.entry_id=v_fixture.winner_entry_id then 1 else 0 end; v_delta:=round((32*(v_score-v_expected))::numeric,2); if not exists(select 1 from public.rating_history rh where rh.profile_id=r.profile_id and rh.source_match_id=new.match_id) then insert into public.sport_rankings(profile_id,sport_id,rating,wins,losses,matches_played,rank,updated_at) values(r.profile_id,v_sport,v_rating_before+v_delta,case when v_score=1 then 1 else 0 end,case when v_score=0 then 1 else 0 end,1,null,now()) on conflict(profile_id,sport_id) do update set rating=round(public.sport_rankings.rating+v_delta,2),wins=public.sport_rankings.wins+case when v_score=1 then 1 else 0 end,losses=public.sport_rankings.losses+case when v_score=0 then 1 else 0 end,matches_played=public.sport_rankings.matches_played+1,updated_at=now(); insert into public.rating_history(profile_id,sport_id,source_match_id,rating_before,rating_after,delta) values(r.profile_id,v_sport,new.match_id,v_rating_before,v_rating_before+v_delta,v_delta); v_xp:=case when v_score=1 then 100 else 50 end; perform public.award_xp_system(r.profile_id,v_xp,'TOURNAMENT_RESULT_CONFIRMED',new.match_id,jsonb_build_object('tournament_fixture_id',v_fixture_id,'winner_entry_id',v_fixture.winner_entry_id,'sport_id',v_sport)); end if; end loop; return new; end; $function$
;

CREATE OR REPLACE FUNCTION public.apply_payment_refund(p_payment_id uuid, p_refund_amount numeric, p_status text)
 RETURNS payment_records
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_payment public.payment_records;
  v_new_refunded numeric;
begin
  if auth.role() <> 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED';
  end if;
  if p_refund_amount is null or p_refund_amount <= 0 then
    raise exception 'REFUND_AMOUNT_INVALID';
  end if;
  if p_status not in ('refunded','partially_refunded') then
    raise exception 'INVALID_REFUND_STATUS';
  end if;
  select * into v_payment
  from public.payment_records
  where id=p_payment_id
  for update;
  if not found then
    raise exception 'PAYMENT_NOT_FOUND';
  end if;
  if v_payment.status not in ('paid','partially_refunded') then
    raise exception 'PAYMENT_NOT_REFUNDABLE';
  end if;
  if p_refund_amount > v_payment.amount-coalesce(v_payment.refunded_amount,0) then
    raise exception 'REFUND_EXCEEDS_REMAINING';
  end if;
  v_new_refunded := coalesce(v_payment.refunded_amount,0) + p_refund_amount;
  if p_status='refunded' and v_new_refunded <> v_payment.amount then
    raise exception 'REFUND_STATUS_AMOUNT_MISMATCH';
  end if;
  if p_status='partially_refunded' and v_new_refunded >= v_payment.amount then
    raise exception 'REFUND_STATUS_AMOUNT_MISMATCH';
  end if;
  update public.payment_records
  set refunded_amount=v_new_refunded,
      status=p_status,
      updated_at=now()
  where id=v_payment.id
  returning * into v_payment;
  update public.bookings
  set payment_status=v_payment.status,
      updated_at=now()
  where id=v_payment.booking_id;
  return v_payment;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.apply_payment_result(p_provider text, p_provider_payment_id text, p_provider_event_id text, p_booking_id uuid, p_amount numeric, p_currency_code text, p_status text, p_payer_profile_id uuid DEFAULT NULL::uuid, p_raw_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS payment_records
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_payment public.payment_records;
  v_booking public.bookings;
  v_existing public.payment_records;
begin
  if auth.role() <> 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED';
  end if;
  if p_provider is null or length(trim(p_provider)) = 0 then
    raise exception 'INVALID_PAYMENT_PROVIDER';
  end if;
  if p_provider_payment_id is null or length(trim(p_provider_payment_id)) = 0 then
    raise exception 'INVALID_PROVIDER_PAYMENT_ID';
  end if;
  if p_provider_event_id is null or length(trim(p_provider_event_id)) = 0 then
    raise exception 'INVALID_PROVIDER_EVENT_ID';
  end if;
  if p_status not in ('pending','authorized','paid','failed','refunded','partially_refunded','cancelled') then
    raise exception 'INVALID_PAYMENT_STATUS';
  end if;
  if p_amount is null or p_amount < 0 then
    raise exception 'INVALID_PAYMENT_AMOUNT';
  end if;

  select * into v_booking
  from public.bookings
  where id = p_booking_id
  for update;
  if not found then
    raise exception 'BOOKING_NOT_FOUND';
  end if;
  if p_amount <> v_booking.amount or p_currency_code <> v_booking.currency_code then
    raise exception 'PAYMENT_AMOUNT_OR_CURRENCY_MISMATCH';
  end if;

  select * into v_existing
  from public.payment_records
  where provider = p_provider
    and provider_payment_id = p_provider_payment_id
  for update;

  if found then
    if v_existing.booking_id <> p_booking_id
       or v_existing.amount <> p_amount
       or v_existing.currency_code <> p_currency_code then
      raise exception 'PAYMENT_IDENTITY_MISMATCH';
    end if;
    if v_existing.provider_event_id is not null
       and v_existing.provider_event_id <> p_provider_event_id then
      raise exception 'PAYMENT_EVENT_ID_MISMATCH';
    end if;

    -- Refund states are terminal except for partial -> full refund.
    if v_existing.status = 'refunded'
       and p_status <> 'refunded' then
      raise exception 'PAYMENT_TERMINAL_STATE';
    end if;
    if v_existing.status = 'partially_refunded'
       and p_status not in ('partially_refunded','refunded') then
      raise exception 'PAYMENT_TERMINAL_STATE';
    end if;
    -- A cancelled payment cannot be resurrected under the same provider payment id.
    if v_existing.status = 'cancelled'
       and p_status <> 'cancelled' then
      raise exception 'PAYMENT_TERMINAL_STATE';
    end if;
    -- Paid cannot regress to a pre-payment/failure state.
    if v_existing.status = 'paid'
       and p_status in ('pending','authorized','failed','cancelled') then
      raise exception 'PAYMENT_STATE_REGRESSION';
    end if;

    -- apply_payment_result must never manufacture refund accounting.
    if p_status = 'refunded'
       and coalesce(v_existing.refunded_amount,0) <> v_existing.amount then
      raise exception 'REFUND_ACCOUNTING_MISMATCH';
    end if;
    if p_status = 'partially_refunded'
       and (coalesce(v_existing.refunded_amount,0) <= 0
            or coalesce(v_existing.refunded_amount,0) >= v_existing.amount) then
      raise exception 'REFUND_ACCOUNTING_MISMATCH';
    end if;

    update public.payment_records
    set provider_event_id = p_provider_event_id,
        status = p_status,
        payer_profile_id = coalesce(p_payer_profile_id, payer_profile_id),
        raw_payload = coalesce(p_raw_payload, '{}'::jsonb),
        paid_at = case when p_status = 'paid' then coalesce(paid_at, now()) else paid_at end,
        updated_at = now()
    where id = v_existing.id
    returning * into v_payment;
  else
    if exists (
      select 1 from public.payment_records
      where provider = p_provider
        and provider_event_id = p_provider_event_id
    ) then
      raise exception 'PAYMENT_EVENT_ALREADY_USED';
    end if;
    -- A new payment record cannot claim a refund state without refund accounting.
    if p_status in ('refunded','partially_refunded') then
      raise exception 'REFUND_REQUIRES_REFUND_RECORD';
    end if;

    insert into public.payment_records(
      booking_id, provider, provider_payment_id, provider_event_id,
      amount, currency_code, status, payer_profile_id, raw_payload, paid_at
    ) values (
      p_booking_id, p_provider, p_provider_payment_id, p_provider_event_id,
      p_amount, p_currency_code, p_status, p_payer_profile_id,
      coalesce(p_raw_payload,'{}'::jsonb),
      case when p_status = 'paid' then now() else null end
    )
    returning * into v_payment;
  end if;

  if p_status = 'paid' then
    update public.bookings
    set payment_status = 'paid', status = 'confirmed', updated_at = now()
    where id = p_booking_id
      and status = 'pending';
  elsif p_status in ('failed','cancelled') then
    update public.bookings
    set payment_status = p_status, updated_at = now()
    where id = p_booking_id
      and payment_status not in ('paid','refunded','partially_refunded');
  elsif p_status in ('refunded','partially_refunded') then
    update public.bookings
    set payment_status = p_status, updated_at = now()
    where id = p_booking_id;
  end if;

  return v_payment;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.assert_tournament_schedule_publishable(p_tournament_id uuid, p_slot_minutes integer DEFAULT 60, p_required_rest_slots integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_result jsonb;
begin
  v_result := public.validate_tournament_schedule(
    p_tournament_id,
    p_slot_minutes,
    p_required_rest_slots
  );

  if coalesce((v_result->>'valid')::boolean, false) = false then
    raise exception using
      errcode = 'P0001',
      message = 'La programación contiene conflictos críticos y no puede publicarse',
      detail = v_result::text;
  end if;

  return jsonb_build_object(
    'publishable', true,
    'validation', v_result
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.assign_organization_role(p_membership_id uuid, p_role_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_membership public.organization_memberships;
  v_role public.organization_roles;
  v_org_owner uuid;
  v_actor uuid := auth.uid();
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_membership from public.organization_memberships where id=p_membership_id for update;
  if not found then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;
  select * into v_role from public.organization_roles where id=p_role_id;
  if not found or v_role.organization_id is distinct from v_membership.organization_id then raise exception 'ROLE_ORGANIZATION_MISMATCH'; end if;
  select owner_id into v_org_owner from public.organizations where id=v_membership.organization_id for share;
  if v_org_owner is null then raise exception 'ORGANIZATION_NOT_FOUND'; end if;

  -- Granting roles is itself a role-management operation; manage_members alone must not be enough to escalate privileges.
  perform public.require_organization_permission(v_membership.organization_id,'manage_roles');

  if lower(coalesce(v_role.code,''))='owner' then
    if v_actor is distinct from v_org_owner then raise exception 'OWNER_ROLE_REQUIRES_ORGANIZATION_OWNER'; end if;
    if not v_role.is_system then raise exception 'RESERVED_OWNER_ROLE_MUST_BE_SYSTEM'; end if;
  end if;

  insert into public.organization_member_roles(membership_id,role_id)
  values(p_membership_id,p_role_id)
  on conflict do nothing;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.auto_confirm_due_match_results(p_after_hours integer DEFAULT 12)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_count integer := 0;
record_result record;
begin
  if p_after_hours < 1 or p_after_hours > 168 then
    raise exception 'after_hours inválido';
  end if;

  for record_result in
    select mr.id,mr.match_id,mr.submitted_by,mr.created_at,mr.winner_profile_id
    from public.match_results mr
    join public.matches m on m.id=mr.match_id
    where mr.status='pending'
      and mr.created_at <= now() - make_interval(hours => p_after_hours)
      and m.status in ('scheduled','in_progress')
    for update of mr,m
  loop
    update public.match_results
      set status='confirmed',updated_at=now(),metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('auto_confirmed',true,'auto_confirmed_at',now(),'auto_confirm_after_hours',p_after_hours)
      where id=record_result.id and status='pending';

    if found then
      update public.matches
        set status='completed',completed_at=coalesce(completed_at,now()),updated_at=now()
        where id=record_result.match_id;

      update public.challenges c
        set status='completed',updated_at=now()
        where c.id=(select challenge_id from public.matches where id=record_result.match_id)
          and c.status<>'completed';

      insert into public.notifications(profile_id,category,type,title,body,action_type,action_payload,source_type,source_id,priority)
      select cp.profile_id,'match','match_result_auto_confirmed','Resultado auto-confirmado','El resultado fue confirmado automáticamente después del período de revisión.','open_match',jsonb_build_object('match_id',record_result.match_id),'match',record_result.match_id,'normal'
      from public.challenge_participants cp
      where cp.challenge_id=(select challenge_id from public.matches where id=record_result.match_id)
        and cp.status='accepted'
      on conflict do nothing;

      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.award_xp(p_profile_id uuid, p_amount integer, p_source_type text, p_source_id uuid DEFAULT NULL::uuid, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS player_progression
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_row public.player_progression;
begin
 if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
 if p_amount < 0 or p_amount > 10000 then raise exception 'XP inválido'; end if;
 if auth.uid()<>p_profile_id then raise exception 'No autorizado'; end if;
 insert into public.xp_events(profile_id,source_type,source_id,amount,metadata) values(p_profile_id,p_source_type,p_source_id,p_amount,coalesce(p_metadata,'{}'::jsonb));
 insert into public.player_progression(profile_id,total_xp,level) values(p_profile_id,p_amount,1)
 on conflict(profile_id) do update set total_xp=public.player_progression.total_xp+excluded.total_xp,level=floor(sqrt((public.player_progression.total_xp+excluded.total_xp)::numeric/100))+1,updated_at=now();
 select * into v_row from public.player_progression where profile_id=p_profile_id; return v_row;
end;$function$
;

CREATE OR REPLACE FUNCTION public.award_xp_system(p_profile_id uuid, p_amount integer, p_source_type text, p_source_id uuid DEFAULT NULL::uuid, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS player_progression
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_row public.player_progression; v_inserted integer;
begin
  if p_profile_id is null then raise exception 'profile_id requerido'; end if;
  if p_amount <= 0 or p_amount > 10000 then raise exception 'XP inválido'; end if;
  insert into public.xp_events(profile_id,source_type,source_id,amount,metadata)
  values(p_profile_id,p_source_type,p_source_id,p_amount,coalesce(p_metadata,'{}'::jsonb))
  on conflict do nothing;
  get diagnostics v_inserted=row_count;
  if v_inserted=0 then
    select * into v_row from public.player_progression where profile_id=p_profile_id;
    if not found then
      insert into public.player_progression(profile_id,total_xp,level) values(p_profile_id,0,1) returning * into v_row;
    end if;
    return v_row;
  end if;
  insert into public.player_progression(profile_id,total_xp,level)
  values(p_profile_id,p_amount,floor(sqrt(p_amount::numeric/100))+1)
  on conflict(profile_id) do update set
    total_xp=public.player_progression.total_xp+p_amount,
    level=floor(sqrt((public.player_progression.total_xp+p_amount)::numeric/100))+1,
    updated_at=now();
  select * into v_row from public.player_progression where profile_id=p_profile_id;
  return v_row;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.begin_platform_test_run(p_suite text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid;
begin
  if auth.role() <> 'service_role' then raise exception 'service_role_required'; end if;
  if p_suite is null or btrim(p_suite) = '' then raise exception 'suite_required'; end if;
  insert into public.platform_test_runs(suite) values (p_suite) returning id into v_id;
  return v_id;
end; $function$
;

CREATE OR REPLACE FUNCTION public.cancel_booking(p_booking_id uuid)
 RETURNS bookings
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_booking public.bookings; v_deadline integer; begin select * into v_booking from public.bookings where id=p_booking_id for update; if not found then raise exception 'Booking not found'; end if; if v_booking.booked_by<>auth.uid() then raise exception 'Not authorized to cancel this booking'; end if; if v_booking.status not in ('pending','confirmed') then raise exception 'Booking cannot be cancelled in its current state'; end if; select cancellation_deadline_minutes into v_deadline from public.booking_policies where bookable_id=v_booking.bookable_id; if v_deadline is not null and now() > v_booking.starts_at - make_interval(mins=>v_deadline) then raise exception 'Cancellation deadline has passed'; end if; update public.bookings set status='cancelled',updated_at=now() where id=p_booking_id returning * into v_booking; return v_booking; end; $function$
;

CREATE OR REPLACE FUNCTION public.cancel_challenge(p_challenge_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
 if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
 if not exists (select 1 from public.challenges where id = p_challenge_id and creator_id = auth.uid()) then raise exception 'No autorizado'; end if;
 if exists (select 1 from public.match_results mr join public.matches m on m.id = mr.match_id
            where m.challenge_id = p_challenge_id and mr.status in ('pending', 'confirmed', 'disputed')) then
   raise exception 'El reto ya tiene un resultado y no puede cancelarse';
 end if;
 update public.challenges set status = 'cancelled', updated_at = now() where id = p_challenge_id and status in ('open', 'accepted', 'scheduled');
 if not found then raise exception 'El reto no puede cancelarse en su estado actual'; end if;
 update public.challenge_invitations set status = 'cancelled', responded_at = now() where challenge_id = p_challenge_id and status = 'pending';
 return true;
end; $function$
;

CREATE OR REPLACE FUNCTION public.cancel_my_marketplace_order(p_order_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_buyer uuid:=auth.uid(); v_status text; begin
 if v_buyer is null then raise exception 'not_authenticated'; end if;
 select status into v_status from public.marketplace_orders where id=p_order_id and buyer_id=v_buyer for update;
 if not found then raise exception 'order_not_found'; end if;
 if v_status <> 'reserved' then raise exception 'order_not_cancellable'; end if;
 update public.marketplace_listing_inventory li set reserved_quantity=greatest(0,li.reserved_quantity-x.qty), updated_at=now()
 from (select listing_id,sum(quantity)::integer qty from public.marketplace_order_items where order_id=p_order_id group by listing_id) x
 where li.listing_id=x.listing_id;
 update public.marketplace_orders set status='cancelled',updated_at=now(),metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('cancelled_by','buyer','cancelled_at',now()) where id=p_order_id;
 return true;
end; $function$
;

CREATE OR REPLACE FUNCTION public.check_booking_conflict()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare existing_quantity integer; capacity_limit integer; conflict_exists boolean;
begin
 if new.status not in ('pending','confirmed') then return new; end if;
 select capacity into capacity_limit from public.bookable_entities where id=new.bookable_id;
 select coalesce(sum(quantity),0), exists(select 1 from public.bookings b where b.bookable_id=new.bookable_id and b.id<>new.id and b.status in ('pending','confirmed') and tstzrange(b.starts_at,b.ends_at,'[)') && tstzrange(new.starts_at,new.ends_at,'[)')) into existing_quantity, conflict_exists from public.bookings b where b.bookable_id=new.bookable_id and b.id<>new.id and b.status in ('pending','confirmed') and tstzrange(b.starts_at,b.ends_at,'[)') && tstzrange(new.starts_at,new.ends_at,'[)');
 if existing_quantity + new.quantity > capacity_limit then raise exception 'BOOKING_CAPACITY_EXCEEDED'; end if;
 return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.check_rate_limit(p_bucket text, p_max_hits integer, p_window_seconds integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_count int;
begin
  if p_bucket is null or length(p_bucket) = 0 then raise exception 'bucket requerido'; end if;
  if p_max_hits < 1 or p_window_seconds < 1 then raise exception 'parametros invalidos'; end if;

  -- limpieza de paso: borra golpes de ESTE bucket mas viejos que la ventana (barato, por indice).
  delete from public.rate_limit_hits
  where bucket = p_bucket and created_at < now() - make_interval(secs => p_window_seconds);

  select count(*) into v_count
  from public.rate_limit_hits
  where bucket = p_bucket and created_at >= now() - make_interval(secs => p_window_seconds);

  if v_count >= p_max_hits then
    return false;
  end if;

  insert into public.rate_limit_hits(bucket) values (p_bucket);
  return true;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.checkin_tournament_entry(p_entry_id uuid, p_method text DEFAULT 'manual'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_entry public.tournament_entries; v_tournament public.tournaments; v_allowed boolean:=false; v_checked uuid; begin if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if; select * into v_entry from public.tournament_entries where id=p_entry_id for update; if not found then raise exception 'Entry not found'; end if; select * into v_tournament from public.tournaments where id=v_entry.tournament_id; if not found then raise exception 'Tournament not found'; end if; if v_entry.captain_profile_id=auth.uid() or exists(select 1 from public.tournament_entry_members tem where tem.entry_id=v_entry.id and tem.profile_id=auth.uid() and tem.status='confirmed') then v_allowed:=true; end if; if v_tournament.organizer_profile_id=auth.uid() or (v_tournament.organization_id is not null and public.has_organization_permission(v_tournament.organization_id,'manage_tournaments',auth.uid())) then v_allowed:=true; end if; if not v_allowed then raise exception 'No autorizado para check-in'; end if; if v_entry.status not in ('pending','confirmed','waitlisted') then raise exception 'Entry cannot check in'; end if; if v_entry.status='waitlisted' then raise exception 'Waitlisted entry cannot check in'; end if; if v_entry.checked_in_at is null then update public.tournament_entries set checked_in_at=now(),updated_at=now() where id=p_entry_id returning id into v_checked; if not exists(select 1 from public.tournament_checkins where entry_id=p_entry_id) then insert into public.tournament_checkins(entry_id,profile_id,method,checked_in_by) values(p_entry_id,coalesce((select captain_profile_id from public.tournament_entries where id=p_entry_id),auth.uid()),coalesce(p_method,'manual'),auth.uid()); end if; else v_checked:=v_entry.id; end if; return jsonb_build_object('ok',true,'entry_id',v_checked,'checked_in_at',coalesce(v_entry.checked_in_at,now()),'already_checked_in',v_entry.checked_in_at is not null); end; $function$
;

CREATE OR REPLACE FUNCTION public.checkout_shop_cart(p_shipping_data jsonb DEFAULT '{}'::jsonb)
 RETURNS shop_orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_user uuid:=auth.uid(); v_cart public.shop_carts; v_order public.shop_orders; v_item record; v_subtotal numeric:=0; v_online_location uuid;
begin
  if v_user is null then raise exception 'AUTH_REQUIRED'; end if;
  select id into v_online_location from public.shop_locations where code='ONLINE' and status='active' limit 1;
  if v_online_location is null then raise exception 'ONLINE_LOCATION_NOT_CONFIGURED'; end if;
  select * into v_cart from public.shop_carts where profile_id=v_user and status='ACTIVE' order by updated_at desc limit 1 for update;
  if not found then raise exception 'NO_ACTIVE_CART'; end if;
  if not exists(select 1 from public.shop_cart_items where cart_id=v_cart.id) then raise exception 'CART_EMPTY'; end if;
  update public.shop_carts set status='CHECKOUT',updated_at=now() where id=v_cart.id;
  for v_item in
    select ci.*,p.title product_title,p.status product_status,coalesce(v.title,'Default') variant_title,coalesce(v.price,p.base_price) unit_price,coalesce(v.is_active,true) variant_active
    from public.shop_cart_items ci join public.shop_products p on p.id=ci.product_id left join public.shop_product_variants v on v.id=ci.variant_id where ci.cart_id=v_cart.id order by ci.id
  loop
    if v_item.product_status<>'active' then raise exception 'PRODUCT_NOT_AVAILABLE'; end if;
    if not v_item.variant_active then raise exception 'VARIANT_NOT_AVAILABLE'; end if;
    if v_item.variant_id is not null then
      insert into public.shop_inventory_levels(location_id,variant_id,stock_quantity) values(v_online_location,v_item.variant_id,0) on conflict do nothing;
      perform 1 from public.shop_inventory_levels il where il.location_id=v_online_location and il.variant_id=v_item.variant_id and il.stock_quantity-il.reserved_quantity>=v_item.quantity for update;
      if not found then raise exception 'ONLINE_STOCK_INSUFFICIENT'; end if;
    end if;
    v_subtotal:=v_subtotal+(v_item.unit_price*v_item.quantity);
  end loop;
  insert into public.shop_orders(profile_id,status,currency_code,subtotal,discount_amount,shipping_amount,total_amount,shipping_data,fulfillment_status,payment_status)
  values(v_user,'payment_pending',v_cart.currency_code,v_subtotal,0,0,v_subtotal,coalesce(p_shipping_data,'{}'::jsonb),'unfulfilled','pending') returning * into v_order;
  for v_item in select ci.*,p.title product_title,coalesce(v.title,'Default') variant_title,coalesce(v.price,p.base_price) unit_price from public.shop_cart_items ci join public.shop_products p on p.id=ci.product_id left join public.shop_product_variants v on v.id=ci.variant_id where ci.cart_id=v_cart.id order by ci.id loop
    insert into public.shop_order_items(order_id,product_id,variant_id,product_title,variant_title,quantity,unit_price,line_total) values(v_order.id,v_item.product_id,v_item.variant_id,v_item.product_title,v_item.variant_title,v_item.quantity,v_item.unit_price,v_item.unit_price*v_item.quantity);
    if v_item.variant_id is not null then
      update public.shop_inventory_levels set reserved_quantity=reserved_quantity+v_item.quantity,updated_at=now() where location_id=v_online_location and variant_id=v_item.variant_id and stock_quantity-reserved_quantity>=v_item.quantity;
      if not found then raise exception 'ONLINE_STOCK_CHANGED'; end if;
      insert into public.shop_inventory_reservations(order_id,variant_id,location_id,quantity,expires_at) values(v_order.id,v_item.variant_id,v_online_location,v_item.quantity,now()+interval '15 minutes');
    end if;
  end loop;
  update public.shop_carts set status='CONVERTED',updated_at=now() where id=v_cart.id;
  delete from public.shop_cart_items where cart_id=v_cart.id;
  return v_order;
exception when others then
  if v_cart.id is not null then update public.shop_carts set status='ACTIVE',updated_at=now() where id=v_cart.id; end if;
  raise;
end; $function$
;

CREATE OR REPLACE FUNCTION public.close_shop_pos_register(p_register_id uuid, p_closing_total numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_user uuid:=auth.uid(); v_reg public.shop_pos_registers; v_cash_sales numeric:=0; v_cash_refunds numeric:=0; v_expected numeric:=0; v_variance numeric:=0; v_now timestamptz:=now();
begin
 if v_user is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_closing_total<0 then raise exception 'INVALID_CLOSING_TOTAL'; end if;
 select * into v_reg from public.shop_pos_registers where id=p_register_id for update;
 if not found then raise exception 'REGISTER_NOT_FOUND'; end if;
 if not public.has_shop_permission(v_reg.location_id,'manage_register',v_user) then raise exception 'SHOP_PERMISSION_DENIED'; end if;
 if v_reg.status<>'open' then raise exception 'REGISTER_NOT_OPEN'; end if;
 select coalesce(sum(pp.amount),0) into v_cash_sales from public.shop_pos_payments pp join public.shop_pos_sales s on s.id=pp.sale_id where s.register_id=p_register_id and s.created_at>=coalesce(v_reg.opened_at,s.created_at) and s.status='completed' and lower(trim(pp.payment_method)) in ('cash','efectivo');
 select coalesce(sum(r.refund_amount),0) into v_cash_refunds from public.shop_returns r join public.shop_pos_sales s on s.id=r.sale_id where s.register_id=p_register_id and r.created_at>=coalesce(v_reg.opened_at,r.created_at) and r.status='completed' and lower(trim(r.refund_method)) in ('cash','efectivo');
 v_expected:=round(coalesce(v_reg.opening_float,0)+v_cash_sales-v_cash_refunds,2); v_variance:=round(p_closing_total-v_expected,2);
 update public.shop_pos_registers set status='closed',closing_total=round(p_closing_total,2),closed_at=v_now,closed_by=v_user,metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('reconciliation',jsonb_build_object('opening_float',coalesce(v_reg.opening_float,0),'cash_sales',v_cash_sales,'cash_refunds',v_cash_refunds,'expected_cash',v_expected,'counted_cash',round(p_closing_total,2),'variance',v_variance,'closed_at',v_now,'closed_by',v_user)),updated_at=v_now where id=p_register_id;
 return jsonb_build_object('ok',true,'register_id',p_register_id,'expected_cash',v_expected,'counted_cash',round(p_closing_total,2),'variance',v_variance,'status','closed');
end; $function$
;

CREATE OR REPLACE FUNCTION public.complete_provider_booking(p_booking_id uuid)
 RETURNS bookings
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_booking public.bookings; declare v_provider uuid; begin select * into v_booking from public.bookings where id=p_booking_id for update; if not found then raise exception 'Booking not found'; end if; select entity_id into v_provider from public.bookable_entities where id=v_booking.bookable_id and entity_type='service'; if v_provider is null then raise exception 'Booking is not a provider service'; end if; if not exists (select 1 from public.provider_services ps where ps.id=v_provider and ps.provider_id=auth.uid()) and not exists (select 1 from public.bookable_entities be join public.organizations o on o.owner_id=be.owner_id where be.id=v_booking.bookable_id and o.owner_id=auth.uid()) then raise exception 'Not authorized to complete this booking'; end if; if v_booking.status<>'confirmed' then raise exception 'Only confirmed bookings can be completed'; end if; update public.bookings set status='completed',updated_at=now(),metadata=metadata||jsonb_build_object('completed_at',now()) where id=p_booking_id returning * into v_booking; return v_booking; end; $function$
;

CREATE OR REPLACE FUNCTION public.confirm_marketplace_payment(p_order_id uuid, p_provider text, p_provider_payment_id text, p_provider_event_id text, p_amount numeric, p_currency_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare v_order public.marketplace_orders%rowtype; v_existing public.marketplace_order_payments%rowtype; v_item record; v_payment_id uuid; begin if auth.role()<>'service_role' then raise exception 'service_role_required'; end if; if p_provider is null or length(trim(p_provider))=0 or p_provider_payment_id is null or length(trim(p_provider_payment_id))=0 or p_provider_event_id is null or length(trim(p_provider_event_id))=0 then raise exception 'payment_identity_required'; end if; select * into v_existing from public.marketplace_order_payments where provider=p_provider and provider_payment_id=p_provider_payment_id for update; if found then if v_existing.order_id<>p_order_id or v_existing.amount<>p_amount or v_existing.currency_code<>p_currency_code then raise exception 'payment_identity_mismatch'; end if; if v_existing.provider_event_id is distinct from p_provider_event_id then raise exception 'payment_event_identity_mismatch'; end if; return jsonb_build_object('ok',true,'idempotent',true,'order_id',p_order_id,'payment_id',v_existing.id); end if; if exists(select 1 from public.marketplace_order_payments where provider=p_provider and provider_event_id=p_provider_event_id) then raise exception 'payment_event_already_used'; end if; select * into v_order from public.marketplace_orders where id=p_order_id for update; if not found then raise exception 'order_not_found'; end if; if v_order.status not in ('reserved','pending') then raise exception 'order_not_payable'; end if; if p_amount<>v_order.total_amount then raise exception 'amount_mismatch'; end if; if p_currency_code<>v_order.currency_code then raise exception 'currency_mismatch'; end if; insert into public.marketplace_order_payments(order_id,provider,provider_payment_id,provider_event_id,amount,currency_code,status,created_at,updated_at) values(p_order_id,p_provider,p_provider_payment_id,p_provider_event_id,p_amount,p_currency_code,'paid',now(),now()) returning id into v_payment_id; for v_item in select listing_id,quantity from public.marketplace_order_items where order_id=p_order_id loop update public.marketplace_listing_inventory set reserved_quantity=greatest(0,reserved_quantity-v_item.quantity),quantity_available=quantity_available-v_item.quantity,updated_at=now() where listing_id=v_item.listing_id and quantity_available-v_item.quantity>=0; if not found then raise exception 'inventory_changed_during_payment'; end if; end loop; update public.marketplace_orders set status='paid',paid_at=now(),updated_at=now() where id=p_order_id; return jsonb_build_object('ok',true,'idempotent',false,'order_id',p_order_id,'payment_id',v_payment_id); end; $function$
;

CREATE OR REPLACE FUNCTION public.confirm_match(p_match_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_result public.match_results;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Debes iniciar sesión'; END IF;
 SELECT * INTO v_result FROM public.match_results WHERE match_id=p_match_id AND status='pending' ORDER BY created_at DESC LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'No hay resultado pendiente de confirmar'; END IF;
 PERFORM public.review_challenge_result(v_result.id,true);
 RETURN true;
END; $function$
;

CREATE OR REPLACE FUNCTION public.confirm_shop_order_payment(p_order_id uuid, p_provider text, p_provider_payment_id text, p_provider_event_id text, p_amount numeric, p_currency_code text, p_raw_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_order public.shop_orders;
  v_existing public.shop_order_payments;
  r record;
  v_online uuid;
begin
  -- Payment confirmation is a trusted webhook/service operation, never a browser operation.
  if auth.role() <> 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED';
  end if;
  if p_provider is null or length(trim(p_provider)) = 0 then raise exception 'INVALID_PAYMENT_PROVIDER'; end if;
  if p_provider_payment_id is null or length(trim(p_provider_payment_id)) = 0 then raise exception 'INVALID_PROVIDER_PAYMENT_ID'; end if;
  if p_provider_event_id is null or length(trim(p_provider_event_id)) = 0 then raise exception 'INVALID_PROVIDER_EVENT_ID'; end if;
  if p_amount < 0 then raise exception 'INVALID_PAYMENT_AMOUNT'; end if;

  select * into v_order from public.shop_orders where id=p_order_id for update;
  if not found then raise exception 'SHOP_ORDER_NOT_FOUND'; end if;
  if v_order.status in ('cancelled','refunded') then raise exception 'SHOP_ORDER_NOT_PAYABLE'; end if;
  if v_order.currency_code<>p_currency_code then raise exception 'SHOP_PAYMENT_CURRENCY_MISMATCH'; end if;
  if round(p_amount,2)<>round(v_order.total_amount,2) then raise exception 'SHOP_PAYMENT_AMOUNT_MISMATCH'; end if;

  select * into v_existing
  from public.shop_order_payments
  where provider=p_provider and provider_event_id=p_provider_event_id
  for update;
  if found then
    if v_existing.order_id<>p_order_id or round(v_existing.amount,2)<>round(p_amount,2) or v_existing.currency_code<>p_currency_code then
      raise exception 'SHOP_PAYMENT_IDENTITY_MISMATCH';
    end if;
    return jsonb_build_object('ok',true,'idempotent',true,'order_id',p_order_id,'payment_id',v_existing.id,'status',v_existing.status);
  end if;

  if exists(select 1 from public.shop_order_payments where provider=p_provider and provider_payment_id=p_provider_payment_id) then
    raise exception 'SHOP_PAYMENT_ID_ALREADY_USED';
  end if;

  select id into v_online from public.shop_locations where code='ONLINE' and status='active' limit 1;
  if v_online is null then raise exception 'ONLINE_LOCATION_NOT_CONFIGURED'; end if;

  insert into public.shop_order_payments(order_id,provider,provider_payment_id,provider_event_id,amount,currency_code,status,raw_payload,paid_at)
  values(p_order_id,p_provider,p_provider_payment_id,p_provider_event_id,p_amount,p_currency_code,'paid',coalesce(p_raw_payload,'{}'::jsonb),now())
  returning * into v_existing;

  for r in select id,variant_id,location_id,quantity from public.shop_inventory_reservations where order_id=p_order_id and status='active' for update loop
    if r.location_id<>v_online then raise exception 'SHOP_PAYMENT_INVENTORY_LOCATION_MISMATCH'; end if;
    update public.shop_inventory_levels
      set reserved_quantity=greatest(0,reserved_quantity-r.quantity),
          stock_quantity=greatest(0,stock_quantity-r.quantity),
          updated_at=now()
    where location_id=r.location_id and variant_id=r.variant_id and stock_quantity>=r.quantity and reserved_quantity>=r.quantity;
    if not found then raise exception 'SHOP_PAYMENT_STOCK_CONSUMPTION_CONFLICT'; end if;
    update public.shop_inventory_reservations set status='consumed',updated_at=now() where id=r.id;
  end loop;

  update public.shop_orders
  set status='paid',payment_status='paid',fulfillment_status='unfulfilled',updated_at=now()
  where id=p_order_id
  returning * into v_order;

  return jsonb_build_object('ok',true,'idempotent',false,'order_id',p_order_id,'payment_id',v_existing.id,'status',v_existing.status,'order_status',v_order.status);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.confirm_tournament_registration_payment(p_entry_id uuid, p_amount_paid numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_payment public.tournament_registration_payments;
  v_entry public.tournament_entries;
begin
  select * into v_entry from public.tournament_entries where id=p_entry_id for update;
  if not found then raise exception 'Entry not found'; end if;
  select * into v_payment from public.tournament_registration_payments where entry_id=p_entry_id for update;
  if not found then raise exception 'Registration payment record not found'; end if;
  if p_amount_paid < 0 or p_amount_paid > v_payment.amount_due then raise exception 'Invalid payment amount'; end if;
  if p_amount_paid <= v_payment.amount_paid then
    return jsonb_build_object('ok',true,'idempotent',true,'status',v_payment.status,'amount_paid',v_payment.amount_paid);
  end if;
  update public.tournament_registration_payments
    set amount_paid=p_amount_paid,
        status=case when p_amount_paid>=amount_due then 'paid' when p_amount_paid>0 then 'partial' else 'unpaid' end,
        paid_at=case when p_amount_paid>=amount_due then coalesce(paid_at,now()) else paid_at end,
        updated_at=now()
    where id=v_payment.id
    returning * into v_payment;
  if v_payment.status='paid' then
    update public.tournament_entries set status=case when status in ('pending','waitlisted') then 'confirmed' else status end, updated_at=now() where id=p_entry_id;
  end if;
  return jsonb_build_object('ok',true,'idempotent',false,'entry_id',p_entry_id,'status',v_payment.status,'amount_paid',v_payment.amount_paid);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_atomic_booking(p_requested_by uuid, p_starts_at timestamp with time zone, p_ends_at timestamp with time zone, p_items jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_group_id uuid;
  v_item jsonb;
  v_bookable_id uuid;
  v_quantity integer;
  v_price numeric;
  v_currency text;
  v_group_currency text;
  v_total numeric := 0;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_requested_by is distinct from auth.uid() then raise exception 'BOOKING_ACTOR_MISMATCH'; end if;
  if p_starts_at is null or p_ends_at is null or p_ends_at <= p_starts_at then raise exception 'INVALID_BOOKING_RANGE'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)=0 or jsonb_array_length(p_items)>20 then raise exception 'BOOKING_ITEMS_INVALID'; end if;

  insert into public.booking_groups(requested_by,starts_at,ends_at,status,payment_status)
  values(p_requested_by,p_starts_at,p_ends_at,'pending','not_required')
  returning id into v_group_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    if coalesce(v_item->>'bookable_id','') = '' then raise exception 'BOOKABLE_ID_REQUIRED'; end if;
    v_bookable_id := (v_item->>'bookable_id')::uuid;
    v_quantity := coalesce((v_item->>'quantity')::integer,1);
    if v_quantity < 1 or v_quantity > 50 then raise exception 'INVALID_BOOKING_QUANTITY'; end if;

    select price,currency_code into v_price,v_currency
    from public.bookable_entities
    where id=v_bookable_id and status='active'
    for update;
    if not found then raise exception 'BOOKABLE_NOT_AVAILABLE'; end if;
    if v_price is null or v_price < 0 then raise exception 'INVALID_BOOKABLE_PRICE'; end if;
    if v_currency is null or length(trim(v_currency))=0 then raise exception 'BOOKABLE_CURRENCY_REQUIRED'; end if;

    if v_group_currency is null then v_group_currency := v_currency;
    elsif v_group_currency <> v_currency then raise exception 'MIXED_CURRENCY_BOOKING_NOT_ALLOWED'; end if;

    insert into public.bookings(bookable_id,booked_by,starts_at,ends_at,quantity,status,payment_status,amount,currency_code,booking_group_id)
    values(v_bookable_id,p_requested_by,p_starts_at,p_ends_at,v_quantity,'pending',case when v_price*v_quantity > 0 then 'pending' else 'not_required' end,v_price*v_quantity,v_currency,v_group_id);
    v_total := v_total + (v_price*v_quantity);
  end loop;

  update public.booking_groups
  set total_amount=v_total,
      currency_code=coalesce(v_group_currency,'COP'),
      payment_status=case when v_total > 0 then 'pending' else 'not_required' end,
      status='confirmed',
      updated_at=now()
  where id=v_group_id;

  return v_group_id;
exception when others then
  raise;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_challenge(p_challenged_id uuid, p_sport_id uuid, p_match_date timestamp with time zone, p_club_id uuid DEFAULT NULL::uuid, p_match_type text DEFAULT 'DIRECT'::text, p_points integer DEFAULT 100)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_challenge public.challenges; v_id uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Debes iniciar sesión'; END IF;
 IF p_challenged_id IS NULL OR p_challenged_id=auth.uid() THEN RAISE EXCEPTION 'Rival inválido'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=p_challenged_id) THEN RAISE EXCEPTION 'Rival no encontrado'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.sports WHERE id=p_sport_id) THEN RAISE EXCEPTION 'Deporte no encontrado'; END IF;
 IF p_match_date IS NOT NULL AND p_match_date<=now() THEN RAISE EXCEPTION 'La fecha del reto debe ser futura'; END IF;
 IF p_points<1 OR p_points>5000 THEN RAISE EXCEPTION 'Los puntos deben estar entre 1 y 5000'; END IF;
 IF p_match_type NOT IN ('DIRECT','INSTANT') THEN RAISE EXCEPTION 'Tipo de reto inválido'; END IF;
 -- >>> NUEVO: anti-duplicados
 IF EXISTS (
   SELECT 1 FROM public.challenges c
   JOIN public.challenge_invitations i ON i.challenge_id=c.id
   WHERE c.creator_id=auth.uid() AND c.status='open' AND c.sport_id=p_sport_id
     AND i.invitee_id=p_challenged_id
     AND c.scheduled_at IS NOT DISTINCT FROM p_match_date
 ) THEN RAISE EXCEPTION 'Ya enviaste este reto'; END IF;
 -- <<< fin de lo nuevo
 INSERT INTO public.challenges(sport_id,creator_id,title,description,status,challenge_type,scheduled_at,location_name,metadata)
 VALUES(p_sport_id,auth.uid(),'Reto Dynasty',NULL,'open','match',p_match_date,NULL,jsonb_build_object('match_type',p_match_type,'points',p_points,'club_id',p_club_id)) RETURNING id INTO v_id;
 PERFORM public.create_challenge_invitation(v_id,p_challenged_id,NULL,coalesce(p_match_date,now()+interval '7 days'));
 RETURN v_id;
END; $function$
;

CREATE OR REPLACE FUNCTION public.create_challenge_invitation(p_challenge_id uuid, p_invitee_id uuid, p_message text DEFAULT NULL::text, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS challenge_invitations
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_ch public.challenges; v_inv public.challenge_invitations; v_exp timestamptz;
BEGIN
  SELECT * INTO v_ch FROM public.challenges WHERE id=p_challenge_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;
  IF v_ch.creator_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Only challenge creator can invite'; END IF;
  IF v_ch.status <> 'open' THEN RAISE EXCEPTION 'Challenge is not open'; END IF;
  IF p_invitee_id IS NULL OR p_invitee_id=auth.uid() THEN RAISE EXCEPTION 'Invalid invitee'; END IF;
  IF EXISTS (SELECT 1 FROM public.challenge_participants WHERE challenge_id=p_challenge_id AND profile_id=p_invitee_id AND status='accepted') THEN RAISE EXCEPTION 'User is already a participant'; END IF;
  IF EXISTS (SELECT 1 FROM public.challenge_invitations WHERE challenge_id=p_challenge_id AND invitee_id=p_invitee_id AND status='pending') THEN RAISE EXCEPTION 'Pending invitation already exists'; END IF;
  v_exp:=coalesce(p_expires_at,now()+interval '7 days');
  INSERT INTO public.challenge_invitations(challenge_id,inviter_id,invitee_id,status,message,expires_at)
  VALUES(p_challenge_id,auth.uid(),p_invitee_id,'pending',p_message,v_exp) RETURNING * INTO v_inv;
  INSERT INTO public.challenge_participants(challenge_id,profile_id,role,status)
  VALUES(p_challenge_id,p_invitee_id,'opponent','invited')
  ON CONFLICT (challenge_id,profile_id) DO UPDATE SET status='invited';
  INSERT INTO public.notifications(profile_id,category,type,title,body,action_type,action_payload,source_type,source_id,priority)
  VALUES(p_invitee_id,'challenge','challenge_invitation_received','Nuevo reto','Has recibido una invitación a un reto.','open_challenge',jsonb_build_object('challenge_id',p_challenge_id,'invitation_id',v_inv.id),'challenge',p_challenge_id,'high')
  ON CONFLICT DO NOTHING;
  RETURN v_inv;
END; $function$
;

CREATE OR REPLACE FUNCTION public.create_marketplace_item_return(p_order_item_id uuid, p_quantity integer, p_reason text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_buyer uuid := auth.uid(); v_item marketplace_order_items%rowtype; v_order marketplace_orders%rowtype; v_already integer; v_refund numeric; v_id uuid;
begin
  if v_buyer is null then raise exception 'not_authenticated'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'invalid_quantity'; end if;
  select * into v_item from public.marketplace_order_items where id=p_order_item_id for update;
  if not found then raise exception 'order_item_not_found'; end if;
  select * into v_order from public.marketplace_orders where id=v_item.order_id for update;
  if not found or v_order.buyer_id <> v_buyer or v_order.status <> 'paid' then raise exception 'return_not_allowed'; end if;
  select coalesce(sum(quantity),0) into v_already from public.marketplace_item_returns where order_item_id=p_order_item_id and status in ('requested','approved','refunded');
  if v_already + p_quantity > v_item.quantity then raise exception 'return_quantity_exceeds_purchase'; end if;
  v_refund := round(v_item.unit_price * p_quantity, 2);
  insert into public.marketplace_item_returns(order_item_id,quantity,refund_amount,reason,status) values(p_order_item_id,p_quantity,v_refund,p_reason,'requested') returning id into v_id;
  return v_id;
end; $function$
;

CREATE OR REPLACE FUNCTION public.create_marketplace_order(p_items jsonb, p_delivery_amount numeric DEFAULT 0)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_buyer uuid:=auth.uid(); v_order uuid; v_item jsonb; v_listing public.marketplace_listings%rowtype; v_inv public.marketplace_listing_inventory%rowtype; v_sub numeric:=0; v_fee numeric:=0; v_line numeric; v_qty integer; v_unit numeric; v_currency text; v_seen_currency text; v_seller uuid;
begin
 if v_buyer is null then raise exception 'not_authenticated'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'items_required'; end if;
 if coalesce(p_delivery_amount,0)<0 then raise exception 'invalid_delivery'; end if;
 for v_item in select * from jsonb_array_elements(p_items) loop
   v_qty:=nullif(v_item->>'quantity','')::integer;
   if v_qty is null or v_qty<=0 then raise exception 'invalid_quantity'; end if;
   select * into v_listing from public.marketplace_listings where id=(v_item->>'listing_id')::uuid and status in ('active','published') for update;
   if not found then raise exception 'listing_unavailable'; end if;
   if v_listing.owner_id=v_buyer then raise exception 'self_purchase_not_allowed'; end if;
   v_unit:=coalesce(v_listing.price,0); if v_unit<0 then raise exception 'invalid_price'; end if;
   v_currency:=v_listing.currency_code; if v_currency is null or length(trim(v_currency))=0 then raise exception 'listing_currency_missing'; end if;
   if v_seen_currency is null then v_seen_currency:=v_currency; elsif v_seen_currency<>v_currency then raise exception 'mixed_currency_not_allowed'; end if;
   select * into v_inv from public.marketplace_listing_inventory where listing_id=v_listing.id for update;
   if not found then raise exception 'inventory_not_configured'; end if;
   if v_inv.quantity_available-v_inv.reserved_quantity<v_qty then raise exception 'insufficient_inventory'; end if;
   v_line:=v_unit*v_qty; v_sub:=v_sub+v_line;
 end loop;
 v_fee:=round(v_sub*0.05,2);
 insert into public.marketplace_orders(buyer_id,currency_code,subtotal,delivery_amount,platform_fee,total_amount,status) values(v_buyer,v_seen_currency,v_sub,p_delivery_amount,v_fee,v_sub+p_delivery_amount,'reserved') returning id into v_order;
 for v_item in select * from jsonb_array_elements(p_items) loop
   select seller_id,price,currency_code into v_seller,v_unit,v_currency from public.marketplace_listings where id=(v_item->>'listing_id')::uuid;
   v_qty:=nullif(v_item->>'quantity','')::integer;
   insert into public.marketplace_order_items(order_id,listing_id,seller_id,sku,quantity,unit_price) values(v_order,(v_item->>'listing_id')::uuid,v_seller,null,v_qty,v_unit);
   update public.marketplace_listing_inventory set reserved_quantity=reserved_quantity+v_qty,updated_at=now() where listing_id=(v_item->>'listing_id')::uuid;
 end loop;
 return v_order;
end; $function$
;

CREATE OR REPLACE FUNCTION public.create_organization_resource(p_organization_id uuid, p_location_id uuid, p_sport_id uuid, p_name text, p_resource_type text, p_capacity integer DEFAULT 1, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS organization_resources
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_resource public.organization_resources;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  perform public.require_organization_permission(p_organization_id,'manage_resources');
  if not exists (select 1 from public.organizations where id=p_organization_id) then raise exception 'ORGANIZATION_NOT_FOUND'; end if;
  if p_location_id is not null and not exists (select 1 from public.organization_locations where id=p_location_id and organization_id=p_organization_id) then raise exception 'LOCATION_NOT_IN_ORGANIZATION'; end if;
  if p_sport_id is not null and not exists (select 1 from public.sports where id=p_sport_id) then raise exception 'SPORT_NOT_FOUND'; end if;
  if trim(coalesce(p_name,''))='' or length(trim(p_name))>160 then raise exception 'INVALID_RESOURCE_NAME'; end if;
  if trim(coalesce(p_resource_type,''))='' or length(trim(p_resource_type))>64 then raise exception 'INVALID_RESOURCE_TYPE'; end if;
  if p_capacity<=0 or p_capacity>10000 then raise exception 'INVALID_CAPACITY'; end if;
  insert into public.organization_resources(organization_id,location_id,sport_id,name,resource_type,capacity,metadata)
  values(p_organization_id,p_location_id,p_sport_id,trim(p_name),trim(p_resource_type),p_capacity,coalesce(p_metadata,'{}'::jsonb))
  returning * into v_resource;
  return v_resource;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_organization_role(p_organization_id uuid, p_code text, p_name text, p_description text DEFAULT NULL::text)
 RETURNS organization_roles
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_role public.organization_roles; begin if p_code !~ '^[a-z0-9_]{2,64}$' then raise exception 'Invalid role code'; end if; perform public.require_organization_permission(p_organization_id,'manage_roles'); insert into public.organization_roles(organization_id,code,name,description,is_system) values(p_organization_id,p_code,p_name,p_description,false) returning * into v_role; return v_role; end; $function$
;

CREATE OR REPLACE FUNCTION public.create_physical_shop_sale(p_location_id uuid, p_register_id uuid, p_customer_id uuid, p_items jsonb, p_payment_method text, p_notes text DEFAULT NULL::text, p_tax_amount numeric DEFAULT 0, p_discount_amount numeric DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_sale public.shop_pos_sales; v_order public.shop_orders; v_item jsonb; v_variant uuid; v_qty int; v_product uuid; v_price numeric; v_stock int; v_title text; v_variant_title text; v_subtotal numeric := 0; v_total numeric; v_customer uuid; v_invoice_id uuid; v_location_type text; v_register public.shop_pos_registers;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)=0 then raise exception 'ITEMS_REQUIRED'; end if;
  if coalesce(p_tax_amount,0) < 0 or coalesce(p_discount_amount,0) < 0 then raise exception 'INVALID_ADJUSTMENT'; end if;
  select location_type into v_location_type from public.shop_locations where id=p_location_id and status='active';
  if v_location_type is null then raise exception 'LOCATION_NOT_FOUND'; end if;
  if v_location_type <> 'physical' then raise exception 'POS_REQUIRES_PHYSICAL_LOCATION'; end if;
  select * into v_register from public.shop_pos_registers where id=p_register_id and location_id=p_location_id and status='open' for update;
  if not found then raise exception 'REGISTER_NOT_OPEN'; end if;
  if p_customer_id is not null then perform 1 from public.shop_customers where id=p_customer_id; if not found then raise exception 'CUSTOMER_NOT_FOUND'; end if; v_customer := p_customer_id; end if;
  insert into public.shop_orders(profile_id,status,currency_code,subtotal,discount_amount,shipping_amount,total_amount,shipping_data,fulfillment_status,payment_status,sales_channel)
  values(null,'paid','COP',0,greatest(coalesce(p_discount_amount,0),0),0,0,jsonb_build_object('channel','PHYSICAL','location_id',p_location_id),'delivered','paid','physical') returning * into v_order;
  insert into public.shop_pos_sales(order_id,location_id,register_id,customer_id,seller_profile_id,sale_channel,subtotal,discount_amount,tax_amount,total_amount,payment_method,status,created_by,channel_location_id)
  values(v_order.id,p_location_id,p_register_id,v_customer,null,'physical',0,greatest(coalesce(p_discount_amount,0),0),greatest(coalesce(p_tax_amount,0),0),0,p_payment_method,'completed',auth.uid(),p_location_id) returning * into v_sale;
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_variant := (v_item->>'variant_id')::uuid; v_qty := greatest((v_item->>'quantity')::int,1);
    select pv.product_id,pv.price,pv.title,p.title into v_product,v_price,v_variant_title,v_title from public.shop_product_variants pv join public.shop_products p on p.id=pv.product_id where pv.id=v_variant and pv.is_active=true and lower(p.status)='active' for update;
    if not found then raise exception 'VARIANT_NOT_AVAILABLE'; end if;
    insert into public.shop_inventory_levels(location_id,variant_id,stock_quantity) values(p_location_id,v_variant,0) on conflict do nothing;
    select stock_quantity into v_stock from public.shop_inventory_levels where location_id=p_location_id and variant_id=v_variant for update;
    if v_stock < v_qty then raise exception 'INSUFFICIENT_LOCATION_STOCK'; end if;
    insert into public.shop_pos_sale_items(sale_id,product_id,variant_id,product_title,variant_title,quantity,unit_price,line_total) values(v_sale.id,v_product,v_variant,v_title,v_variant_title,v_qty,v_price,v_price*v_qty);
    insert into public.shop_order_items(order_id,product_id,variant_id,product_title,variant_title,quantity,unit_price,line_total) values(v_order.id,v_product,v_variant,v_title,v_variant_title,v_qty,v_price,v_price*v_qty);
    v_subtotal := v_subtotal + v_price*v_qty;
    update public.shop_inventory_levels set stock_quantity=stock_quantity-v_qty,updated_at=now() where location_id=p_location_id and variant_id=v_variant;
    insert into public.shop_inventory_movements(location_id,variant_id,movement_type,quantity,source_type,source_id,created_by,notes) values(p_location_id,v_variant,'sale',-v_qty,'POS_SALE',v_sale.id,auth.uid(),p_notes);
  end loop;
  v_total := greatest(0,v_subtotal-greatest(coalesce(p_discount_amount,0),0)+greatest(coalesce(p_tax_amount,0),0));
  update public.shop_pos_sales set subtotal=v_subtotal,total_amount=v_total where id=v_sale.id; update public.shop_orders set subtotal=v_subtotal,total_amount=v_total where id=v_order.id;
  insert into public.shop_pos_payments(sale_id,payment_method,amount) values(v_sale.id,p_payment_method,v_total);
  insert into public.shop_invoices(order_id,customer_id,status,subtotal,tax_amount,discount_amount,total_amount,currency_code,issued_at) values(v_order.id,v_customer,'issued',v_subtotal,greatest(coalesce(p_tax_amount,0),0),greatest(coalesce(p_discount_amount,0),0),v_total,'COP',now()) returning id into v_invoice_id;
  update public.shop_pos_sales set invoice_id=v_invoice_id where id=v_sale.id;
  return jsonb_build_object('ok',true,'sale_id',v_sale.id,'order_id',v_order.id,'invoice_id',v_invoice_id,'total_amount',v_total,'location_id',p_location_id,'register_id',p_register_id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_shop_return(p_sale_id uuid, p_location_id uuid, p_customer_id uuid, p_items jsonb, p_refund_method text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_return public.shop_returns;
  v_item jsonb;
  v_sale_item uuid;
  v_variant uuid;
  v_qty int;
  v_unit numeric;
  v_sold_qty int;
  v_returned_qty int;
  v_available_return_qty int;
  v_refund numeric := 0;
  v_location_type text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'RETURN_ITEMS_REQUIRED'; end if;
  if p_refund_method is null or length(trim(p_refund_method))=0 then raise exception 'REFUND_METHOD_REQUIRED'; end if;

  select location_type into v_location_type
  from public.shop_locations
  where id=p_location_id and status='active';
  if v_location_type <> 'physical' then raise exception 'RETURN_REQUIRES_PHYSICAL_LOCATION'; end if;

  perform 1 from public.shop_pos_sales s
  where s.id=p_sale_id and s.status='completed' and s.location_id=p_location_id
  for share;
  if not found then raise exception 'SALE_NOT_RETURNABLE'; end if;

  insert into public.shop_returns(sale_id,location_id,customer_id,reason,refund_method,created_by,status)
  values(p_sale_id,p_location_id,p_customer_id,p_reason,p_refund_method,auth.uid(),'draft')
  returning * into v_return;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_sale_item := (v_item->>'sale_item_id')::uuid;
    v_qty := (v_item->>'quantity')::int;
    if v_qty is null or v_qty <= 0 then raise exception 'INVALID_RETURN_QUANTITY'; end if;

    select variant_id,unit_price,quantity into v_variant,v_unit,v_sold_qty
    from public.shop_pos_sale_items
    where id=v_sale_item and sale_id=p_sale_id
    for update;
    if not found then raise exception 'SALE_ITEM_NOT_FOUND'; end if;

    select coalesce(sum(ri.quantity),0) into v_returned_qty
    from public.shop_return_items ri
    join public.shop_returns rr on rr.id=ri.return_id
    where ri.sale_item_id=v_sale_item and rr.status='completed';

    v_available_return_qty := v_sold_qty - v_returned_qty;
    if v_qty > v_available_return_qty then raise exception 'RETURN_QUANTITY_EXCEEDS_PURCHASE'; end if;

    insert into public.shop_return_items(return_id,sale_item_id,variant_id,quantity,unit_refund,line_refund)
    values(v_return.id,v_sale_item,v_variant,v_qty,v_unit,v_unit*v_qty);
    v_refund := v_refund + v_unit*v_qty;

    insert into public.shop_inventory_levels(location_id,variant_id,stock_quantity)
    values(p_location_id,v_variant,0)
    on conflict (location_id,variant_id) do nothing;

    update public.shop_inventory_levels
    set stock_quantity=stock_quantity+v_qty,updated_at=now()
    where location_id=p_location_id and variant_id=v_variant;

    insert into public.shop_inventory_movements(location_id,variant_id,movement_type,quantity,source_type,source_id,created_by)
    values(p_location_id,v_variant,'RETURN',v_qty,'POS_RETURN',v_return.id,auth.uid());
  end loop;

  update public.shop_returns
  set refund_amount=round(v_refund,2),status='completed'
  where id=v_return.id
  returning * into v_return;

  return jsonb_build_object('ok',true,'return_id',v_return.id,'refund_amount',v_refund);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_skill_challenge(p_sport_id uuid, p_title text, p_description text, p_category text, p_difficulty text DEFAULT 'INTERMEDIATE'::text, p_target_votes integer DEFAULT 100, p_points integer DEFAULT 100, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_id uuid; begin if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if; if not exists(select 1 from public.sports where id=p_sport_id) then raise exception 'SPORT_NOT_FOUND'; end if; if trim(coalesce(p_title,''))='' or length(p_title)>160 then raise exception 'INVALID_TITLE'; end if; if p_difficulty not in ('BEGINNER','INTERMEDIATE','ADVANCED','PRO','ELITE') then raise exception 'INVALID_DIFFICULTY'; end if; if p_target_votes<=0 or p_target_votes>100000 then raise exception 'INVALID_TARGET'; end if; if p_points<0 or p_points>5000 then raise exception 'INVALID_POINTS'; end if; insert into public.skill_challenges(creator_id,sport_id,title,description,category,difficulty,target_votes,points,expires_at) values(auth.uid(),p_sport_id,trim(p_title),nullif(trim(p_description),''),trim(p_category),p_difficulty,p_target_votes,p_points,p_expires_at) returning id into v_id; return v_id; end $function$
;

CREATE OR REPLACE FUNCTION public.enforce_bookable_resource_active()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_status text; begin if new.organization_resource_id is not null then select status into v_status from public.organization_resources where id=new.organization_resource_id; if not found then raise exception 'Organization resource not found'; end if; if v_status<>'active' then raise exception 'Only active resources can be made bookable'; end if; end if; return new; end; $function$
;

CREATE OR REPLACE FUNCTION public.enforce_bookable_resource_ownership()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.uid() is null then return new; end if;
  if new.organization_resource_id is not null
     and (tg_op = 'INSERT' or new.organization_resource_id is distinct from old.organization_resource_id) then
    if not exists (
      select 1
      from public.organization_resources r
      join public.organizations o on o.id = r.organization_id
      where r.id = new.organization_resource_id
        and (o.owner_id = auth.uid()
             or exists (select 1 from public.organization_memberships m
                        where m.organization_id = o.id and m.profile_id = auth.uid() and m.status = 'active'
                          and m.membership_type in ('owner', 'admin', 'manager', 'coach', 'staff')))
    ) then
      raise exception 'RESOURCE_NOT_OWNED';
    end if;
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.enforce_booking_capacity()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_capacity integer; v_reserved integer; begin if new.status not in ('pending','confirmed') then return new; end if; select capacity into v_capacity from public.bookable_entities where id=new.bookable_id for update; if v_capacity is null then raise exception 'Bookable entity not found'; end if; select coalesce(sum(quantity),0) into v_reserved from public.bookings where bookable_id=new.bookable_id and status in ('pending','confirmed') and starts_at < new.ends_at and ends_at > new.starts_at and (tg_op='INSERT' or id<>new.id); if v_reserved + new.quantity > v_capacity then raise exception 'Booking capacity exceeded'; end if; return new; end; $function$
;

CREATE OR REPLACE FUNCTION public.enforce_booking_resource_active()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_status text; begin select r.status into v_status from public.bookable_entities be join public.organization_resources r on r.id=be.organization_resource_id where be.id=new.bookable_id; if v_status is not null and v_status<>'active' then raise exception 'Resource is not available for booking'; end if; return new; end; $function$
;

CREATE OR REPLACE FUNCTION public.enforce_provider_service_relationship()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ begin if new.organization_id is not null and not public.provider_can_operate_service(new.provider_id,new.organization_id) then raise exception 'Provider is not active for this organization'; end if; return new; end; $function$
;

CREATE OR REPLACE FUNCTION public.enforce_shop_pos_sale_permission()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.role() = 'service_role' then return new; end if;
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.has_shop_permission(new.location_id,'sell',auth.uid()) then
    raise exception 'SHOP_PERMISSION_DENIED';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.enforce_shop_return_permission()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.role()='service_role' then return new; end if;
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.has_shop_permission(new.location_id,'sell',auth.uid()) then raise exception 'SHOP_PERMISSION_DENIED'; end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.ensure_challenge_match_on_accept()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_ch public.challenges;
BEGIN
  IF NEW.status='accepted' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
    SELECT * INTO v_ch FROM public.challenges WHERE id=NEW.challenge_id;
    INSERT INTO public.matches(challenge_id,sport_id,status,scheduled_at,location_name,metadata)
    VALUES(v_ch.id,v_ch.sport_id,'scheduled',v_ch.scheduled_at,v_ch.location_name,jsonb_build_object('source','challenge_acceptance'))
    ON CONFLICT (challenge_id) DO NOTHING;
  END IF;
  RETURN NEW;
END; $function$
;

CREATE OR REPLACE FUNCTION public.expire_marketplace_reserved_orders(p_before timestamp with time zone DEFAULT now())
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_count integer := 0; v_order public.marketplace_orders%rowtype; begin
  if auth.role() <> 'service_role' then raise exception 'service_role_required'; end if;
  for v_order in select * from public.marketplace_orders where status='reserved' and created_at < p_before - interval '15 minutes' for update loop
    update public.marketplace_listing_inventory li
      set reserved_quantity = greatest(0, li.reserved_quantity - x.qty), updated_at=now()
    from (select listing_id, sum(quantity)::integer qty from public.marketplace_order_items where order_id=v_order.id group by listing_id) x
    where li.listing_id=x.listing_id;
    update public.marketplace_orders set status='cancelled', updated_at=now(), metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('expired_at',now()) where id=v_order.id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end; $function$
;

CREATE OR REPLACE FUNCTION public.expire_pending_booking_offers()
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_count integer:=0; begin with expired as (update public.bookings set status='expired',updated_at=now(),metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('expired_reason','payment_timeout','expired_at',now()) where status='pending' and payment_status='pending' and created_at + make_interval(mins=>coalesce((select bp.payment_hold_minutes from public.booking_policies bp where bp.bookable_id=bookings.bookable_id),15))<=now() returning id,metadata), wl as (update public.booking_waitlist w set status='expired' from expired e where w.id=(e.metadata->>'waitlist_entry_id')::uuid and w.status='offered' returning w.id) select count(*) into v_count from expired; return v_count; end; $function$
;

CREATE OR REPLACE FUNCTION public.expire_stale_challenge_disputes()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_row record;
  v_count integer := 0;
  c_timeout constant interval := interval '48 hours';
begin
  for v_row in
    select mr.id as result_id, mr.match_id, m.challenge_id
    from public.match_results mr
    join public.matches m on m.id = mr.match_id
    where mr.status in ('pending', 'disputed')
      and mr.updated_at < now() - c_timeout
      and m.challenge_id is not null
      and m.status not in ('completed', 'cancelled')
    order by mr.updated_at
    limit 200
    for update of mr skip locked
  loop
    begin
      update public.match_results set status = 'confirmed', updated_at = now() where id = v_row.result_id;
      update public.matches set status = 'completed', completed_at = coalesce(completed_at, now()), updated_at = now() where id = v_row.match_id;
      update public.challenges set status = 'completed', updated_at = now() where id = v_row.challenge_id and status <> 'completed';
      insert into public.notifications(profile_id, category, type, title, body, action_type, action_payload, source_type, source_id, priority)
      select cp.profile_id, 'match', 'match_result_auto_confirmed', 'Resultado confirmado automáticamente',
             'Pasaron más de 48 horas sin que se resolviera la disputa, así que el último resultado registrado quedó confirmado automáticamente.',
             'open_match', jsonb_build_object('match_id', v_row.match_id), 'match', v_row.match_id, 'normal'
      from public.challenge_participants cp
      where cp.challenge_id = v_row.challenge_id and cp.status = 'accepted'
      on conflict do nothing;
      v_count := v_count + 1;
    exception when others then
      raise warning 'expire_stale_challenge_disputes failed for result %: %', v_row.result_id, sqlerrm;
    end;
  end loop;
  return v_count;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.finish_platform_test_run(p_run_id uuid, p_summary jsonb DEFAULT '{}'::jsonb)
 RETURNS platform_test_runs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_failed integer; v_row public.platform_test_runs;
begin
  if auth.role() <> 'service_role' then raise exception 'service_role_required'; end if;
  select count(*) into v_failed from public.platform_test_assertions where run_id=p_run_id and not passed;
  update public.platform_test_runs
  set status=case when v_failed=0 then 'passed' else 'failed' end,
      finished_at=now(), summary=coalesce(p_summary,'{}'::jsonb)
  where id=p_run_id
  returning * into v_row;
  if not found then raise exception 'test_run_not_found'; end if;
  return v_row;
end; $function$
;

CREATE OR REPLACE FUNCTION public.generate_groups_to_knockout_draw(p_stage_id uuid, p_next_stage_id uuid, p_qualifiers_per_group integer DEFAULT 2)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_stage public.tournament_stages;
  v_next public.tournament_stages;
  v_entry_ids uuid[];
  v_count integer := 0;
  v_i integer;
  v_fixture_id uuid;
  v_cat uuid;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  if p_qualifiers_per_group < 1 or p_qualifiers_per_group > 8 then raise exception 'Invalid qualifier count'; end if;
  select * into v_stage from public.tournament_stages where id=p_stage_id for update;
  select * into v_next from public.tournament_stages where id=p_next_stage_id for update;
  if not found then raise exception 'Stage not found'; end if;
  if v_stage.tournament_id<>v_next.tournament_id then raise exception 'Stages belong to different tournaments'; end if;
  if not (exists(select 1 from public.tournaments t where t.id=v_stage.tournament_id and (t.organizer_profile_id=auth.uid() or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))))) then raise exception 'No autorizado'; end if;
  select category_id into v_cat from public.tournament_stages where id=p_stage_id;
  select array_agg(entry_id order by rank,group_id) into v_entry_ids
  from (select tge.entry_id,tge.group_id,tge.rank,row_number() over(partition by tge.group_id order by tge.rank nulls last,tge.entry_id) rn from public.tournament_group_entries tge where tge.group_id in (select id from public.tournament_groups where stage_id=p_stage_id)) q
  where q.rn<=p_qualifiers_per_group;
  if coalesce(array_length(v_entry_ids,1),0)<2 then raise exception 'Not enough qualified entries'; end if;
  if exists(select 1 from public.tournament_fixtures where stage_id=p_next_stage_id) then return jsonb_build_object('ok',true,'existing',true,'fixtures',(select count(*) from public.tournament_fixtures where stage_id=p_next_stage_id)); end if;
  for v_i in 1..floor(array_length(v_entry_ids,1)/2) loop
    insert into public.tournament_fixtures(tournament_id,category_id,stage_id,slot,round_number,side_a_entry_id,side_b_entry_id,status,metadata)
    values(v_next.tournament_id,v_cat,p_next_stage_id,v_i,1,v_entry_ids[(v_i*2)-1],v_entry_ids[v_i*2],'scheduled',jsonb_build_object('draw_engine','groups_to_knockout','generated_at',now(),'source_stage_id',p_stage_id)) returning id into v_fixture_id;
    v_count:=v_count+1;
  end loop;
  update public.tournament_stages set status='active' where id=p_next_stage_id and status='pending';
  return jsonb_build_object('ok',true,'fixtures',v_count,'next_stage_id',p_next_stage_id,'qualifiers_per_group',p_qualifiers_per_group);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.generate_round_robin_draw(p_stage_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_stage public.tournament_stages;
  v_count integer;
  v_round integer;
  v_slot integer;
  v_entry_a uuid;
  v_entry_b uuid;
  v_group record;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  select * into v_stage from public.tournament_stages where id=p_stage_id for update;
  if not found then raise exception 'Stage not found'; end if;
  if not (exists(select 1 from public.tournaments t where t.id=v_stage.tournament_id and (t.organizer_profile_id=auth.uid() or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))))) then
    raise exception 'No autorizado';
  end if;
  if v_stage.stage_type not in ('round_robin','group') then raise exception 'Stage type not compatible with round robin'; end if;
  if exists(select 1 from public.tournament_fixtures where stage_id=p_stage_id) then
    return jsonb_build_object('ok',true,'existing',true,'fixtures', (select count(*) from public.tournament_fixtures where stage_id=p_stage_id));
  end if;
  v_count:=0;
  for v_group in select g.id from public.tournament_groups g where g.stage_id=p_stage_id order by g.group_order loop
    v_round:=1;
    v_slot:=1;
    for v_entry_a, v_entry_b in
      select a.entry_id,b.entry_id
      from public.tournament_group_entries a
      join public.tournament_group_entries b on b.group_id=a.group_id and b.entry_id>a.entry_id
      where a.group_id=v_group.id
      order by a.entry_id,b.entry_id
    loop
      insert into public.tournament_fixtures(tournament_id,category_id,stage_id,group_id,slot,round_number,side_a_entry_id,side_b_entry_id,status,metadata)
      select v_stage.tournament_id,v_stage.category_id,p_stage_id,v_group.id,v_slot,v_round,v_entry_a,v_entry_b,'scheduled',jsonb_build_object('draw_engine','round_robin','generated_at',now())
      where not exists(select 1 from public.tournament_fixtures f where f.stage_id=p_stage_id and f.group_id=v_group.id and ((f.side_a_entry_id=v_entry_a and f.side_b_entry_id=v_entry_b) or (f.side_a_entry_id=v_entry_b and f.side_b_entry_id=v_entry_a)));
      if found then v_count:=v_count+1; v_slot:=v_slot+1; end if;
      if v_slot>10000 then raise exception 'Too many fixtures'; end if;
    end loop;
  end loop;
  update public.tournament_stages set status='active' where id=p_stage_id and status='pending';
  return jsonb_build_object('ok',true,'fixtures',v_count,'stage_id',p_stage_id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.generate_single_elimination_draw(p_tournament_id uuid, p_category_id uuid, p_stage_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_stage record;
  v_tournament record;
  v_entry_count integer;
  v_bracket_size integer := 1;
  v_rounds integer;
  v_existing integer;
  v_round integer;
  v_slot integer;
  v_total_slots integer;
  v_pos integer;
  v_entry_id uuid;
  v_entry_ids uuid[] := '{}';
  v_fixture_id uuid;
  v_next_id uuid;
  v_seed integer;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;

  select * into v_tournament from public.tournaments where id=p_tournament_id for update;
  if not found then raise exception 'TOURNAMENT_NOT_FOUND'; end if;

  if not (
    v_tournament.organizer_profile_id = auth.uid()
    or (v_tournament.organization_id is not null and public.has_organization_permission(v_tournament.organization_id,'manage_tournaments'))
  ) then raise exception 'TOURNAMENT_PERMISSION_DENIED'; end if;

  select * into v_stage
  from public.tournament_stages
  where id=p_stage_id and tournament_id=p_tournament_id and category_id=p_category_id
  for update;
  if not found then raise exception 'STAGE_NOT_FOUND'; end if;
  if lower(v_stage.stage_type) not in ('single_elimination','knockout','elimination') and lower(coalesce(v_stage.rules->>'format','')) <> 'single_elimination' then
    raise exception 'UNSUPPORTED_STAGE_FORMAT';
  end if;
  if v_stage.status not in ('pending','active') then raise exception 'STAGE_NOT_EDITABLE'; end if;

  select count(*) into v_existing
  from public.tournament_fixtures
  where tournament_id=p_tournament_id and category_id=p_category_id and stage_id=p_stage_id;
  if v_existing > 0 then raise exception 'DRAW_ALREADY_EXISTS'; end if;

  select count(*) into v_entry_count
  from public.tournament_entries te
  where te.tournament_id=p_tournament_id
    and te.category_id=p_category_id
    and te.status='confirmed';
  if v_entry_count < 2 then raise exception 'NOT_ENOUGH_ENTRIES'; end if;

  while v_bracket_size < v_entry_count loop
    v_bracket_size := v_bracket_size * 2;
  end loop;
  v_rounds := ceil(log(2::numeric, v_bracket_size))::integer;
  v_total_slots := v_bracket_size / 2;

  select array_agg(entry_id order by
      case when seed is not null then 0 else 1 end,
      coalesce(seed, recommended_seed),
      recommended_seed,
      entry_id
    ) into v_entry_ids
  from public.get_tournament_fair_play_entries(p_category_id)
  where entry_id in (
    select id from public.tournament_entries
    where tournament_id=p_tournament_id and category_id=p_category_id and status='confirmed'
  );

  if coalesce(array_length(v_entry_ids,1),0) <> v_entry_count then raise exception 'DRAW_ENTRY_MISMATCH'; end if;

  -- Create bracket skeleton round by round.
  for v_round in 1..v_rounds loop
    if v_round = 1 then
      v_total_slots := v_bracket_size / 2;
    else
      v_total_slots := v_bracket_size / power(2,v_round);
    end if;
    for v_slot in 1..v_total_slots loop
      insert into public.tournament_fixtures(
        tournament_id,category_id,stage_id,slot,round_number,status,metadata
      ) values (
        p_tournament_id,p_category_id,p_stage_id,v_slot,v_round,'scheduled',
        jsonb_build_object('draw_method','fair_play_auto','generated_at',now())
      );
    end loop;
  end loop;

  -- Seed first round with bracket positions. Unfilled positions are BYEs.
  for v_pos in 1..v_bracket_size loop
    v_entry_id := case when v_pos <= coalesce(array_length(v_entry_ids,1),0) then v_entry_ids[v_pos] else null end;
    if v_entry_id is null then continue; end if;
    v_slot := ceil(v_pos/2.0)::integer;
    if mod(v_pos,2)=1 then
      update public.tournament_fixtures
      set side_a_entry_id=v_entry_id,
          metadata=metadata || jsonb_build_object('side_a_seed', (select seed from public.tournament_entries where id=v_entry_id),'side_a_position',v_pos)
      where tournament_id=p_tournament_id and category_id=p_category_id and stage_id=p_stage_id and round_number=1 and slot=v_slot;
    else
      update public.tournament_fixtures
      set side_b_entry_id=v_entry_id,
          metadata=metadata || jsonb_build_object('side_b_seed', (select seed from public.tournament_entries where id=v_entry_id),'side_b_position',v_pos)
      where tournament_id=p_tournament_id and category_id=p_category_id and stage_id=p_stage_id and round_number=1 and slot=v_slot;
    end if;
  end loop;

  -- BYE slots are immediately ready; normal fixtures remain scheduled.
  update public.tournament_fixtures
  set status='ready',
      winner_entry_id=coalesce(side_a_entry_id,side_b_entry_id),
      metadata=metadata || jsonb_build_object('bye',true)
  where tournament_id=p_tournament_id and category_id=p_category_id and stage_id=p_stage_id and round_number=1
    and ((side_a_entry_id is null) <> (side_b_entry_id is null));

  -- Link every fixture to the winner destination in the next round.
  for v_round in 1..v_rounds-1 loop
    for v_slot in 1..(v_bracket_size / power(2,v_round+1)) loop
      select id into v_next_id from public.tournament_fixtures
      where tournament_id=p_tournament_id and category_id=p_category_id and stage_id=p_stage_id and round_number=v_round+1 and slot=v_slot;

      update public.tournament_fixtures f
      set next_fixture_id=v_next_id
      where f.tournament_id=p_tournament_id and f.category_id=p_category_id and f.stage_id=p_stage_id
        and f.round_number=v_round and f.slot in (v_slot*2-1,v_slot*2);
    end loop;
  end loop;

  update public.tournament_stages set status='active' where id=p_stage_id;
  return v_bracket_size;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_dynasty_ai_context()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select jsonb_build_object(
    'profile_id', auth.uid(),
    'entitlements', coalesce((
      select jsonb_agg(jsonb_build_object(
        'feature_key', e.feature_key,
        'feature_value', e.feature_value,
        'organization_id', e.organization_id,
        'seller_profile_id', e.seller_profile_id,
        'starts_at', e.starts_at,
        'ends_at', e.ends_at
      ) order by e.feature_key)
      from public.billing_entitlements e
      where (e.profile_id = auth.uid()
          or e.organization_id in (
            select om.organization_id
            from public.organization_memberships om
            where om.profile_id = auth.uid() and om.status = 'active'
          )
          or e.seller_profile_id in (
            select msp.id
            from public.marketplace_seller_profiles msp
            where msp.owner_id = auth.uid()
          ))
        and (e.ends_at is null or e.ends_at > now())
    ), '[]'::jsonb),
    'organizations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', o.id,
        'name', o.name,
        'organization_type', o.organization_type,
        'status', o.status
      ) order by o.name)
      from public.organizations o
      where o.owner_id = auth.uid()
         or o.id in (
           select om.organization_id
           from public.organization_memberships om
           where om.profile_id = auth.uid() and om.status = 'active'
         )
    ), '[]'::jsonb),
    'seller_profiles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id,
        'display_name', s.display_name,
        'seller_type', s.seller_type,
        'premium_status', s.premium_status,
        'status', s.status
      ) order by s.display_name)
      from public.marketplace_seller_profiles s
      where s.owner_id = auth.uid()
    ), '[]'::jsonb)
  );
$function$
;

CREATE OR REPLACE FUNCTION public.get_dynasty_ai_memory(p_profile_id uuid, p_scope text DEFAULT 'athlete'::text)
 RETURNS TABLE(note_key text, note_value jsonb, confidence numeric)
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  select note_key, note_value, confidence
  from public.ai_memory_notes
  where profile_id = auth.uid()
    and scope = p_scope
    and active = true
  order by updated_at desc;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_marketplace_order_items(p_order_id uuid)
 RETURNS SETOF marketplace_order_items
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select i.*
  from public.marketplace_order_items i
  join public.marketplace_orders o on o.id=i.order_id
  where o.id=p_order_id
    and (o.buyer_id=auth.uid()
         or exists (
           select 1 from public.marketplace_seller_profiles s
           where s.id=i.seller_id and s.owner_id=auth.uid()
         ))
  order by i.created_at;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_marketplace_orders()
 RETURNS SETOF marketplace_orders
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select o.*
  from public.marketplace_orders o
  where o.buyer_id = auth.uid()
  order by o.created_at desc;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_marketplace_seller_orders()
 RETURNS TABLE(order_id uuid, order_status text, created_at timestamp with time zone, currency_code text, subtotal numeric, delivery_amount numeric, platform_fee numeric, total_amount numeric, seller_id uuid, seller_gross numeric, seller_fee numeric, seller_refunds numeric, seller_net numeric, seller_settlement_status text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select o.id, o.status, o.created_at, o.currency_code, o.subtotal, o.delivery_amount, o.platform_fee, o.total_amount,
         s.id,
         coalesce(sum(i.line_total),0),
         coalesce(sum(i.seller_fee),0),
         coalesce(ss.refunds_amount,0),
         coalesce(ss.net_amount,0),
         ss.status
  from public.marketplace_orders o
  join public.marketplace_order_items i on i.order_id=o.id
  join public.marketplace_seller_profiles s on s.id=i.seller_id and s.owner_id=auth.uid()
  left join public.marketplace_seller_settlements ss on ss.order_id=o.id and ss.seller_id=s.id
  group by o.id,o.status,o.created_at,o.currency_code,o.subtotal,o.delivery_amount,o.platform_fee,o.total_amount,s.id,ss.refunds_amount,ss.net_amount,ss.status
  order by o.created_at desc;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_shop_admin_snapshot()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_locations uuid[];
  v_inventory jsonb;
  v_alerts jsonb;
  v_sales jsonb;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;

  select coalesce(array_agg(ss.location_id), '{}'::uuid[])
    into v_locations
  from public.shop_staff ss
  where ss.profile_id = auth.uid()
    and ss.status = 'active'
    and ss.role in ('owner','manager','inventory');

  if coalesce(array_length(v_locations,1),0) = 0 then
    raise exception 'SHOP_PERMISSION_DENIED';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.product_title, x.variant_title), '[]'::jsonb)
    into v_inventory
  from public.shop_inventory_dashboard x
  where x.location_id = any(v_locations);

  select coalesce(jsonb_agg(to_jsonb(x) order by x.available_quantity asc, x.product_title), '[]'::jsonb)
    into v_alerts
  from public.shop_inventory_alerts x
  where x.location_id = any(v_locations);

  select coalesce(jsonb_agg(to_jsonb(x) order by x.sale_date desc), '[]'::jsonb)
    into v_sales
  from public.shop_sales_daily x
  where x.location_id = any(v_locations);

  return jsonb_build_object(
    'inventory', v_inventory,
    'alerts', v_alerts,
    'sales', v_sales,
    'location_ids', to_jsonb(v_locations)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_or_create_daily_coach_session(p_mode text DEFAULT 'coach'::text, p_plan jsonb DEFAULT '{}'::jsonb)
 RETURNS ai_daily_coach_sessions
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare r public.ai_daily_coach_sessions;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_mode not in ('coach','fitness','tournament') then raise exception 'INVALID_MODE'; end if;
  if pg_column_size(coalesce(p_plan,'{}'::jsonb)) > 65536 then raise exception 'PLAN_TOO_LARGE'; end if;
  insert into public.ai_daily_coach_sessions(profile_id,session_date,mode,plan)
  values(auth.uid(),current_date,p_mode,coalesce(p_plan,'{}'::jsonb))
  on conflict(profile_id,session_date,mode) do update set updated_at=now()
  returning * into r;
  return r;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_or_create_shop_cart()
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_cart uuid;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  select id into v_cart from public.shop_carts where profile_id=auth.uid() and status='ACTIVE' limit 1;
  if v_cart is null then
    insert into public.shop_carts(profile_id) values(auth.uid()) returning id into v_cart;
  end if;
  return v_cart;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_platform_overview()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  result jsonb;
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'organizations_total', (select count(*) from public.organizations),
    'organizations_active', (select count(*) from public.organizations where status = 'active'),
    'profiles_total', (select count(*) from public.profiles),
    'tournaments_total', (select count(*) from public.tournaments),
    'tournament_entries_total', (select count(*) from public.tournament_entries),
    'bookings_total', (select count(*) from public.bookings),
    'shop_orders_total', (select count(*) from public.shop_orders),
    'marketplace_orders_total', (select count(*) from public.marketplace_orders),
    'billing_subscriptions_active', (
      select count(*) from public.billing_subscriptions where status in ('active', 'trialing')
    ),
    'revenue_paid_cop', (
      coalesce((select sum(amount_paid) from public.billing_invoices where status = 'paid'), 0) +
      coalesce((select sum(total_amount) from public.shop_orders where payment_status = 'paid'), 0) +
      coalesce((select sum(total_amount) from public.marketplace_orders where status = 'paid'), 0) +
      coalesce((select sum(amount_paid) from public.booking_payment_records where payment_status = 'paid'), 0) +
      coalesce((select sum(amount_paid) from public.tournament_registration_payments where status = 'paid'), 0)
    ),
    'organizations', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', o.id,
        'name', o.name,
        'organization_type', o.organization_type,
        'city', o.city,
        'status', o.status,
        'owner_id', o.owner_id,
        'created_at', o.created_at
      )), '[]'::jsonb)
      from (
        select * from public.organizations
        order by created_at desc
        limit 100
      ) o
    )
  ) into result;

  return result;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_player_ranking(p_profile_id uuid, p_sport_id uuid)
 RETURNS TABLE(profile_id uuid, sport_id uuid, rating numeric, wins integer, losses integer, matches_played integer, rank integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select sr.profile_id,sr.sport_id,sr.rating,sr.wins,sr.losses,sr.matches_played,
         coalesce(sr.rank,row_number() over(partition by sr.sport_id order by sr.rating desc,sr.profile_id)::int) as rank
  from public.sport_rankings sr
  where sr.profile_id=p_profile_id and sr.sport_id=p_sport_id;
$function$
;

CREATE OR REPLACE FUNCTION public.get_shop_location_available_stock(p_location_id uuid, p_variant_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_type text;
  v_stock integer;
  v_role text := coalesce(auth.role(),'anon');
begin
  select location_type into v_type
  from public.shop_locations
  where id = p_location_id and status = 'active';

  if v_type is null then
    raise exception 'LOCATION_NOT_FOUND';
  end if;

  if v_type = 'physical' and v_role <> 'service_role' then
    raise exception 'PHYSICAL_STOCK_PRIVATE';
  end if;

  select greatest(0, coalesce(il.stock_quantity,0) - coalesce(il.reserved_quantity,0))
    into v_stock
  from public.shop_inventory_levels il
  where il.location_id = p_location_id
    and il.variant_id = p_variant_id;

  return coalesce(v_stock,0);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_tournament_fair_play_entries(p_category_id uuid)
 RETURNS TABLE(entry_id uuid, seed integer, members_count integer, avg_rating numeric, total_matches integer, total_wins integer, total_losses integer, other_categories_count integer, strength_score numeric, recommended_seed integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_tournament_id uuid; v_organizer uuid; v_org uuid;
begin
  select tc.tournament_id,t.organizer_profile_id,t.organization_id into v_tournament_id,v_organizer,v_org
  from public.tournament_categories tc join public.tournaments t on t.id=tc.tournament_id
  where tc.id=p_category_id;
  if v_tournament_id is null then raise exception 'Category not found'; end if;
  if auth.role() <> 'service_role' and not (
    v_organizer=auth.uid() or (v_org is not null and public.has_organization_permission(v_org,'manage_tournaments',auth.uid()))
  ) then raise exception 'TOURNAMENT_PERMISSION_DENIED'; end if;

  return query
  with cat as (
    select tc.id,tc.tournament_id,t.sport_id from public.tournament_categories tc join public.tournaments t on t.id=tc.tournament_id where tc.id=p_category_id
  ), entries as (
    select te.id,te.seed,c.sport_id,c.tournament_id from public.tournament_entries te join cat c on c.id=te.category_id where te.status in ('pending','confirmed','waitlisted')
  ), members as (
    select e.id entry_id,tem.profile_id from entries e join public.tournament_entry_members tem on tem.entry_id=e.id and tem.status='confirmed'
  ), rating_stats as (
    select m.entry_id,count(*)::int members_count,coalesce(avg(sr.rating),0)::numeric avg_rating,coalesce(sum(sr.matches_played),0)::int member_matches
    from members m left join public.sport_rankings sr on sr.profile_id=m.profile_id and sr.sport_id=(select sport_id from cat) group by m.entry_id
  ), fixture_stats as (
    select e.id entry_id,count(tf.id) filter(where tf.status='completed')::int total_matches,count(tf.id) filter(where tf.status='completed' and tf.winner_entry_id=e.id)::int total_wins,count(tf.id) filter(where tf.status='completed' and tf.winner_entry_id is not null and tf.winner_entry_id<>e.id and (tf.side_a_entry_id=e.id or tf.side_b_entry_id=e.id))::int total_losses
    from entries e left join public.tournament_fixtures tf on tf.category_id=p_category_id and (tf.side_a_entry_id=e.id or tf.side_b_entry_id=e.id) group by e.id
  ), cross_cat as (
    select e.id entry_id,count(distinct te2.category_id) filter(where te2.category_id<>p_category_id)::int other_categories_count
    from entries e join public.tournament_entry_members tem on tem.entry_id=e.id and tem.status='confirmed'
    join public.tournament_entry_members tem2 on tem2.profile_id=tem.profile_id and tem2.status='confirmed'
    join public.tournament_entries te2 on te2.id=tem2.entry_id and te2.tournament_id=(select tournament_id from cat) group by e.id
  ), scores as (
    select e.id entry_id,e.seed,coalesce(rs.members_count,0) members_count,coalesce(rs.avg_rating,0) avg_rating,coalesce(fs.total_matches,0) total_matches,coalesce(fs.total_wins,0) total_wins,coalesce(fs.total_losses,0) total_losses,coalesce(cc.other_categories_count,0) other_categories_count,
      (coalesce(rs.avg_rating,0)+(coalesce(fs.total_wins,0)*25)+(coalesce(fs.total_matches,0)*5))::numeric strength_score
    from entries e left join rating_stats rs on rs.entry_id=e.id left join fixture_stats fs on fs.entry_id=e.id left join cross_cat cc on cc.entry_id=e.id
  )
  select s.entry_id,s.seed,s.members_count,s.avg_rating,s.total_matches,s.total_wins,s.total_losses,s.other_categories_count,s.strength_score,dense_rank() over(order by s.strength_score desc,s.entry_id)::int
  from scores s order by 10;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.guard_tournament_fixture_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF OLD.status = 'completed' AND NEW.status NOT IN ('completed') THEN
    RAISE EXCEPTION 'completed_fixture_is_immutable';
  END IF;
  IF OLD.status = 'cancelled' AND NEW.status NOT IN ('cancelled') THEN
    RAISE EXCEPTION 'cancelled_fixture_is_immutable';
  END IF;
  IF OLD.status = 'scheduled' AND NEW.status NOT IN ('scheduled','ready','in_progress','cancelled','walkover') THEN
    RAISE EXCEPTION 'invalid_fixture_transition';
  END IF;
  IF OLD.status = 'ready' AND NEW.status NOT IN ('ready','in_progress','cancelled','walkover') THEN
    RAISE EXCEPTION 'invalid_fixture_transition';
  END IF;
  IF OLD.status = 'in_progress' AND NEW.status NOT IN ('in_progress','completed','cancelled','walkover') THEN
    RAISE EXCEPTION 'invalid_fixture_transition';
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.guard_tournament_stage_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF OLD.status = 'completed' AND NEW.status <> OLD.status THEN
    RAISE EXCEPTION 'completed_stage_is_immutable';
  END IF;
  IF OLD.status = 'cancelled' AND NEW.status <> OLD.status THEN
    RAISE EXCEPTION 'cancelled_stage_is_immutable';
  END IF;
  IF OLD.status = 'pending' AND NEW.status NOT IN ('pending','active','cancelled') THEN
    RAISE EXCEPTION 'invalid_stage_transition';
  END IF;
  IF OLD.status = 'active' AND NEW.status NOT IN ('active','completed','cancelled') THEN
    RAISE EXCEPTION 'invalid_stage_transition';
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_booking_capacity_release()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ begin if old.status in ('pending','confirmed') and new.status in ('cancelled','expired') then perform public.promote_waitlist_for_booking(old.bookable_id,old.starts_at,old.ends_at); end if; return new; end; $function$
;

CREATE OR REPLACE FUNCTION public.has_ai_entitlement(p_feature_key text, p_profile_id uuid DEFAULT auth.uid(), p_organization_id uuid DEFAULT NULL::uuid, p_seller_profile_id uuid DEFAULT NULL::uuid)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select exists (
    select 1
    from public.billing_entitlements e
    where e.feature_key = p_feature_key
      and (e.ends_at is null or e.ends_at > now())
      and (
        (
          p_profile_id is not null
          and p_profile_id = auth.uid()
          and e.profile_id = auth.uid()
        )
        or (
          p_organization_id is not null
          and e.organization_id = p_organization_id
          and exists (
            select 1
            from public.organization_memberships om
            where om.organization_id = p_organization_id
              and om.profile_id = auth.uid()
              and om.status = 'active'
          )
        )
        or (
          p_seller_profile_id is not null
          and e.seller_profile_id = p_seller_profile_id
          and exists (
            select 1
            from public.marketplace_seller_profiles msp
            where msp.id = p_seller_profile_id
              and msp.owner_id = auth.uid()
          )
        )
      )
  );
$function$
;

CREATE OR REPLACE FUNCTION public.has_organization_permission(p_organization_id uuid, p_permission_key text, p_profile_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN p_profile_id IS DISTINCT FROM auth.uid() AND auth.role() <> 'service_role' THEN false
    ELSE EXISTS (
      SELECT 1
      FROM public.organization_memberships m
      JOIN public.organization_member_roles mr ON mr.membership_id=m.id
      JOIN public.organization_role_permissions rp ON rp.role_id=mr.role_id
      JOIN public.organization_permissions p ON p.id=rp.permission_id
      WHERE m.organization_id=p_organization_id
        AND m.profile_id=p_profile_id
        AND m.status='active'
        AND p.permission_key=p_permission_key
    )
    OR EXISTS (
      SELECT 1 FROM public.organizations o
      WHERE o.id=p_organization_id AND o.owner_id=p_profile_id
    )
  END;
$function$
;

CREATE OR REPLACE FUNCTION public.has_shop_permission(p_location_id uuid, p_permission text, p_profile_id uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select exists (
    select 1 from public.shop_staff ss
    where ss.location_id=p_location_id
      and ss.profile_id = case when auth.role()='service_role' then p_profile_id else auth.uid() end
      and ss.status='active'
      and case p_permission
        when 'sell' then ss.role in ('owner','manager','cashier')
        when 'manage_register' then ss.role in ('owner','manager')
        when 'manage_inventory' then ss.role in ('owner','manager','inventory')
        when 'manage_staff' then ss.role in ('owner','manager')
        when 'view_reports' then ss.role in ('owner','manager','inventory')
        else false
      end
  );
$function$
;

CREATE OR REPLACE FUNCTION public.is_platform_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.platform_admins where profile_id = auth.uid()
  );
$function$
;

CREATE OR REPLACE FUNCTION public.is_sport_relevant(p_profile_id uuid, p_sport_id uuid, p_entity_scope text DEFAULT 'sport_specific'::text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
 select case when p_entity_scope='universal' then true else exists(select 1 from public.player_sports ps where ps.profile_id=p_profile_id and ps.sport_id=p_sport_id and ps.relationship in ('active','primary','secondary','learning','following','discover')) end;
$function$
;

CREATE OR REPLACE FUNCTION public.mark_ai_daily_coach_completed(p_session_id uuid DEFAULT NULL::uuid)
 RETURNS ai_daily_coach_sessions
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$ declare r public.ai_daily_coach_sessions; v_session_id uuid:=p_session_id; begin if v_session_id is null then select id into v_session_id from public.ai_daily_coach_sessions where profile_id=auth.uid() and completed=false and created_at::date=current_date order by created_at desc limit 1; end if; if v_session_id is null then raise exception 'SESSION_NOT_FOUND'; end if; update public.ai_daily_coach_sessions set completed=true,completed_at=coalesce(completed_at,now()),updated_at=now() where id=v_session_id and profile_id=auth.uid() returning * into r; if r.id is null then raise exception 'SESSION_NOT_FOUND'; end if; return r; end; $function$
;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_count integer;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  update public.notifications
     set read_at = now()
   where profile_id = auth.uid()
     and read_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.mark_marketplace_settlement_paid(p_settlement_id uuid, p_provider_payout_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s public.marketplace_seller_settlements%rowtype;
begin
 if auth.role() <> 'service_role' then raise exception 'forbidden'; end if;
 if p_provider_payout_id is null or length(trim(p_provider_payout_id))=0 then raise exception 'provider_payout_id_required'; end if;
 select * into s from public.marketplace_seller_settlements where id=p_settlement_id for update;
 if not found then raise exception 'settlement_not_found'; end if;
 if s.status='paid' then return jsonb_build_object('ok',true,'idempotent',true,'settlement_id',s.id,'status',s.status); end if;
 if s.status <> 'ready' then raise exception 'settlement_not_ready'; end if;
 if s.net_amount <= 0 then raise exception 'settlement_not_payable'; end if;
 update public.marketplace_seller_settlements set status='paid',provider_payout_id=p_provider_payout_id,updated_at=now() where id=s.id;
 return jsonb_build_object('ok',true,'settlement_id',s.id,'status','paid','provider_payout_id',p_provider_payout_id,'net_amount',s.net_amount);
end; $function$
;

CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id uuid)
 RETURNS notifications
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_notification public.notifications; begin update public.notifications set read_at=coalesce(read_at,now()) where id=p_notification_id and profile_id=auth.uid() returning * into v_notification; if not found then raise exception 'Notification not found'; end if; return v_notification; end; $function$
;

CREATE OR REPLACE FUNCTION public.mint_dynasty_card(p_owner uuid, p_original uuid, p_sport uuid, p_rarity text, p_origin text, p_protected boolean, p_source_match uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_id uuid; v_rating numeric; v_level integer;
begin
  select rating into v_rating from public.sport_rankings where profile_id = p_original and sport_id = p_sport;
  select level into v_level from public.player_progression where profile_id = p_original;
  insert into public.dynasty_cards(owner_profile_id, original_profile_id, sport_id, rarity, origin, is_protected, source_match_id, stats)
  values (p_owner, p_original, p_sport, p_rarity, p_origin, p_protected, p_source_match,
          jsonb_build_object('rating', coalesce(v_rating, 1000), 'level', coalesce(v_level, 1)))
  on conflict do nothing
  returning id into v_id;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.notify_booking_status_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_type text; declare v_title text; declare v_body text; begin if new.status is not distinct from old.status then return new; end if; if new.status='confirmed' then v_type:='booking_confirmed'; v_title:='Reserva confirmada'; v_body:='Tu reserva ha sido confirmada.'; elsif new.status='cancelled' then v_type:='booking_cancelled'; v_title:='Reserva cancelada'; v_body:='Tu reserva fue cancelada.'; elsif new.status='expired' then v_type:='booking_expired'; v_title:='Reserva vencida'; v_body:='Tu reserva venció por falta de confirmación.'; elsif new.status='completed' then v_type:='booking_completed'; v_title:='Reserva completada'; v_body:='Tu actividad ha sido completada.'; else return new; end if; insert into public.notifications(profile_id,category,type,title,body,action_type,action_payload,source_type,source_id,priority) select new.booked_by,'booking',v_type,v_title,v_body,'open_booking',jsonb_build_object('booking_id',new.id),'booking',new.id,'normal' where exists (select 1 from public.notification_preferences np where np.profile_id=new.booked_by and np.in_app_enabled=true and coalesce((np.categories->>'booking')::boolean,true)=true) or not exists (select 1 from public.notification_preferences np where np.profile_id=new.booked_by) on conflict do nothing; return new; end; $function$
;

CREATE OR REPLACE FUNCTION public.on_challenge_created_add_creator()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  INSERT INTO public.challenge_participants(challenge_id,profile_id,role,status)
  VALUES(NEW.id,NEW.creator_id,'creator','accepted')
  ON CONFLICT (challenge_id,profile_id) DO UPDATE SET role='creator',status='accepted';
  RETURN NEW;
END; $function$
;

CREATE OR REPLACE FUNCTION public.on_player_sport_mint_base_card()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if new.relationship in ('active', 'primary', 'secondary', 'learning') then
    perform public.mint_dynasty_card(new.profile_id, new.profile_id, new.sport_id, 'common', 'base', true, null);
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.open_shop_pos_register(p_register_id uuid, p_opening_float numeric DEFAULT 0)
 RETURNS shop_pos_registers
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v public.shop_pos_registers;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_opening_float < 0 then raise exception 'INVALID_OPENING_FLOAT'; end if;
 select * into v from public.shop_pos_registers where id=p_register_id for update;
 if not found then raise exception 'REGISTER_NOT_FOUND'; end if;
 if not public.has_shop_permission(v.location_id,'manage_register',auth.uid()) then raise exception 'SHOP_PERMISSION_DENIED'; end if;
 update public.shop_pos_registers set status='open',opened_at=now(),opened_by=auth.uid(),closed_at=null,closed_by=null,opening_float=p_opening_float,closing_total=null,updated_at=now() where id=p_register_id and status<>'disabled' returning * into v;
 if not found then raise exception 'REGISTER_NOT_OPENABLE'; end if;
 return v;
end; $function$
;

CREATE OR REPLACE FUNCTION public.post_paid_booking_to_finance()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_org uuid; v_account uuid; v_category uuid; begin if new.status<>'paid' or old.status='paid' then return new; end if; select o.id into v_org from public.bookable_entities be join public.organizations o on o.owner_id=be.owner_id where be.id=new.booking_id order by o.created_at asc limit 1; if v_org is null then return new; end if; select id into v_account from public.finance_accounts where organization_id=v_org and currency_code=new.currency_code and is_active=true order by created_at asc limit 1; if v_account is null then return new; end if; select id into v_category from public.finance_categories where organization_id=v_org and category_type='income' and is_active=true order by created_at asc limit 1; insert into public.finance_transactions(organization_id,account_id,category_id,transaction_type,amount,currency_code,occurred_at,description,source_type,source_id,status,metadata,created_by) values(v_org,v_account,v_category,'income',new.amount,new.currency_code,coalesce(new.paid_at,now()),'Booking payment','payment',new.id,'posted',jsonb_build_object('booking_id',new.booking_id,'provider',new.provider),new.payer_profile_id) on conflict do nothing; return new; end; $function$
;

CREATE OR REPLACE FUNCTION public.post_payment_refund_to_finance()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_payment public.payment_records; declare v_booking public.bookings; declare v_org uuid; declare v_account uuid; declare v_category uuid; begin if new.status<>'succeeded' or old.status='succeeded' then return new; end if; select * into v_payment from public.payment_records where id=new.payment_id; select * into v_booking from public.bookings where id=v_payment.booking_id; select o.id into v_org from public.bookable_entities be join public.organizations o on o.owner_id=be.owner_id where be.id=v_booking.bookable_id order by o.created_at asc limit 1; if v_org is null then return new; end if; select id into v_account from public.finance_accounts where organization_id=v_org and currency_code=v_payment.currency_code and is_active=true order by created_at asc limit 1; if v_account is null then return new; end if; select id into v_category from public.finance_categories where organization_id=v_org and category_type='expense' and is_active=true order by created_at asc limit 1; insert into public.finance_transactions(organization_id,account_id,category_id,transaction_type,amount,currency_code,occurred_at,description,source_type,source_id,status,metadata) values(v_org,v_account,v_category,'expense',new.amount,v_payment.currency_code,now(),'Payment refund','payment_refund',new.id,'posted',jsonb_build_object('payment_id',new.payment_id,'booking_id',v_payment.booking_id)) on conflict do nothing; return new; end; $function$
;

CREATE OR REPLACE FUNCTION public.prepare_marketplace_seller_settlements(p_order_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_order public.marketplace_orders%rowtype; v_count integer;
begin
  if auth.role() <> 'service_role' then raise exception 'forbidden'; end if;
  select * into v_order from public.marketplace_orders where id=p_order_id for update;
  if not found or v_order.status <> 'fulfilled' then raise exception 'order_not_settleable'; end if;
  insert into public.marketplace_seller_settlements(order_id,seller_id,gross_amount,platform_fee,refunds_amount,currency_code,status)
  select oi.order_id, oi.seller_id, sum(oi.line_total), round(sum(oi.line_total)*0.05,2),
         coalesce((select sum(ir.refund_amount) from public.marketplace_item_returns ir join public.marketplace_order_items x on x.id=ir.order_item_id where x.order_id=oi.order_id and x.seller_id=oi.seller_id and ir.status='refunded'),0),
         v_order.currency_code, 'ready'
  from public.marketplace_order_items oi
  where oi.order_id=p_order_id
  group by oi.order_id,oi.seller_id
  on conflict(order_id,seller_id) do update set gross_amount=excluded.gross_amount, platform_fee=excluded.platform_fee, refunds_amount=excluded.refunds_amount, currency_code=excluded.currency_code, updated_at=now()
  where public.marketplace_seller_settlements.status <> 'paid';
  get diagnostics v_count=row_count;
  return v_count;
end; $function$
;

CREATE OR REPLACE FUNCTION public.preview_tournament_schedule(p_tournament_id uuid, p_slot_minutes integer DEFAULT 60, p_required_rest_slots integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_tournament public.tournaments;
  v_validation jsonb;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select * into v_tournament
  from public.tournaments
  where id = p_tournament_id;

  if not found then
    raise exception 'TOURNAMENT_NOT_FOUND';
  end if;

  if not (
    v_tournament.organizer_profile_id = auth.uid()
    or (
      v_tournament.organization_id is not null
      and public.has_organization_permission(v_tournament.organization_id,'manage_tournaments',auth.uid())
    )
  ) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  v_validation := public.validate_tournament_schedule(
    p_tournament_id,
    p_slot_minutes,
    p_required_rest_slots
  );

  return jsonb_build_object(
    'tournament_id', p_tournament_id,
    'validation', v_validation,
    'preview_only', true
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.process_dynasty_progression(p_profile_id uuid, p_sport_id uuid, p_source_type text, p_source_id uuid, p_won boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_event_id uuid; v_streak integer; v_best integer; v_xp bigint; v_rating numeric; v_matches integer; v_wins integer; v_metric text; v_target numeric; v_progress numeric; v_um public.user_missions; v_m public.missions; v_a public.achievements; v_level integer; v_season public.seasons; v_season_xp integer; v_reward_inserted integer;
begin
  if p_profile_id is null or p_sport_id is null or p_source_id is null then raise exception 'INVALID_PROGRESSION_EVENT'; end if;
  insert into public.dynasty_progression_events(profile_id,sport_id,source_type,source_id,won) values(p_profile_id,p_sport_id,p_source_type,p_source_id,p_won) on conflict(profile_id,source_type,source_id) do nothing returning id into v_event_id;
  if v_event_id is null then return jsonb_build_object('ok',true,'idempotent',true); end if;
  insert into public.player_progression(profile_id,total_xp,level) values(p_profile_id,0,1) on conflict(profile_id) do nothing;
  insert into public.player_sport_streaks(profile_id,sport_id,current_win_streak,best_win_streak,last_match_at,updated_at) values(p_profile_id,p_sport_id,case when p_won then 1 else 0 end,case when p_won then 1 else 0 end,now(),now()) on conflict(profile_id,sport_id) do update set current_win_streak=case when p_won then public.player_sport_streaks.current_win_streak+1 else 0 end,best_win_streak=greatest(public.player_sport_streaks.best_win_streak,case when p_won then public.player_sport_streaks.current_win_streak+1 else 0 end),last_match_at=now(),updated_at=now();
  select current_win_streak,best_win_streak into v_streak,v_best from public.player_sport_streaks where profile_id=p_profile_id and sport_id=p_sport_id;
  select total_xp,level into v_xp,v_level from public.player_progression where profile_id=p_profile_id;
  select coalesce(rating,1000),coalesce(matches_played,0),coalesce(wins,0) into v_rating,v_matches,v_wins from public.sport_rankings where profile_id=p_profile_id and sport_id=p_sport_id;
  v_rating:=coalesce(v_rating,1000);
  for v_m in select * from public.missions where is_active=true and (sport_id is null or sport_id=p_sport_id) loop
    v_metric:=coalesce(v_m.target->>'metric',v_m.mission_type); v_target:=greatest(1,coalesce((v_m.target->>'target')::numeric,1));
    v_progress:=case when v_metric in ('matches','match_count','play') then v_matches when v_metric in ('wins','win_count','win') then v_wins when v_metric in ('xp','total_xp') then v_xp when v_metric in ('rating','elo') then v_rating when v_metric in ('win_streak','streak') then v_best else 0 end;
    insert into public.user_missions(profile_id,mission_id,progress,status) values(p_profile_id,v_m.id,least(v_progress,v_target),case when v_progress>=v_target then 'completed' else 'active' end) on conflict(profile_id,mission_id) do update set progress=greatest(public.user_missions.progress,least(v_progress,v_target)),status=case when greatest(public.user_missions.progress,least(v_progress,v_target))>=v_target then 'completed' else public.user_missions.status end,completed_at=case when greatest(public.user_missions.progress,least(v_progress,v_target))>=v_target then coalesce(public.user_missions.completed_at,now()) else public.user_missions.completed_at end,updated_at=now() returning * into v_um;
    if v_um.status='completed' then
      insert into public.dynasty_mission_rewards(user_mission_id) values(v_um.id) on conflict(user_mission_id) do nothing returning 1 into v_reward_inserted;
      if v_reward_inserted=1 and v_m.xp_reward>0 then perform public.award_xp_system(p_profile_id,v_m.xp_reward,'MISSION_COMPLETED',v_um.id,jsonb_build_object('mission_code',v_m.code,'sport_id',p_sport_id)); end if;
    end if;
  end loop;
  for v_a in select * from public.achievements where is_active=true and code in ('FIRST_MATCH','FIRST_WIN','FIVE_MATCHES','FIVE_WINS','WIN_STREAK_3','WIN_STREAK_5','LEVEL_5','RATING_1200') loop
    if (v_a.code='FIRST_MATCH' and v_matches>=1) or (v_a.code='FIRST_WIN' and v_wins>=1) or (v_a.code='FIVE_MATCHES' and v_matches>=5) or (v_a.code='FIVE_WINS' and v_wins>=5) or (v_a.code='WIN_STREAK_3' and v_best>=3) or (v_a.code='WIN_STREAK_5' and v_best>=5) or (v_a.code='LEVEL_5' and v_level>=5) or (v_a.code='RATING_1200' and v_rating>=1200) then
      insert into public.player_achievements(profile_id,achievement_id,source_id,metadata) values(p_profile_id,v_a.id,p_source_id,jsonb_build_object('sport_id',p_sport_id,'source_type',p_source_type)) on conflict(profile_id,achievement_id) do nothing;
      if found and v_a.xp_reward>0 then perform public.award_xp_system(p_profile_id,v_a.xp_reward,'ACHIEVEMENT_UNLOCKED',v_a.id,jsonb_build_object('achievement_code',v_a.code,'source_id',p_source_id)); end if;
    end if;
  end loop;
  for v_season in select * from public.seasons where status='active' and (sport_id is null or sport_id=p_sport_id) loop
    select coalesce(sum(e.amount),0) into v_season_xp from public.xp_events e where e.profile_id=p_profile_id and e.created_at>=coalesce(v_season.starts_at,'-infinity'::timestamptz) and e.created_at<=coalesce(v_season.ends_at,'infinity'::timestamptz);
    insert into public.player_season_progression(profile_id,season_id,sport_id,xp_earned,matches_played,wins,losses,best_win_streak) values(p_profile_id,v_season.id,p_sport_id,greatest(v_season_xp,0),1,case when p_won then 1 else 0 end,case when p_won then 0 else 1 end,v_best) on conflict(profile_id,season_id) do update set xp_earned=excluded.xp_earned,matches_played=public.player_season_progression.matches_played+1,wins=public.player_season_progression.wins+excluded.wins,losses=public.player_season_progression.losses+excluded.losses,best_win_streak=greatest(public.player_season_progression.best_win_streak,excluded.best_win_streak),updated_at=now();
  end loop;
  return jsonb_build_object('ok',true,'idempotent',false,'profile_id',p_profile_id,'sport_id',p_sport_id,'win_streak',v_streak,'best_win_streak',v_best,'rating',v_rating,'matches',v_matches,'wins',v_wins,'level',v_level);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.process_marketplace_item_return(p_return_id uuid, p_provider_refund_id text, p_restock boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.marketplace_item_returns%rowtype; oi public.marketplace_order_items%rowtype; pay public.marketplace_order_payments%rowtype; s public.marketplace_seller_settlements%rowtype; v_remaining numeric; v_refund_id uuid;
begin
  if auth.role() <> 'service_role' then raise exception 'forbidden'; end if;
  select * into r from public.marketplace_item_returns where id=p_return_id for update;
  if not found then raise exception 'return_not_found'; end if;
  if r.status='refunded' then return jsonb_build_object('ok',true,'idempotent',true,'return_id',r.id,'status',r.status); end if;
  if r.status not in ('requested','approved') then raise exception 'return_not_processable'; end if;
  if p_provider_refund_id is null or length(trim(p_provider_refund_id))=0 then raise exception 'provider_refund_id_required'; end if;
  select * into oi from public.marketplace_order_items where id=r.order_item_id for update;
  select * into s from public.marketplace_seller_settlements where order_id=oi.order_id and seller_id=oi.seller_id for update;
  if found and s.status='paid' then raise exception 'seller_settlement_already_paid'; end if;
  select * into pay from public.marketplace_order_payments where order_id=oi.order_id and status in ('paid','partially_refunded') order by created_at desc limit 1 for update;
  if not found then raise exception 'paid_payment_not_found'; end if;
  select coalesce(pay.amount - coalesce((select sum(pr.amount) from public.marketplace_order_refunds pr where pr.payment_id=pay.id and pr.status in ('requested','succeeded')),0), pay.amount) into v_remaining;
  if r.refund_amount > v_remaining then raise exception 'refund_exceeds_remaining_payment'; end if;
  insert into public.marketplace_order_refunds(payment_id,amount,provider_refund_id,status,reason) values(pay.id,r.refund_amount,p_provider_refund_id,'succeeded',r.reason) returning id into v_refund_id;
  update public.marketplace_item_returns set status='refunded',provider_refund_id=p_provider_refund_id,updated_at=now() where id=r.id;
  if p_restock then update public.marketplace_listing_inventory set quantity_available=quantity_available+r.quantity,updated_at=now() where listing_id=oi.listing_id; end if;
  update public.marketplace_seller_settlements ss set refunds_amount=coalesce((select sum(ir.refund_amount) from public.marketplace_item_returns ir join public.marketplace_order_items x on x.id=ir.order_item_id where x.order_id=ss.order_id and x.seller_id=ss.seller_id and ir.status='refunded'),0),updated_at=now() where ss.order_id=oi.order_id and ss.seller_id=oi.seller_id;
  return jsonb_build_object('ok',true,'return_id',r.id,'refund_id',v_refund_id,'restocked',p_restock,'status','refunded');
end; $function$
;

CREATE OR REPLACE FUNCTION public.promote_booking_waitlist()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_wait public.booking_waitlist; v_policy public.booking_policies; v_capacity integer; v_reserved integer; v_price numeric; v_currency text; v_payment_status text; v_booking_status text; begin if old.status not in ('pending','confirmed') or new.status<>'cancelled' then return new; end if; select * into v_policy from public.booking_policies where bookable_id=new.bookable_id; if not found or not v_policy.allow_waitlist or not v_policy.auto_promote_waitlist then return new; end if; select capacity,price,currency_code into v_capacity,v_price,v_currency from public.bookable_entities where id=new.bookable_id for update; select coalesce(sum(quantity),0) into v_reserved from public.bookings where bookable_id=new.bookable_id and status in ('pending','confirmed') and starts_at<old.ends_at and ends_at>old.starts_at; for v_wait in select * from public.booking_waitlist where bookable_id=new.bookable_id and status='waiting' and requested_starts_at<old.ends_at and requested_ends_at>old.starts_at and (expires_at is null or expires_at>now()) order by priority desc,created_at asc for update skip locked loop if v_reserved+v_wait.quantity<=v_capacity then if coalesce(v_price,0)>0 then v_payment_status:='pending'; v_booking_status:='pending'; else v_payment_status:='not_required'; v_booking_status:='confirmed'; end if; update public.booking_waitlist set status='offered' where id=v_wait.id; insert into public.bookings(bookable_id,booked_by,starts_at,ends_at,quantity,status,payment_status,amount,currency_code,metadata) values(new.bookable_id,v_wait.profile_id,v_wait.requested_starts_at,v_wait.requested_ends_at,v_wait.quantity,v_booking_status,v_payment_status,coalesce(v_price,0)*v_wait.quantity,v_currency,jsonb_build_object('waitlist_entry_id',v_wait.id,'waitlist_promoted',true,'payment_required',coalesce(v_price,0)>0)); if coalesce(v_price,0)>0 then exit; end if; v_reserved:=v_reserved+v_wait.quantity; end if; end loop; return new; end; $function$
;

CREATE OR REPLACE FUNCTION public.promote_waitlist_for_booking(p_bookable_id uuid, p_starts_at timestamp with time zone, p_ends_at timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_wait public.booking_waitlist; v_policy public.booking_policies; v_capacity integer; v_reserved integer; v_price numeric; v_currency text; v_new_booking_id uuid; begin select * into v_policy from public.booking_policies where bookable_id=p_bookable_id; if not found or not v_policy.allow_waitlist or not v_policy.auto_promote_waitlist then return null; end if; select capacity,price,currency_code into v_capacity,v_price,v_currency from public.bookable_entities where id=p_bookable_id for update; select coalesce(sum(quantity),0) into v_reserved from public.bookings where bookable_id=p_bookable_id and status in ('pending','confirmed') and starts_at<p_ends_at and ends_at>p_starts_at; for v_wait in select * from public.booking_waitlist where bookable_id=p_bookable_id and status='waiting' and requested_starts_at<p_ends_at and requested_ends_at>p_starts_at and (expires_at is null or expires_at>now()) order by priority desc,created_at asc for update skip locked loop if v_reserved+v_wait.quantity<=v_capacity then update public.booking_waitlist set status='offered' where id=v_wait.id; insert into public.bookings(bookable_id,booked_by,starts_at,ends_at,quantity,status,payment_status,amount,currency_code,metadata) values(p_bookable_id,v_wait.profile_id,v_wait.requested_starts_at,v_wait.requested_ends_at,v_wait.quantity,case when coalesce(v_price,0)>0 then 'pending' else 'confirmed' end,case when coalesce(v_price,0)>0 then 'pending' else 'not_required' end,coalesce(v_price,0)*v_wait.quantity,v_currency,jsonb_build_object('waitlist_entry_id',v_wait.id,'waitlist_promoted',true,'payment_required',coalesce(v_price,0)>0)); select id into v_new_booking_id from public.bookings where bookable_id=p_bookable_id and booked_by=v_wait.profile_id and metadata->>'waitlist_entry_id'=v_wait.id::text order by created_at desc limit 1; return v_new_booking_id; end if; end loop; return null; end; $function$
;

CREATE OR REPLACE FUNCTION public.protect_listing_privileged()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.uid() is null then return new; end if;
  if tg_op = 'INSERT' then
    new.is_featured := false;
    new.is_premium_placement := false;
  else
    new.is_featured := old.is_featured;
    new.is_premium_placement := old.is_premium_placement;
  end if;
  if new.seller_id is not null and (tg_op = 'INSERT' or new.seller_id is distinct from old.seller_id) then
    if not exists (
      select 1 from public.marketplace_seller_profiles sp
      where sp.id = new.seller_id
        and (sp.owner_id = auth.uid()
             or sp.organization_id in (select o.id from public.organizations o where o.owner_id = auth.uid()))
    ) then
      raise exception 'SELLER_NOT_OWNED';
    end if;
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.protect_profile_system_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if tg_op='UPDATE' then
    new.id := old.id;
    new.created_at := old.created_at;
    new.player_status := old.player_status;
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.protect_seller_profile_privileged()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.uid() is null then return new; end if;
  if tg_op = 'INSERT' then
    new.verification_status := 'unverified';
    new.premium_status := 'free';
  else
    new.verification_status := old.verification_status;
    new.premium_status := old.premium_status;
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.provider_can_operate_service(p_provider_id uuid, p_organization_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN p_provider_id IS DISTINCT FROM auth.uid() AND auth.role() <> 'service_role' THEN false
    ELSE EXISTS (
      SELECT 1 FROM public.provider_organization_relationships r
      WHERE r.provider_id=p_provider_id
        AND r.organization_id=p_organization_id
        AND r.status='active'
        AND (r.ends_on IS NULL OR r.ends_on>=current_date)
    )
  END;
$function$
;

CREATE OR REPLACE FUNCTION public.publish_tournament_schedule(p_tournament_id uuid, p_slot_minutes integer DEFAULT 60, p_required_rest_slots integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_tournament public.tournaments;
  v_validation jsonb;
  v_count integer;
  v_publish_at timestamptz := now();
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  select * into v_tournament from public.tournaments where id=p_tournament_id for update;
  if not found then raise exception 'Tournament not found'; end if;
  if not (v_tournament.organizer_profile_id=auth.uid() or (v_tournament.organization_id is not null and public.has_organization_permission(v_tournament.organization_id,'manage_tournaments',auth.uid()))) then raise exception 'No autorizado para publicar la programación'; end if;
  if v_tournament.status in ('completed','cancelled') then raise exception 'Tournament is not publishable in its current state'; end if;
  select count(*) into v_count from public.tournament_fixtures where tournament_id=p_tournament_id and scheduled_at is not null;
  if v_count=0 then raise exception 'No hay fixtures programados para publicar'; end if;
  v_validation := public.assert_tournament_schedule_publishable(p_tournament_id,p_slot_minutes,p_required_rest_slots);
  update public.tournaments set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('schedule_published_at',v_publish_at,'schedule_published_by',auth.uid(),'schedule_slot_minutes',p_slot_minutes,'schedule_required_rest_slots',p_required_rest_slots,'schedule_validation',v_validation),updated_at=v_publish_at where id=p_tournament_id;
  insert into public.notifications(profile_id,category,type,title,body,action_type,action_payload,source_type,source_id,priority)
  select distinct tem.profile_id,'tournament','tournament_schedule_published','Programación publicada',
    'La programación del torneo '||v_tournament.title||' ya está disponible.',
    'open_tournament',jsonb_build_object('tournament_id',p_tournament_id), 'tournament',p_tournament_id,'high'
  from public.tournament_entries te
  join public.tournament_entry_members tem on tem.entry_id=te.id and tem.status='confirmed'
  where te.tournament_id=p_tournament_id
  on conflict do nothing;
  return jsonb_build_object('ok',true,'tournament_id',p_tournament_id,'scheduled_fixtures',v_count,'validation',v_validation,'published_at',v_publish_at);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.record_ai_recommendation_outcome(p_interaction_id uuid, p_recommendation_key text, p_outcome text, p_reward numeric DEFAULT 0, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_profile uuid; v_id uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select profile_id into v_profile from public.ai_coach_interactions where id=p_interaction_id;
  if v_profile is distinct from auth.uid() then raise exception 'AI_INTERACTION_FORBIDDEN'; end if;
  if p_outcome not in ('accepted','completed','dismissed','ignored','failed') then raise exception 'INVALID_AI_OUTCOME'; end if;
  insert into public.ai_recommendation_outcomes(interaction_id,recommendation_key,outcome,reward,metadata) values(p_interaction_id,p_recommendation_key,p_outcome,greatest(-1,least(1,p_reward)),coalesce(p_metadata,'{}'::jsonb)) returning id into v_id;
  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.record_platform_test_assertion(p_run_id uuid, p_assertion_key text, p_passed boolean, p_detail jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.role() <> 'service_role' then raise exception 'service_role_required'; end if;
  insert into public.platform_test_assertions(run_id,assertion_key,passed,detail)
  values(p_run_id,p_assertion_key,p_passed,coalesce(p_detail,'{}'::jsonb))
  on conflict(run_id,assertion_key) do update
  set passed=excluded.passed, detail=excluded.detail;
end; $function$
;

CREATE OR REPLACE FUNCTION public.record_tournament_fixture_result(p_fixture_id uuid, p_winner_entry_id uuid, p_score_a numeric DEFAULT NULL::numeric, p_score_b numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_fx public.tournament_fixtures;
  v_t public.tournaments;
  v_match uuid;
  v_winner_profile uuid;
  v_loser_entry uuid;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  if (p_score_a is null) <> (p_score_b is null) then raise exception 'SCORES_MUST_BOTH_BE_PRESENT_OR_NULL'; end if;
  if p_score_a is not null and (p_score_a < 0 or p_score_b < 0) then raise exception 'SCORES_MUST_BE_NON_NEGATIVE'; end if;

  select * into v_fx from public.tournament_fixtures where id=p_fixture_id for update;
  if not found then raise exception 'Fixture not found'; end if;
  select * into v_t from public.tournaments where id=v_fx.tournament_id;
  if not found then raise exception 'Tournament not found'; end if;
  if not (v_t.organizer_profile_id=auth.uid() or (v_t.organization_id is not null and public.has_organization_permission(v_t.organization_id,'manage_tournaments',auth.uid()))) then raise exception 'No autorizado para registrar resultado'; end if;
  if v_fx.status in ('completed','cancelled') then raise exception 'Fixture already finalized'; end if;
  if p_winner_entry_id not in (v_fx.side_a_entry_id,v_fx.side_b_entry_id) then raise exception 'Winner must be a fixture participant'; end if;
  if p_score_a is not null and p_score_a = p_score_b then raise exception 'TIED_SCORE_REQUIRES_EXPLICIT_RULE'; end if;

  if v_fx.match_id is null then
    insert into public.matches(sport_id,status,scheduled_at,location_name,metadata)
    values(v_t.sport_id,'completed',v_fx.scheduled_at,null,jsonb_build_object('tournament_fixture_id',p_fixture_id,'tournament_id',v_fx.tournament_id)) returning id into v_match;
    update public.tournament_fixtures set match_id=v_match where id=v_fx.id;
  else
    v_match:=v_fx.match_id;
    update public.matches set status='completed',completed_at=coalesce(completed_at,now()),updated_at=now() where id=v_match;
  end if;

  select captain_profile_id into v_winner_profile from public.tournament_entries where id=p_winner_entry_id;
  v_loser_entry:=case when v_fx.side_a_entry_id=p_winner_entry_id then v_fx.side_b_entry_id else v_fx.side_a_entry_id end;

  update public.tournament_fixtures
  set winner_entry_id=p_winner_entry_id,status='completed',metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('score_a',p_score_a,'score_b',p_score_b,'result_recorded_at',now(),'result_recorded_by',auth.uid())
  where id=p_fixture_id;

  if v_fx.group_id is not null then
    update public.tournament_group_entries ge
    set played=played+1,
        wins=wins+case when ge.entry_id=p_winner_entry_id then 1 else 0 end,
        losses=losses+case when ge.entry_id<>p_winner_entry_id then 1 else 0 end,
        points=points+case when ge.entry_id=p_winner_entry_id then 3 else 0 end,
        score_for=score_for+case when ge.entry_id=p_winner_entry_id then coalesce(p_score_a,0) else coalesce(p_score_b,0) end,
        score_against=score_against+case when ge.entry_id=p_winner_entry_id then coalesce(p_score_b,0) else coalesce(p_score_a,0) end
    where ge.group_id=v_fx.group_id and ge.entry_id in (v_fx.side_a_entry_id,v_fx.side_b_entry_id);
    with ranked as (
      select id,row_number() over(order by points desc,(score_for-score_against) desc,score_for desc,entry_id)::int r
      from public.tournament_group_entries where group_id=v_fx.group_id
    )
    update public.tournament_group_entries ge set rank=ranked.r from ranked where ge.id=ranked.id;
  end if;

  insert into public.match_results(match_id,winner_profile_id,result_data,submitted_by,status)
  values(v_match,v_winner_profile,jsonb_build_object('tournament_fixture_id',p_fixture_id,'winner_entry_id',p_winner_entry_id,'score_a',p_score_a,'score_b',p_score_b),auth.uid(),'confirmed')
  on conflict (match_id) do update set winner_profile_id=excluded.winner_profile_id,result_data=excluded.result_data,status='confirmed',updated_at=now();

  insert into public.notifications(profile_id,category,type,title,body,action_type,action_payload,source_type,source_id,priority)
  select tem.profile_id,'tournament','tournament_result_recorded','Resultado de torneo registrado','Se registró el resultado de tu partido.','open_tournament',jsonb_build_object('tournament_id',v_fx.tournament_id,'fixture_id',p_fixture_id),'tournament_fixture',p_fixture_id,'normal'
  from public.tournament_entry_members tem
  where tem.entry_id in (v_fx.side_a_entry_id,v_fx.side_b_entry_id) and tem.status='confirmed'
  on conflict do nothing;

  return jsonb_build_object('ok',true,'fixture_id',p_fixture_id,'match_id',v_match,'winner_entry_id',p_winner_entry_id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.refund_marketplace_payment(p_payment_id uuid, p_amount numeric, p_provider_refund_id text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_payment public.marketplace_order_payments%rowtype;
  v_refund numeric;
  v_remaining numeric;
  v_refund_id uuid;
  v_existing public.marketplace_order_refunds%rowtype;
begin
  if auth.role() <> 'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'INVALID_REFUND'; end if;
  if p_provider_refund_id is null or length(trim(p_provider_refund_id)) = 0 then raise exception 'REFUND_IDENTITY_REQUIRED'; end if;

  select * into v_payment
  from public.marketplace_order_payments
  where id = p_payment_id
  for update;
  if not found then raise exception 'PAYMENT_NOT_FOUND'; end if;

  select * into v_existing
  from public.marketplace_order_refunds
  where provider_refund_id = p_provider_refund_id
  for update;
  if found then
    if v_existing.payment_id <> p_payment_id or v_existing.amount <> p_amount then
      raise exception 'REFUND_IDENTITY_MISMATCH';
    end if;
    return jsonb_build_object('ok', true, 'idempotent', true, 'refund_id', v_existing.id, 'amount', v_existing.amount);
  end if;

  if v_payment.status not in ('paid','partially_refunded') then raise exception 'PAYMENT_NOT_REFUNDABLE'; end if;

  select coalesce(sum(amount),0) into v_refund
  from public.marketplace_order_refunds
  where payment_id = p_payment_id and status in ('pending','succeeded');
  v_remaining := v_payment.amount - v_refund;
  if p_amount > v_remaining then raise exception 'REFUND_EXCEEDS_REMAINING'; end if;

  insert into public.marketplace_order_refunds(payment_id,amount,provider_refund_id,status,reason)
  values(p_payment_id,p_amount,p_provider_refund_id,'succeeded',p_reason)
  returning id into v_refund_id;

  if p_amount = v_remaining then
    update public.marketplace_order_payments set status='refunded',updated_at=now() where id=p_payment_id;
    update public.marketplace_orders set status='refunded',updated_at=now() where id=v_payment.order_id;
  else
    update public.marketplace_order_payments set status='partially_refunded',updated_at=now() where id=p_payment_id;
    update public.marketplace_orders set status='partially_refunded',updated_at=now() where id=v_payment.order_id;
  end if;

  return jsonb_build_object('ok',true,'idempotent',false,'refund_id',v_refund_id,'amount',p_amount);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.register_tournament_entry(p_category_id uuid, p_member_profile_ids uuid[], p_registration_data jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_cat public.tournament_categories;
  v_tournament public.tournaments;
  v_entry uuid;
  v_member uuid;
  v_count integer;
  v_amount_due numeric;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  if coalesce(array_length(p_member_profile_ids,1),0)<1 then raise exception 'Debe existir al menos un jugador'; end if;
  select * into v_cat from public.tournament_categories where id=p_category_id for update;
  if not found then raise exception 'Category not found'; end if;
  select * into v_tournament from public.tournaments where id=v_cat.tournament_id for update;
  if not found then raise exception 'Tournament not found'; end if;
  if v_tournament.status not in ('published','registration_open') or v_cat.status<>'open' then raise exception 'Registrations are not open'; end if;
  if v_tournament.registration_opens_at is not null and now()<v_tournament.registration_opens_at then raise exception 'Registration has not opened'; end if;
  if v_tournament.registration_closes_at is not null and now()>v_tournament.registration_closes_at then raise exception 'Registration has closed'; end if;
  if v_cat.participant_mode='pair' and array_length(p_member_profile_ids,1)<>2 then raise exception 'Pair category requires exactly 2 members'; end if;
  if v_cat.participant_mode='individual' and array_length(p_member_profile_ids,1)<>1 then raise exception 'Individual category requires exactly 1 member'; end if;
  if v_cat.participant_mode='team' and array_length(p_member_profile_ids,1)<2 then raise exception 'Team category requires at least 2 members'; end if;
  select count(*) into v_count from public.tournament_entries where category_id=p_category_id and status in ('pending','confirmed','waitlisted');
  if v_cat.capacity is not null and v_count>=v_cat.capacity then raise exception 'Category capacity reached'; end if;
  foreach v_member in array p_member_profile_ids loop
    if not exists(select 1 from public.profiles where id=v_member) then raise exception 'Player not found'; end if;
    if exists(select 1 from public.tournament_entry_members tem join public.tournament_entries te on te.id=tem.entry_id where te.category_id=p_category_id and te.status in ('pending','confirmed','waitlisted') and tem.profile_id=v_member) then raise exception 'Player already registered in this category'; end if;
  end loop;
  if not auth.uid() = p_member_profile_ids[1] then
    if not exists(select 1 from public.tournaments t where t.id=v_tournament.id and (t.organizer_profile_id=auth.uid() or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid())))) then
      raise exception 'Only the captain or tournament organizer may register this entry';
    end if;
  end if;
  insert into public.tournament_entries(tournament_id,category_id,entry_type,captain_profile_id,status,registration_data)
  values(v_tournament.id,p_category_id,v_cat.participant_mode,p_member_profile_ids[1],'pending',coalesce(p_registration_data,'{}'::jsonb)) returning id into v_entry;
  foreach v_member in array p_member_profile_ids loop
    insert into public.tournament_entry_members(entry_id,profile_id,role,status)
    values(v_entry,v_member,case when v_member=p_member_profile_ids[1] then 'captain' else 'member' end,case when v_member=p_member_profile_ids[1] then 'confirmed' else 'invited' end);
    if v_member <> p_member_profile_ids[1] then
      insert into public.notifications(profile_id, category, type, title, body, source_type, source_id)
      values (
        v_member, 'tournament', 'tournament_entry_invite_received',
        'Te invitaron a un torneo', 'Alguien te anotó como compañero de equipo. Acepta o rechaza la invitación.',
        'tournament_entry', v_entry
      );
    end if;
  end loop;
  v_amount_due := coalesce(v_cat.entry_fee,v_tournament.entry_fee,0);
  insert into public.tournament_registration_payments(entry_id,amount_due,amount_paid,currency_code,status,paid_at)
  values(
    v_entry,
    v_amount_due,
    0,
    coalesce(v_tournament.currency_code,'COP'),
    case when v_amount_due=0 then 'paid' else 'unpaid' end,
    case when v_amount_due=0 then now() else null end
  );
  if v_amount_due=0 then
    update public.tournament_entries set status='confirmed', updated_at=now() where id=v_entry;
  end if;
  return v_entry;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.release_ai_request_reservation(p_reservation_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  delete from public.ai_request_reservations where id=p_reservation_id and profile_id=auth.uid();
  return true;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.release_card_stakes_on_challenge_cancel()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    update public.challenge_card_stakes set status = 'released', settled_at = now()
      where challenge_id = new.id and status = 'locked';
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.release_expired_shop_inventory_reservations(p_limit integer DEFAULT 500)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_count integer:=0; r record;
begin
 if p_limit<1 or p_limit>5000 then raise exception 'INVALID_LIMIT'; end if;
 for r in select id,variant_id,location_id,quantity,order_id from public.shop_inventory_reservations where status='active' and expires_at<=now() order by expires_at for update skip locked limit p_limit loop
   update public.shop_inventory_levels set reserved_quantity=greatest(0,reserved_quantity-r.quantity),updated_at=now() where location_id=r.location_id and variant_id=r.variant_id;
   update public.shop_inventory_reservations set status='expired',updated_at=now() where id=r.id;
   update public.shop_orders set status='cancelled',payment_status='pending',fulfillment_status='unfulfilled',updated_at=now() where id=r.order_id and status='payment_pending';
   v_count:=v_count+1;
 end loop;
 return v_count;
end; $function$
;

CREATE OR REPLACE FUNCTION public.remove_organization_role(p_membership_id uuid, p_role_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_membership public.organization_memberships;
  v_role public.organization_roles;
  v_org_owner uuid;
  v_actor uuid := auth.uid();
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_membership from public.organization_memberships where id=p_membership_id for update;
  if not found then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;
  select * into v_role from public.organization_roles where id=p_role_id;
  if not found or v_role.organization_id is distinct from v_membership.organization_id then raise exception 'ROLE_ORGANIZATION_MISMATCH'; end if;
  select owner_id into v_org_owner from public.organizations where id=v_membership.organization_id for share;
  if v_org_owner is null then raise exception 'ORGANIZATION_NOT_FOUND'; end if;

  perform public.require_organization_permission(v_membership.organization_id,'manage_roles');

  if lower(coalesce(v_role.code,''))='owner' and v_actor is distinct from v_org_owner then
    raise exception 'OWNER_ROLE_REQUIRES_ORGANIZATION_OWNER';
  end if;

  delete from public.organization_member_roles
  where membership_id=p_membership_id and role_id=p_role_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.request_partner(p_sport_id uuid, p_recipient_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_request_id uuid;
  v_existing public.partner_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_sport_id is null or not exists(select 1 from public.sports where id=p_sport_id) then raise exception 'SPORT_NOT_FOUND'; end if;
  if p_recipient_id is null or auth.uid()=p_recipient_id then raise exception 'SELF_PARTNER_NOT_ALLOWED'; end if;
  if not exists(select 1 from public.profiles where id=p_recipient_id) then raise exception 'PLAYER_NOT_FOUND'; end if;
  if to_regclass('public.user_blocks') is not null and exists(
    select 1 from public.user_blocks
    where (blocker_profile_id=auth.uid() and blocked_profile_id=p_recipient_id)
       or (blocker_profile_id=p_recipient_id and blocked_profile_id=auth.uid())
  ) then raise exception 'PLAYER_BLOCKED'; end if;

  select * into v_existing
  from public.partner_requests
  where sport_id=p_sport_id and requester_id=auth.uid() and recipient_id=p_recipient_id
  for update;

  if found then
    if v_existing.status='PENDING' then
      raise exception 'PARTNER_REQUEST_ALREADY_PENDING';
    elsif v_existing.status='ACCEPTED' then
      raise exception 'PARTNER_REQUEST_ALREADY_ACCEPTED';
    elsif v_existing.status not in ('REJECTED') then
      raise exception 'PARTNER_REQUEST_NOT_REREQUESTABLE';
    end if;

    update public.partner_requests
      set status='PENDING', responded_at=null
      where id=v_existing.id
      returning id into v_request_id;
  else
    insert into public.partner_requests(sport_id,requester_id,recipient_id,status)
    values(p_sport_id,auth.uid(),p_recipient_id,'PENDING')
    returning id into v_request_id;
  end if;

  insert into public.notifications(profile_id,category,type,title,body,action_type,action_payload,source_type,source_id,priority)
  values(p_recipient_id,'partner','PARTNER_REQUEST','Nueva invitación de partner','Te han enviado una invitación para formar pareja.','open_partner_request',jsonb_build_object('request_id',v_request_id),'partner_request',v_request_id,'normal')
  on conflict do nothing;
  return v_request_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.require_organization_permission(p_organization_id uuid, p_permission_key text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ begin if not public.has_organization_permission(p_organization_id,p_permission_key,auth.uid()) then raise exception 'Missing organization permission: %',p_permission_key; end if; end; $function$
;

CREATE OR REPLACE FUNCTION public.reserve_ai_request(p_feature_key text DEFAULT 'ai.chat'::text, p_hour_limit integer DEFAULT 30)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_id uuid; v_count integer; v_profile uuid := auth.uid(); v_limit integer := 30; begin if v_profile is null then raise exception 'AUTH_REQUIRED'; end if; if p_feature_key is null or length(trim(p_feature_key))=0 or length(p_feature_key)>100 then raise exception 'INVALID_FEATURE'; end if; if p_hour_limit is not null and p_hour_limit < 1 then raise exception 'INVALID_LIMIT'; end if; if p_hour_limit is not null and p_hour_limit <> 30 then raise exception 'INVALID_LIMIT'; end if; perform 1 from public.profiles where id=v_profile for update; if not found then raise exception 'PROFILE_NOT_FOUND'; end if; delete from public.ai_request_reservations where expires_at <= now(); select count(*) into v_count from public.ai_usage_events where profile_id=v_profile and feature_key=p_feature_key and created_at >= now()-interval '1 hour'; v_count := v_count + (select count(*) from public.ai_request_reservations where profile_id=v_profile and feature_key=p_feature_key and expires_at > now()); if v_count >= v_limit then raise exception 'AI_RATE_LIMITED'; end if; insert into public.ai_request_reservations(profile_id,feature_key) values(v_profile,p_feature_key) returning id into v_id; return v_id; end; $function$
;

CREATE OR REPLACE FUNCTION public.respond_to_challenge(p_challenge_id uuid, p_response text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv public.challenge_invitations; v_accept boolean;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Debes iniciar sesión'; END IF;
 IF p_response NOT IN ('ACCEPTED','REJECTED') THEN RAISE EXCEPTION 'Respuesta inválida'; END IF;
 v_accept := p_response='ACCEPTED';
 SELECT * INTO v_inv FROM public.challenge_invitations WHERE challenge_id=p_challenge_id AND invitee_id=auth.uid() AND status='pending' ORDER BY created_at DESC LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'No hay una invitación pendiente para este reto'; END IF;
 PERFORM public.respond_to_challenge_invitation(v_inv.id,v_accept);
 RETURN true;
END; $function$
;

CREATE OR REPLACE FUNCTION public.respond_to_challenge_invitation(p_invitation_id uuid, p_accept boolean)
 RETURNS challenge_invitations
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_inv public.challenge_invitations; v_ch public.challenges;
begin
  select * into v_inv from public.challenge_invitations where id = p_invitation_id for update;
  if not found then raise exception 'Invitation not found'; end if;
  if v_inv.invitee_id is distinct from auth.uid() then raise exception 'Not authorized'; end if;
  if v_inv.status <> 'pending' then raise exception 'Invitation is not pending'; end if;
  if v_inv.expires_at is not null and v_inv.expires_at <= now() then
    update public.challenge_invitations set status = 'expired', responded_at = now() where id = p_invitation_id returning * into v_inv;
    update public.challenges set status = 'cancelled', updated_at = now() where id = v_inv.challenge_id and status = 'open';
    return v_inv;
  end if;
  select * into v_ch from public.challenges where id = v_inv.challenge_id for update;
  if not found then raise exception 'Challenge not found'; end if;
  if v_ch.status not in ('open') then raise exception 'Challenge is not open'; end if;

  if p_accept then
    update public.challenge_invitations set status = 'accepted', responded_at = now() where id = p_invitation_id returning * into v_inv;
    insert into public.challenge_participants(challenge_id, profile_id, role, status)
    values (v_inv.challenge_id, auth.uid(), 'opponent', 'accepted')
    on conflict (challenge_id, profile_id) do update set status = 'accepted', role = 'opponent';
    insert into public.notifications(profile_id, category, type, title, body, action_type, action_payload, source_type, source_id, priority)
    values (v_inv.inviter_id, 'challenge', 'challenge_invitation_accepted', 'Reto aceptado', 'Tu reto fue aceptado.', 'open_challenge', jsonb_build_object('challenge_id', v_inv.challenge_id), 'challenge', v_inv.challenge_id, 'normal')
    on conflict do nothing;
  else
    update public.challenge_invitations set status = 'declined', responded_at = now() where id = p_invitation_id returning * into v_inv;
    update public.challenge_participants set status = 'declined' where challenge_id = v_inv.challenge_id and profile_id = auth.uid();
    update public.challenges set status = 'cancelled', updated_at = now() where id = v_inv.challenge_id and status = 'open';
    insert into public.notifications(profile_id, category, type, title, body, action_type, action_payload, source_type, source_id, priority)
    values (v_inv.inviter_id, 'challenge', 'challenge_invitation_declined', 'Reto rechazado', 'Tu invitación fue rechazada.', 'open_challenge', jsonb_build_object('challenge_id', v_inv.challenge_id), 'challenge', v_inv.challenge_id, 'normal')
    on conflict do nothing;
  end if;
  return v_inv;
end; $function$
;

CREATE OR REPLACE FUNCTION public.respond_to_partner_request(p_request_id uuid, p_response text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare r public.partner_requests; begin if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if; select * into r from public.partner_requests where id=p_request_id for update; if not found then raise exception 'PARTNER_REQUEST_NOT_FOUND'; end if; if auth.uid()<>r.recipient_id then raise exception 'ONLY_RECIPIENT_CAN_RESPOND'; end if; if r.status<>'PENDING' then raise exception 'PARTNER_REQUEST_NOT_PENDING'; end if; if p_response not in ('ACCEPTED','REJECTED') then raise exception 'INVALID_RESPONSE'; end if; update public.partner_requests set status=p_response,responded_at=now() where id=r.id; if p_response='ACCEPTED' then insert into public.pair_profiles(sport_id,player_1,player_2) values(r.sport_id,least(r.requester_id,r.recipient_id),greatest(r.requester_id,r.recipient_id)) on conflict(sport_id,player_1,player_2) do nothing; end if; if to_regclass('public.notifications') is not null then insert into public.notifications(profile_id,category,type,title,body,action_type,action_payload,source_type,source_id,priority) values(r.requester_id,'partner','PARTNER_RESPONSE','Respuesta de partner',case when p_response='ACCEPTED' then 'Tu invitación de partner fue aceptada.' else 'Tu invitación de partner fue rechazada.' end,'open_partner_request',jsonb_build_object('request_id',r.id),'partner_request',r.id,'normal') on conflict do nothing; end if; end; $function$
;

CREATE OR REPLACE FUNCTION public.respond_tournament_entry_invite(p_entry_id uuid, p_accept boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_member public.tournament_entry_members;
  v_captain uuid;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;

  select * into v_member from public.tournament_entry_members
    where entry_id = p_entry_id and profile_id = auth.uid()
    for update;

  if not found then
    raise exception 'No tienes una invitación pendiente para este equipo';
  end if;

  if v_member.status <> 'invited' then
    raise exception 'Esta invitación ya fue respondida';
  end if;

  update public.tournament_entry_members
    set status = case when p_accept then 'confirmed' else 'rejected' end
    where entry_id = p_entry_id and profile_id = auth.uid();

  if not p_accept then
    update public.tournament_entries
      set status = 'rejected'
      where id = p_entry_id and status in ('pending','confirmed','waitlisted');
  end if;

  select captain_profile_id into v_captain from public.tournament_entries where id = p_entry_id;

  if v_captain is not null and v_captain <> auth.uid() then
    insert into public.notifications(profile_id, category, type, title, body, source_type, source_id)
    values (
      v_captain, 'tournament', 'tournament_entry_invite_responded',
      case when p_accept then 'Tu compañero aceptó la invitación al torneo' else 'Tu compañero rechazó la invitación al torneo' end,
      null, 'tournament_entry', p_entry_id
    );
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.retry_failed_card_deliveries()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_row record;
  v_fixed integer := 0;
  v_already_done boolean;
begin
  for v_row in
    select * from public.card_delivery_failures
    where not resolved and attempts < 5
    order by created_at
    limit 100
    for update skip locked
  loop
    begin
      if v_row.step = 'trophy_mint' then
        select exists(
          select 1 from public.dynasty_cards
          where source_match_id = v_row.match_id and owner_profile_id = v_row.winner_profile_id and origin = 'win_reward'
        ) into v_already_done;
        if not v_already_done then
          perform public.mint_dynasty_card(v_row.winner_profile_id, v_row.loser_profile_id, v_row.sport_id, coalesce(v_row.rarity, 'common'), 'win_reward', false, v_row.match_id);
        end if;
      elsif v_row.step = 'card_transfer' and v_row.stake_loser_card_id is not null then
        select exists(
          select 1 from public.dynasty_card_transfers
          where card_id = v_row.stake_loser_card_id and to_profile_id = v_row.winner_profile_id and match_id = v_row.match_id
        ) into v_already_done;
        if not v_already_done then
          update public.dynasty_cards set owner_profile_id = v_row.winner_profile_id
            where id = v_row.stake_loser_card_id and owner_profile_id = v_row.loser_profile_id and not is_protected;
          if found then
            insert into public.dynasty_card_transfers(card_id, from_profile_id, to_profile_id, challenge_id, match_id)
            values (v_row.stake_loser_card_id, v_row.loser_profile_id, v_row.winner_profile_id, v_row.challenge_id, v_row.match_id)
            on conflict do nothing;
          end if;
        end if;
      else
        v_already_done := true; -- nada que reintentar (datos insuficientes): se marca resuelto para no acumular basura.
      end if;

      update public.card_delivery_failures
        set resolved = true, last_attempt_at = now()
        where id = v_row.id;

      insert into public.notifications(profile_id, category, type, title, body, action_type, action_payload, source_type, source_id, priority)
      values (v_row.winner_profile_id, 'match', 'card_delivery_fixed', 'Tu carta ya se entregó',
              'El problema técnico con la carta de ese reto ya se resolvió.', 'open_cards', '{}'::jsonb, 'match', v_row.match_id, 'normal')
      on conflict do nothing;
      v_fixed := v_fixed + 1;
    exception when others then
      update public.card_delivery_failures
        set attempts = attempts + 1, last_attempt_at = now(), error_message = sqlerrm
        where id = v_row.id;
    end;
  end loop;
  return v_fixed;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.review_challenge_result(p_result_id uuid, p_confirm boolean)
 RETURNS match_results
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_result public.match_results; v_match public.matches;
BEGIN
  SELECT * INTO v_result FROM public.match_results WHERE id=p_result_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Result not found'; END IF;
  SELECT * INTO v_match FROM public.matches WHERE id=v_result.match_id FOR UPDATE;
  IF NOT FOUND OR v_match.challenge_id IS NULL THEN RAISE EXCEPTION 'Challenge match not found'; END IF;
  IF v_result.status <> 'pending' THEN RAISE EXCEPTION 'Result is not pending'; END IF;
  IF v_result.submitted_by=auth.uid() THEN RAISE EXCEPTION 'Submitter cannot review own result'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.challenge_participants cp WHERE cp.challenge_id=v_match.challenge_id AND cp.profile_id=auth.uid() AND cp.status='accepted') THEN RAISE EXCEPTION 'Not an accepted challenge participant'; END IF;
  IF p_confirm THEN
    UPDATE public.match_results SET status='confirmed',updated_at=now() WHERE id=p_result_id RETURNING * INTO v_result;
    UPDATE public.matches SET status='completed',completed_at=coalesce(completed_at,now()),updated_at=now() WHERE id=v_match.id;
    UPDATE public.challenges SET status='completed',updated_at=now() WHERE id=v_match.challenge_id AND status<>'completed';
    INSERT INTO public.notifications(profile_id,category,type,title,body,action_type,action_payload,source_type,source_id,priority)
    SELECT cp.profile_id,'match','match_result_confirmed','Resultado confirmado','El resultado del partido fue confirmado.','open_match',jsonb_build_object('match_id',v_match.id),'match',v_match.id,'normal'
    FROM public.challenge_participants cp WHERE cp.challenge_id=v_match.challenge_id AND cp.status='accepted'
    ON CONFLICT DO NOTHING;
  ELSE
    UPDATE public.match_results SET status='disputed',updated_at=now() WHERE id=p_result_id RETURNING * INTO v_result;
    INSERT INTO public.notifications(profile_id,category,type,title,body,action_type,action_payload,source_type,source_id,priority)
    VALUES(v_result.submitted_by,'match','match_result_disputed','Resultado disputado','El resultado fue disputado y requiere revisión.','open_match',jsonb_build_object('match_id',v_match.id,'result_id',v_result.id),'match',v_match.id,'high')
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN v_result;
END; $function$
;

CREATE OR REPLACE FUNCTION public.run_platform_invariant_suite(p_suite_name text DEFAULT 'core_invariants'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_run uuid;
  v_failed int := 0;
  v_total int := 0;
  v_checks jsonb := '[]'::jsonb;
  r record;
begin
  if auth.role() <> 'service_role' then raise exception 'service_role_only'; end if;
  insert into public.platform_test_runs(suite,status,started_at)
  values(p_suite_name,'running',now()) returning id into v_run;

  for r in
    select 'shop_no_negative_stock' check_name, count(*) violations from public.shop_inventory_levels where stock_quantity < 0 or reserved_quantity < 0
    union all select 'marketplace_no_negative_inventory', count(*) from public.marketplace_listing_inventory where quantity_available < 0 or reserved_quantity < 0
    union all select 'payment_refunds_over_original', count(*) from public.payment_records pr join (select payment_id,sum(amount) total_refunded from public.payment_refunds where status='succeeded' group by payment_id) x on x.payment_id=pr.id where x.total_refunded > pr.amount
    union all select 'marketplace_refunds_over_payment', count(*) from public.marketplace_order_payments p join (select payment_id,sum(amount) total_refunded from public.marketplace_order_refunds where status='succeeded' group by payment_id) x on x.payment_id=p.id where x.total_refunded > p.amount
    union all select 'shop_duplicate_inventory_keys', count(*)-count(distinct (location_id,variant_id)) from public.shop_inventory_levels
    union all select 'tournament_duplicate_checkins', count(*)-count(distinct (entry_id,profile_id)) from public.tournament_checkins
    union all select 'duplicate_xp_sources', count(*)-count(distinct (profile_id,source_type,source_id)) from public.xp_events where source_id is not null
    union all select 'duplicate_rating_sources', count(*)-count(distinct (profile_id,sport_id,source_match_id)) from public.rating_history where source_match_id is not null
    union all select 'tournaments_invalid_status', count(*) from public.tournaments where status not in ('draft','published','registration_open','registration_closed','in_progress','completed','cancelled')
    union all select 'tournament_categories_invalid_status', count(*) from public.tournament_categories where status not in ('draft','open','closed','in_progress','completed','cancelled')
    union all select 'fixtures_invalid_status', count(*) from public.tournament_fixtures where status not in ('scheduled','ready','in_progress','completed','walkover','cancelled')
    union all select 'shop_orders_negative_total', count(*) from public.shop_orders where total_amount < 0
    union all select 'marketplace_orders_negative_total', count(*) from public.marketplace_orders where total_amount < 0
  loop
    v_total := v_total + 1;
    if r.violations <> 0 then v_failed := v_failed + 1; end if;
    v_checks := v_checks || jsonb_build_array(jsonb_build_object('name',r.check_name,'violations',r.violations,'status',case when r.violations=0 then 'PASS' else 'FAIL' end));
    insert into public.platform_test_assertions(run_id,assertion_key,passed,detail)
    values(v_run,r.check_name,r.violations=0,jsonb_build_object('violations',r.violations));
  end loop;

  update public.platform_test_runs set status=case when v_failed=0 then 'passed' else 'failed' end, finished_at=now(), summary=jsonb_build_object('total',v_total,'failed',v_failed,'checks',v_checks) where id=v_run;
  return jsonb_build_object('run_id',v_run,'suite',p_suite_name,'status',case when v_failed=0 then 'PASS' else 'FAIL' end,'total',v_total,'failed',v_failed,'checks',v_checks);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.run_schema_drift_audit()
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_run_id uuid;
    v_missing_tables jsonb;
      v_stale_grants jsonb;
        v_missing_count integer;
          v_stale_count integer;
            v_risk text;
              v_summary text;
                v_finding record;
                begin
                  with stmts as (
                      select version, name, unnest(statements) as stmt
                          from supabase_migrations.schema_migrations
                            ),
                              created as (
                                  select version, name,
                                        (regexp_matches(stmt, 'create\s+table\s+(?:if not exists\s+)?(?:public\.)?"?([a-zA-Z_][a-zA-Z0-9_]*)"?', 'gi'))[1] as table_name
                                            from stmts
                                                where stmt ilike '%create table%'
                                                  ),
                                                    missing as (
                                                        select c.table_name, array_agg(distinct c.version || ':' || c.name) as migrations
                                                            from created c
                                                                where not exists (
                                                                      select 1 from information_schema.tables it
                                                                            where it.table_schema = 'public' and it.table_name = c.table_name
                                                                                )
                                                                                    group by c.table_name
                                                                                      )
                                                                                        select coalesce(jsonb_agg(jsonb_build_object('table_name', table_name, 'migrations', to_jsonb(migrations))), '[]'::jsonb),
                                                                                                 count(*)
                                                                                                   into v_missing_tables, v_missing_count
                                                                                                     from missing;

                                                                                                       with stmts as (
                                                                                                           select version, name, unnest(statements) as stmt
                                                                                                               from supabase_migrations.schema_migrations
                                                                                                                 ),
                                                                                                                   revokes as (
                                                                                                                       select distinct version, name,
                                                                                                                             (regexp_matches(stmt, 'revoke\s+execute\s+on\s+function\s+(?:public\.)?"?([a-zA-Z_][a-zA-Z0-9_]*)"?', 'gi'))[1] as fn_name
                                                                                                                                 from stmts
                                                                                                                                     where stmt ilike '%revoke%execute%' and (stmt ilike '%anon%' or stmt ilike '%public%')
                                                                                                                                       ),
                                                                                                                                         stale as (
                                                                                                                                             select r.fn_name, array_agg(distinct r.version || ':' || r.name) as migrations
                                                                                                                                                 from revokes r
                                                                                                                                                     where exists (
                                                                                                                                                           select 1 from information_schema.routine_privileges rp
                                                                                                                                                                 where rp.routine_schema = 'public' and rp.routine_name = r.fn_name and rp.grantee in ('anon', 'PUBLIC')
                                                                                                                                                                     )
                                                                                                                                                                         group by r.fn_name
                                                                                                                                                                           )
                                                                                                                                                                             select coalesce(jsonb_agg(jsonb_build_object('function_name', fn_name, 'migrations', to_jsonb(migrations))), '[]'::jsonb),
                                                                                                                                                                                      count(*)
                                                                                                                                                                                        into v_stale_grants, v_stale_count
                                                                                                                                                                                          from stale;

                                                                                                                                                                                            v_risk := case
                                                                                                                                                                                                when v_missing_count > 0 then 'high'
                                                                                                                                                                                                    when v_stale_count > 0 then 'medium'
                                                                                                                                                                                                        else 'low'
                                                                                                                                                                                                          end;

                                                                                                                                                                                                            v_summary := format(
                                                                                                                                                                                                                'Auditoria automatica: %s tabla(s) huerfana(s) por colision de nombre, %s funcion(es) con grant a anon/public pese a un REVOKE historico.',
                                                                                                                                                                                                                    v_missing_count, v_stale_count
                                                                                                                                                                                                                      );

                                                                                                                                                                                                                        insert into public.ai_evolution_runs (
                                                                                                                                                                                                                            trigger_type, scope, status, model, summary, observations, proposals, risk_level, requires_approval, started_at, finished_at
                                                                                                                                                                                                                              ) values (
                                                                                                                                                                                                                                  'manual_audit', 'schema_drift_and_grant_drift', 'completed', 'claude-sonnet-5', v_summary,
                                                                                                                                                                                                                                      jsonb_build_object('missing_tables', v_missing_tables, 'stale_grants', v_stale_grants),
                                                                                                                                                                                                                                          '[]'::jsonb, v_risk, (v_missing_count + v_stale_count) > 0, now(), now()
                                                                                                                                                                                                                                            )
                                                                                                                                                                                                                                              returning id into v_run_id;

                                                                                                                                                                                                                                                for v_finding in select * from jsonb_array_elements(v_missing_tables)
                                                                                                                                                                                                                                                  loop
                                                                                                                                                                                                                                                      insert into public.ai_evolution_proposals (
                                                                                                                                                                                                                                                            run_id, title, category, hypothesis, evidence, proposed_change, risk_level, status
                                                                                                                                                                                                                                                                ) values (
                                                                                                                                                                                                                                                                      v_run_id,
                                                                                                                                                                                                                                                                            'Tabla huerfana: ' || (v_finding.value ->> 'table_name'),
                                                                                                                                                                                                                                                                                  'schema_integrity',
                                                                                                                                                                                                                                                                                        'Una migracion intento crear esta tabla pero no existe en el esquema vivo, probablemente por colision de nombre con una tabla preexistente (CREATE TABLE IF NOT EXISTS no-op) o por un error posterior en la misma migracion.',
                                                                                                                                                                                                                                                                                              v_finding.value,
                                                                                                                                                                                                                                                                                                    'Revisar la migracion original, confirmar la causa exacta y crear la tabla bajo un nombre sin colision si la feature sigue vigente.',
                                                                                                                                                                                                                                                                                                          'high',
                                                                                                                                                                                                                                                                                                                'proposed'
                                                                                                                                                                                                                                                                                                                    );
                                                                                                                                                                                                                                                                                                                      end loop;

                                                                                                                                                                                                                                                                                                                        for v_finding in select * from jsonb_array_elements(v_stale_grants)
                                                                                                                                                                                                                                                                                                                          loop
                                                                                                                                                                                                                                                                                                                              insert into public.ai_evolution_proposals (
                                                                                                                                                                                                                                                                                                                                    run_id, title, category, hypothesis, evidence, proposed_change, risk_level, status
                                                                                                                                                                                                                                                                                                                                        ) values (
                                                                                                                                                                                                                                                                                                                                              v_run_id,
                                                                                                                                                                                                                                                                                                                                                    'Grant abierto pese a REVOKE historico: ' || (v_finding.value ->> 'function_name'),
                                                                                                                                                                                                                                                                                                                                                          'security_grant_drift',
                                                                                                                                                                                                                                                                                                                                                                'Una migracion revoco el acceso de anon/public a esta funcion, pero el permiso sigue activo hoy: probablemente el REVOKE apunto a un rol insuficiente (p.ej. solo anon en vez de PUBLIC) o el objeto se recreo despues sin volver a revocar.',
                                                                                                                                                                                                                                                                                                                                                                      v_finding.value,
                                                                                                                                                                                                                                                                                                                                                                            'Confirmar el rol correcto a revocar y aplicar REVOKE EXECUTE ... FROM PUBLIC, anon explicito sobre esta funcion.',
                                                                                                                                                                                                                                                                                                                                                                                  'medium',
                                                                                                                                                                                                                                                                                                                                                                                        'proposed'
                                                                                                                                                                                                                                                                                                                                                                                            );
                                                                                                                                                                                                                                                                                                                                                                                              end loop;

                                                                                                                                                                                                                                                                                                                                                                                                return v_run_id;
                                                                                                                                                                                                                                                                                                                                                                                                end;
                                                                                                                                                                                                                                                                                                                                                                                                $function$
;

CREATE OR REPLACE FUNCTION public.set_organization_activity_status(p_activity_id uuid, p_is_active boolean)
 RETURNS organization_activities
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_activity public.organization_activities; begin select * into v_activity from public.organization_activities where id=p_activity_id for update; if not found then raise exception 'Activity not found'; end if; perform public.require_organization_permission(v_activity.organization_id,'manage_activities'); update public.organization_activities set is_active=p_is_active where id=p_activity_id returning * into v_activity; return v_activity; end; $function$
;

CREATE OR REPLACE FUNCTION public.set_organization_member_status(p_membership_id uuid, p_status text)
 RETURNS organization_memberships
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_member public.organization_memberships;
  v_owner uuid;
  v_actor uuid := auth.uid();
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_status not in ('active','invited','suspended','left') then raise exception 'INVALID_MEMBERSHIP_STATUS'; end if;
  select * into v_member from public.organization_memberships where id=p_membership_id for update;
  if not found then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;
  select owner_id into v_owner from public.organizations where id=v_member.organization_id for share;
  if v_owner is null then raise exception 'ORGANIZATION_NOT_FOUND'; end if;

  perform public.require_organization_permission(v_member.organization_id,'manage_members');

  -- The organization owner cannot be suspended or removed through the member-management RPC.
  if v_member.profile_id = v_owner and v_actor is distinct from v_owner and p_status <> 'active' then
    raise exception 'OWNER_MEMBERSHIP_PROTECTED';
  end if;

  update public.organization_memberships
     set status=p_status, updated_at=now()
   where id=p_membership_id
  returning * into v_member;
  return v_member;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_organization_resource_status(p_resource_id uuid, p_status text)
 RETURNS organization_resources
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_resource public.organization_resources; begin if p_status not in ('active','maintenance','inactive') then raise exception 'Invalid resource status'; end if; select * into v_resource from public.organization_resources where id=p_resource_id for update; if not found then raise exception 'Resource not found'; end if; perform public.require_organization_permission(v_resource.organization_id,'manage_resources'); update public.organization_resources set status=p_status,updated_at=now() where id=p_resource_id returning * into v_resource; return v_resource; end; $function$
;

CREATE OR REPLACE FUNCTION public.set_role_permission(p_role_id uuid, p_permission_id uuid, p_enabled boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_role public.organization_roles; begin select * into v_role from public.organization_roles where id=p_role_id for update; if not found then raise exception 'Role not found'; end if; if v_role.is_system then raise exception 'System roles cannot be modified'; end if; perform public.require_organization_permission(v_role.organization_id,'manage_roles'); if not exists (select 1 from public.organization_permissions where id=p_permission_id) then raise exception 'Permission not found'; end if; if p_enabled then insert into public.organization_role_permissions(role_id,permission_id) values(p_role_id,p_permission_id) on conflict do nothing; else delete from public.organization_role_permissions where role_id=p_role_id and permission_id=p_permission_id; end if; end; $function$
;

CREATE OR REPLACE FUNCTION public.set_tournament_entry_seed(p_entry_id uuid, p_seed integer)
 RETURNS tournament_entries
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_entry public.tournament_entries;
  v_organizer_id uuid;
  v_organization_id uuid;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  if p_seed is not null and p_seed < 1 then raise exception 'Seed inválido'; end if;

  select te.* into v_entry
  from public.tournament_entries te
  where te.id=p_entry_id
  for update;

  if not found then raise exception 'Tournament entry not found'; end if;

  select organizer_profile_id, organization_id
    into v_organizer_id, v_organization_id
  from public.tournaments
  where id=v_entry.tournament_id;

  if not (
    v_organizer_id = auth.uid()
    or (
      v_organization_id is not null
      and public.has_organization_permission(v_organization_id,'manage_tournaments',auth.uid())
    )
  ) then
    raise exception 'No autorizado para modificar el seed';
  end if;

  update public.tournament_entries
  set seed=p_seed,
      registration_data=coalesce(registration_data,'{}'::jsonb)||jsonb_build_object(
        'seed_override',true,
        'seed_override_by',auth.uid(),
        'seed_override_at',now()
      ),
      updated_at=now()
  where id=p_entry_id
  returning * into v_entry;

  return v_entry;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_weekly_challenge_participant_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.settle_challenge_card_stakes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_match public.matches;
  v_win public.challenge_card_stakes;
  v_lose public.challenge_card_stakes;
  v_have_win boolean; v_have_lose boolean;
  v_loser uuid; v_wins integer; v_rarity text; v_recent integer; v_distinct integer; v_global_recent integer;
  v_step text := 'card_transfer';
  c_max_trophies_per_rival constant integer := 2;
  c_max_trophies_per_week constant integer := 6; -- NUEVO: tope global, sin importar el rival
  c_min_rivals_for_rarity constant integer := 3;
begin
  if new.status <> 'confirmed' or (tg_op = 'UPDATE' and old.status = 'confirmed') then return new; end if;
  if new.winner_profile_id is null then return new; end if;

  begin
    select * into v_match from public.matches where id = new.match_id;
    if not found or v_match.challenge_id is null then return new; end if;

    select * into v_win from public.challenge_card_stakes
      where challenge_id = v_match.challenge_id and status = 'locked' and profile_id = new.winner_profile_id for update;
    v_have_win := found;
    select * into v_lose from public.challenge_card_stakes
      where challenge_id = v_match.challenge_id and status = 'locked' and profile_id <> new.winner_profile_id for update;
    v_have_lose := found;

    if v_have_win and v_have_lose then
      update public.dynasty_cards set owner_profile_id = new.winner_profile_id
        where id = v_lose.card_id and owner_profile_id = v_lose.profile_id and not is_protected;
      if found then
        insert into public.dynasty_card_transfers(card_id, from_profile_id, to_profile_id, challenge_id, match_id)
        values (v_lose.card_id, v_lose.profile_id, new.winner_profile_id, v_match.challenge_id, v_match.id)
        on conflict do nothing;
        update public.challenge_card_stakes set status = 'settled', settled_at = now() where id in (v_win.id, v_lose.id);
        insert into public.notifications(profile_id, category, type, title, body, action_type, action_payload, source_type, source_id, priority)
        values
          (new.winner_profile_id, 'match', 'card_won', '¡Ganaste una carta!', 'Ganaste el reto y te quedaste con la carta de tu rival.', 'open_cards', jsonb_build_object('card_id', v_lose.card_id), 'match', v_match.id, 'high'),
          (v_lose.profile_id, 'match', 'card_lost', 'Perdiste una carta', 'Perdiste el reto y tu carta pasó a tu rival. Revancha.', 'open_cards', jsonb_build_object('card_id', v_lose.card_id), 'match', v_match.id, 'high')
        on conflict do nothing;
        return new;
      end if;
    end if;

    update public.challenge_card_stakes set status = 'released', settled_at = now()
      where challenge_id = v_match.challenge_id and status = 'locked';

    select cp.profile_id into v_loser from public.challenge_participants cp
      where cp.challenge_id = v_match.challenge_id and cp.status = 'accepted' and cp.profile_id <> new.winner_profile_id
      order by cp.joined_at limit 1;

    if v_loser is not null then
      v_step := 'trophy_mint';

      select count(*) into v_recent
        from public.dynasty_cards c
        join public.match_results mr on mr.match_id = c.source_match_id
        where c.origin = 'win_reward' and c.original_profile_id = v_loser
          and mr.winner_profile_id = new.winner_profile_id
          and c.created_at > now() - interval '7 days';
      if v_recent >= c_max_trophies_per_rival then
        insert into public.notifications(profile_id, category, type, title, body, action_type, action_payload, source_type, source_id, priority)
        values (new.winner_profile_id, 'match', 'card_limit', 'Victoria registrada',
                'Ganaste el reto, pero ya alcanzaste el máximo de cartas trofeo contra este rival esta semana. Gana contra otros jugadores para seguir coleccionando.',
                'open_cards', '{}'::jsonb, 'match', v_match.id, 'normal')
        on conflict do nothing;
        return new;
      end if;

      -- NUEVO (b): tope global semanal, sin importar contra quien se gane. Antes solo existia el
      -- tope por rival de arriba, asi que turnandose entre 3+ rivales distintos se podian seguir
      -- acumulando cartas comunes sin ningun limite real.
      select count(*) into v_global_recent
        from public.dynasty_cards c
        join public.match_results mr on mr.match_id = c.source_match_id
        where c.origin = 'win_reward' and mr.winner_profile_id = new.winner_profile_id
          and c.created_at > now() - interval '7 days';
      if v_global_recent >= c_max_trophies_per_week then
        insert into public.notifications(profile_id, category, type, title, body, action_type, action_payload, source_type, source_id, priority)
        values (new.winner_profile_id, 'match', 'card_limit', 'Victoria registrada',
                'Ganaste el reto, pero ya alcanzaste el máximo de cartas trofeo de la semana. Vuelven a estar disponibles la próxima semana.',
                'open_cards', '{}'::jsonb, 'match', v_match.id, 'normal')
        on conflict do nothing;
        return new;
      end if;

      select count(*) into v_wins from public.match_results mr join public.matches m on m.id = mr.match_id
        where mr.status = 'confirmed' and mr.winner_profile_id = new.winner_profile_id
          and m.sport_id = v_match.sport_id and m.challenge_id is not null;

      select count(distinct cp2.profile_id) into v_distinct
        from public.match_results mr
        join public.matches m on m.id = mr.match_id
        join public.challenge_participants cp2 on cp2.challenge_id = m.challenge_id
          and cp2.status = 'accepted' and cp2.profile_id <> new.winner_profile_id
        where mr.status = 'confirmed' and mr.winner_profile_id = new.winner_profile_id
          and m.sport_id = v_match.sport_id and m.challenge_id is not null;

      v_rarity := case
        when v_distinct < c_min_rivals_for_rarity then 'common'
        when v_wins % 25 = 0 then 'legendary'
        when v_wins % 10 = 0 then 'epic'
        when v_wins % 5 = 0 then 'rare'
        else 'common' end;

      perform public.mint_dynasty_card(new.winner_profile_id, v_loser, v_match.sport_id, v_rarity, 'win_reward', false, v_match.id);

      insert into public.notifications(profile_id, category, type, title, body, action_type, action_payload, source_type, source_id, priority)
      values (new.winner_profile_id, 'match', 'card_trophy', '¡Nueva carta trofeo!',
              'Ganaste el reto y sumaste una carta a tu colección.',
              'open_cards', '{}'::jsonb, 'match', v_match.id, 'high')
      on conflict do nothing;
    end if;
  exception when others then
    -- NUEVO (c): antes esto solo quedaba como "raise warning" (nadie lo ve) y liberaba las
    -- cartas en silencio. Ahora ademas se registra el fallo para reintentarlo solo, y se avisa a
    -- los jugadores involucrados en vez de dejarlos sin ninguna explicacion.
    raise warning 'settle_challenge_card_stakes failed for match %: %', new.match_id, sqlerrm;
    begin
      update public.challenge_card_stakes set status = 'released', settled_at = now()
        where challenge_id = (select challenge_id from public.matches where id = new.match_id) and status = 'locked';
    exception when others then null;
    end;
    begin
      insert into public.card_delivery_failures(challenge_id, match_id, winner_profile_id, loser_profile_id, sport_id, rarity, step, stake_loser_card_id, error_message)
      values (
        (select challenge_id from public.matches where id = new.match_id),
        new.match_id, new.winner_profile_id, v_loser, v_match.sport_id, v_rarity, v_step,
        case when v_have_lose then v_lose.card_id else null end,
        sqlerrm
      );
      insert into public.notifications(profile_id, category, type, title, body, action_type, action_payload, source_type, source_id, priority)
      select p, 'match', 'card_delivery_issue', 'Problema entregando tu carta',
             'Ganaste (o jugaste) este reto, pero hubo un problema técnico entregando la carta. El sistema lo va a reintentar automáticamente; no tienes que hacer nada.',
             'open_match', jsonb_build_object('match_id', new.match_id), 'match', new.match_id, 'normal'
      from unnest(array[new.winner_profile_id, v_loser]) as p
      where p is not null
      on conflict do nothing;
    exception when others then null; -- si hasta el registro del fallo falla, no se vuelve a intentar desde aqui (nunca debe tumbar la confirmacion del resultado).
    end;
  end;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.stake_card_on_challenge(p_challenge_id uuid, p_card_id uuid)
 RETURNS challenge_card_stakes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_ch public.challenges;
  v_card public.dynasty_cards;
  v_stake public.challenge_card_stakes;
  v_locked integer;
begin
  if v_uid is null then raise exception 'Debes iniciar sesión'; end if;
  select * into v_ch from public.challenges where id = p_challenge_id for update;
  if not found then raise exception 'Reto no encontrado'; end if;
  if v_ch.status not in ('open', 'accepted', 'active') then raise exception 'El reto ya no admite cartas en juego'; end if;
  if not exists (select 1 from public.challenge_participants cp where cp.challenge_id = p_challenge_id and cp.profile_id = v_uid and cp.status = 'accepted') then
    raise exception 'Solo los participantes aceptados pueden poner una carta en juego';
  end if;
  if exists (select 1 from public.match_results mr join public.matches m on m.id = mr.match_id where m.challenge_id = p_challenge_id) then
    raise exception 'Ya hay un resultado enviado para este reto';
  end if;
  select * into v_card from public.dynasty_cards where id = p_card_id for update;
  if not found or v_card.owner_profile_id <> v_uid then raise exception 'Esa carta no es tuya'; end if;
  if v_card.is_protected then raise exception 'La carta base está protegida y no se puede poner en juego'; end if;
  if v_card.sport_id <> v_ch.sport_id then raise exception 'La carta debe ser del mismo deporte del reto'; end if;
  select count(*) into v_locked from public.challenge_card_stakes where challenge_id = p_challenge_id and status = 'locked';
  if v_locked >= 2 then raise exception 'Las cartas de este reto ya están bloqueadas'; end if;

  update public.challenge_card_stakes set status = 'released', settled_at = now()
    where challenge_id = p_challenge_id and profile_id = v_uid and status = 'locked';
  begin
    insert into public.challenge_card_stakes(challenge_id, profile_id, card_id)
    values (p_challenge_id, v_uid, p_card_id) returning * into v_stake;
  exception when unique_violation then
    raise exception 'Esa carta ya está en juego en otro reto';
  end;

  insert into public.notifications(profile_id, category, type, title, body, action_type, action_payload, source_type, source_id, priority)
  select cp.profile_id, 'challenge', 'card_stake_placed', 'Carta en juego', 'Tu rival puso una carta en juego. Pon la tuya para acordar la apuesta.',
         'open_challenge', jsonb_build_object('challenge_id', p_challenge_id), 'challenge', p_challenge_id, 'normal'
  from public.challenge_participants cp
  where cp.challenge_id = p_challenge_id and cp.profile_id <> v_uid and cp.status = 'accepted'
  on conflict do nothing;
  return v_stake;
end $function$
;

CREATE OR REPLACE FUNCTION public.submit_challenge_result(p_match_id uuid, p_winner_profile_id uuid, p_result_data jsonb DEFAULT '{}'::jsonb)
 RETURNS match_results
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_match public.matches; v_result public.match_results;
BEGIN
  SELECT * INTO v_match FROM public.matches WHERE id=p_match_id FOR UPDATE;
  IF NOT FOUND OR v_match.challenge_id IS NULL THEN RAISE EXCEPTION 'Challenge match not found'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.challenge_participants cp WHERE cp.challenge_id=v_match.challenge_id AND cp.profile_id=auth.uid() AND cp.status='accepted') THEN RAISE EXCEPTION 'Not an accepted challenge participant'; END IF;
  IF v_match.status NOT IN ('scheduled','in_progress') THEN RAISE EXCEPTION 'Match is not active'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.challenge_participants cp WHERE cp.challenge_id=v_match.challenge_id AND cp.profile_id=p_winner_profile_id AND cp.status='accepted') THEN RAISE EXCEPTION 'Winner must be a participant'; END IF;
  SELECT * INTO v_result FROM public.match_results WHERE match_id=p_match_id FOR UPDATE;
  IF FOUND THEN
    IF v_result.status='confirmed' THEN RAISE EXCEPTION 'Result already confirmed'; END IF;
    IF v_result.submitted_by=auth.uid() THEN RAISE EXCEPTION 'Existing result was submitted by you'; END IF;
    UPDATE public.match_results SET winner_profile_id=p_winner_profile_id,result_data=coalesce(p_result_data,'{}'::jsonb),submitted_by=auth.uid(),status='pending',updated_at=now() WHERE id=v_result.id RETURNING * INTO v_result;
  ELSE
    INSERT INTO public.match_results(match_id,winner_profile_id,result_data,submitted_by,status) VALUES(p_match_id,p_winner_profile_id,coalesce(p_result_data,'{}'::jsonb),auth.uid(),'pending') RETURNING * INTO v_result;
  END IF;
  INSERT INTO public.notifications(profile_id,category,type,title,body,action_type,action_payload,source_type,source_id,priority)
  SELECT cp.profile_id,'match','match_result_submitted','Resultado enviado','Hay un resultado pendiente de confirmar.','open_match',jsonb_build_object('match_id',p_match_id),'match',p_match_id,'high'
  FROM public.challenge_participants cp WHERE cp.challenge_id=v_match.challenge_id AND cp.profile_id<>auth.uid() AND cp.status='accepted'
  ON CONFLICT DO NOTHING;
  RETURN v_result;
END; $function$
;

CREATE OR REPLACE FUNCTION public.submit_match_result(p_challenge_id uuid, p_score_set1 text, p_score_set2 text, p_score_set3 text, p_winner_id uuid, p_result_data jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_match public.matches; v_result public.match_results; v_payload jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Debes iniciar sesión'; END IF;
 SELECT * INTO v_match FROM public.matches WHERE challenge_id=p_challenge_id LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'No existe partido para este reto'; END IF;
 v_payload := coalesce(p_result_data,'{}'::jsonb) || jsonb_build_object('score_set1',p_score_set1,'score_set2',p_score_set2,'score_set3',p_score_set3);
 v_result := public.submit_challenge_result(v_match.id,p_winner_id,v_payload);
 RETURN v_result.id;
END; $function$
;

CREATE OR REPLACE FUNCTION public.submit_skill_challenge(p_challenge_id uuid, p_video_url text, p_caption text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_id uuid; v_status text; begin if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if; select status into v_status from public.skill_challenges where id=p_challenge_id for update; if v_status is null then raise exception 'CHALLENGE_NOT_FOUND'; end if; if v_status not in ('OPEN','SUBMITTED','VOTING') then raise exception 'CHALLENGE_CLOSED'; end if; if trim(coalesce(p_video_url,''))='' or length(p_video_url)>2000 then raise exception 'INVALID_VIDEO_URL'; end if; insert into public.skill_submissions(challenge_id,user_id,video_url,caption) values(p_challenge_id,auth.uid(),trim(p_video_url),nullif(trim(p_caption),'')) on conflict(challenge_id,user_id) do update set video_url=excluded.video_url,caption=excluded.caption returning id into v_id; update public.skill_challenges set status='SUBMITTED' where id=p_challenge_id and status='OPEN'; return v_id; end $function$
;

CREATE OR REPLACE FUNCTION public.suspend_bookings_for_resource(p_resource_id uuid, p_reason text DEFAULT 'resource_unavailable'::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_resource public.organization_resources; declare v_count integer; begin select * into v_resource from public.organization_resources where id=p_resource_id for update; if not found then raise exception 'Resource not found'; end if; perform public.require_organization_permission(v_resource.organization_id,'manage_resources'); update public.bookings b set status='cancelled',updated_at=now(),metadata=metadata||jsonb_build_object('cancel_reason',p_reason,'cancelled_by_resource',p_resource_id) from public.bookable_entities be where be.id=b.bookable_id and be.organization_resource_id=p_resource_id and b.status in ('pending','confirmed') and b.starts_at>now(); get diagnostics v_count=row_count; return v_count; end; $function$
;

CREATE OR REPLACE FUNCTION public.swap_tournament_fixture_entries(p_fixture_a uuid, p_fixture_b uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  a record; b record; t record;
  tmp_a uuid; tmp_b uuid; v_stage_status text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_fixture_a = p_fixture_b then raise exception 'SAME_FIXTURE'; end if;
  select * into a from public.tournament_fixtures where id=p_fixture_a for update;
  if not found then raise exception 'FIXTURE_NOT_FOUND'; end if;
  select * into b from public.tournament_fixtures where id=p_fixture_b for update;
  if not found then raise exception 'FIXTURE_NOT_FOUND'; end if;
  if a.tournament_id<>b.tournament_id or a.category_id<>b.category_id or a.stage_id<>b.stage_id or a.round_number<>1 or b.round_number<>1 then raise exception 'INCOMPATIBLE_FIXTURES'; end if;
  select * into t from public.tournaments where id=a.tournament_id for update;
  if not (t.organizer_profile_id=auth.uid() or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments'))) then raise exception 'TOURNAMENT_PERMISSION_DENIED'; end if;
  select s.status into v_stage_status from public.tournament_stages s where s.id=a.stage_id;
  if v_stage_status not in ('pending','active') then raise exception 'STAGE_NOT_EDITABLE'; end if;
  if a.status in ('completed','in_progress') or b.status in ('completed','in_progress') then raise exception 'FIXTURE_NOT_EDITABLE'; end if;
  tmp_a:=a.side_a_entry_id; tmp_b:=a.side_b_entry_id;
  update public.tournament_fixtures set side_a_entry_id=b.side_a_entry_id,side_b_entry_id=b.side_b_entry_id,
    metadata=metadata||jsonb_build_object('manual_override',true,'override_by',auth.uid(),'override_at',now()) where id=a.id;
  update public.tournament_fixtures set side_a_entry_id=tmp_a,side_b_entry_id=tmp_b,
    metadata=metadata||jsonb_build_object('manual_override',true,'override_by',auth.uid(),'override_at',now()) where id=b.id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.transfer_shop_inventory(p_variant_id uuid, p_from_location_id uuid, p_to_location_id uuid, p_quantity integer, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ declare v_from int; v_to int; begin if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if; if p_quantity<1 then raise exception 'INVALID_QUANTITY'; end if; if p_from_location_id=p_to_location_id then raise exception 'SAME_LOCATION'; end if; if not public.has_shop_permission(p_from_location_id,'manage_inventory',auth.uid()) or not public.has_shop_permission(p_to_location_id,'manage_inventory',auth.uid()) then raise exception 'SHOP_PERMISSION_DENIED'; end if; select stock_quantity into v_from from public.shop_inventory_levels where location_id=p_from_location_id and variant_id=p_variant_id for update; if v_from is null or v_from<p_quantity then raise exception 'INSUFFICIENT_STOCK'; end if; insert into public.shop_inventory_levels(location_id,variant_id,stock_quantity) values(p_to_location_id,p_variant_id,0) on conflict do nothing; update public.shop_inventory_levels set stock_quantity=stock_quantity-p_quantity,updated_at=now() where location_id=p_from_location_id and variant_id=p_variant_id; update public.shop_inventory_levels set stock_quantity=stock_quantity+p_quantity,updated_at=now() where location_id=p_to_location_id and variant_id=p_variant_id returning stock_quantity into v_to; insert into public.shop_inventory_movements(location_id,variant_id,movement_type,quantity,source_type,notes,created_by) values(p_from_location_id,p_variant_id,'TRANSFER_OUT',-p_quantity,'TRANSFER',p_notes,auth.uid()),(p_to_location_id,p_variant_id,'TRANSFER_IN',p_quantity,'TRANSFER',p_notes,auth.uid()); return jsonb_build_object('ok',true,'from_location',p_from_location_id,'to_location',p_to_location_id,'quantity',p_quantity,'from_remaining',v_from-p_quantity,'to_new_stock',v_to); end; $function$
;

CREATE OR REPLACE FUNCTION public.transition_tournament_status(p_tournament_id uuid, p_new_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_t public.tournaments%rowtype;
  v_allowed boolean := false;
begin
  if v_actor is null then
    raise exception 'not_authenticated';
  end if;

  select * into v_t
  from public.tournaments
  where id = p_tournament_id
  for update;

  if not found then
    raise exception 'tournament_not_found';
  end if;

  if p_new_status is null or p_new_status not in ('draft','published','registration_open','registration_closed','in_progress','completed','cancelled') then
    raise exception 'invalid_tournament_status';
  end if;

  -- Only the organizer or a member with the explicit tournament-management permission may change status.
  v_allowed := v_t.organizer_profile_id = v_actor
    or (v_t.organization_id is not null and public.has_organization_permission(v_t.organization_id,'manage_tournaments',v_actor));

  if not v_allowed then
    raise exception 'forbidden';
  end if;

  case v_t.status
    when 'draft' then v_allowed := p_new_status in ('published','cancelled');
    when 'published' then v_allowed := p_new_status in ('registration_open','cancelled');
    when 'registration_open' then v_allowed := p_new_status in ('registration_closed','cancelled');
    when 'registration_closed' then v_allowed := p_new_status in ('in_progress','cancelled');
    when 'in_progress' then v_allowed := p_new_status in ('completed','cancelled');
    when 'completed' then v_allowed := false;
    when 'cancelled' then v_allowed := false;
    else v_allowed := false;
  end case;

  if not v_allowed then
    raise exception 'invalid_status_transition: % -> %', v_t.status, p_new_status;
  end if;

  update public.tournaments
  set status = p_new_status, updated_at = now()
  where id = p_tournament_id;

  return jsonb_build_object('ok', true, 'tournament_id', p_tournament_id, 'from', v_t.status, 'to', p_new_status);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.upsert_dynasty_ai_memory(p_scope text, p_note_key text, p_note_value jsonb, p_confidence numeric DEFAULT NULL::numeric, p_source_message_id uuid DEFAULT NULL::uuid)
 RETURNS ai_memory_notes
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare row_out public.ai_memory_notes;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_scope is null or length(trim(p_scope))=0 or length(trim(p_scope))>64 then raise exception 'INVALID_SCOPE'; end if;
  if p_note_key is null or length(trim(p_note_key))=0 or length(trim(p_note_key))>128 then raise exception 'INVALID_NOTE_KEY'; end if;
  if pg_column_size(coalesce(p_note_value,'{}'::jsonb)) > 16384 then raise exception 'NOTE_TOO_LARGE'; end if;
  if p_confidence is not null and (p_confidence < 0 or p_confidence > 1) then raise exception 'INVALID_CONFIDENCE'; end if;
  insert into public.ai_memory_notes(profile_id,scope,note_key,note_value,confidence,source_message_id)
  values(auth.uid(),trim(p_scope),trim(p_note_key),coalesce(p_note_value,'{}'::jsonb),p_confidence,p_source_message_id)
  on conflict(profile_id,scope,note_key)
  do update set note_value=excluded.note_value,confidence=excluded.confidence,source_message_id=excluded.source_message_id,active=true,updated_at=now()
  returning * into row_out;
  return row_out;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.upsert_shop_cart_item(p_product_id uuid, p_variant_id uuid, p_quantity integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_cart uuid; v_item uuid; v_active boolean; v_stock integer; v_reserved integer; v_online uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_quantity < 1 or p_quantity > 100 then raise exception 'INVALID_QUANTITY'; end if;
  v_online := (select id from public.shop_locations where code='ONLINE' and status='active' limit 1);
  if v_online is null then raise exception 'ONLINE_LOCATION_NOT_CONFIGURED'; end if;
  v_cart := public.get_or_create_shop_cart();
  if p_variant_id is not null then
    select pv.is_active,p.stock_quantity into v_active,v_stock from public.shop_product_variants pv join public.shop_products p on p.id=pv.product_id where pv.id=p_variant_id and pv.product_id=p_product_id;
    if not found then raise exception 'VARIANT_NOT_FOUND'; end if;
    if not coalesce(v_active,false) then raise exception 'PRODUCT_NOT_AVAILABLE'; end if;
    insert into public.shop_inventory_levels(location_id,variant_id,stock_quantity) values(v_online,p_variant_id,0) on conflict do nothing;
    select il.stock_quantity,il.reserved_quantity into v_stock,v_reserved from public.shop_inventory_levels il where il.location_id=v_online and il.variant_id=p_variant_id for update;
    if coalesce(v_stock,0)-coalesce(v_reserved,0) < p_quantity then raise exception 'ONLINE_STOCK_INSUFFICIENT'; end if;
  else
    select (status='active') into v_active from public.shop_products where id=p_product_id;
    if not found or not v_active then raise exception 'PRODUCT_NOT_AVAILABLE'; end if;
  end if;
  insert into public.shop_cart_items(cart_id,product_id,variant_id,quantity) values(v_cart,p_product_id,p_variant_id,p_quantity)
  on conflict(cart_id,product_id,variant_id) do update set quantity=excluded.quantity,updated_at=now() returning id into v_item;
  update public.shop_carts set updated_at=now() where id=v_cart; return v_item;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.upsert_shop_customer(p_customer_id uuid DEFAULT NULL::uuid, p_full_name text DEFAULT NULL::text, p_document_type text DEFAULT NULL::text, p_document_number text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_email text DEFAULT NULL::text, p_address text DEFAULT NULL::text, p_notes text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if coalesce(length(trim(p_full_name)),0) < 2 then raise exception 'CUSTOMER_NAME_REQUIRED'; end if;
  if p_customer_id is null then
    insert into public.shop_customers(full_name,document_type,document_number,phone,email,address,notes,metadata)
    values(p_full_name,p_document_type,p_document_number,p_phone,p_email,p_address,p_notes,jsonb_build_object('created_by',auth.uid())) returning id into v_id;
  else
    update public.shop_customers set full_name=p_full_name,document_type=p_document_type,document_number=p_document_number,phone=p_phone,email=p_email,address=p_address,notes=p_notes,updated_at=now() where id=p_customer_id returning id into v_id;
    if v_id is null then raise exception 'CUSTOMER_NOT_FOUND'; end if;
  end if;
  return v_id;
end; $function$
;

CREATE OR REPLACE FUNCTION public.upsert_shop_staff_member(p_location_id uuid, p_profile_id uuid, p_role text, p_status text DEFAULT 'active'::text)
 RETURNS shop_staff
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v public.shop_staff; v_is_owner boolean;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_profile_id is null then raise exception 'PROFILE_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id=p_profile_id) then raise exception 'PROFILE_NOT_FOUND'; end if;
  if not exists (select 1 from public.shop_locations where id=p_location_id and status='active') then raise exception 'LOCATION_NOT_FOUND'; end if;
  if p_role not in ('owner','manager','cashier','inventory') then raise exception 'INVALID_SHOP_ROLE'; end if;
  if p_status not in ('active','suspended','revoked') then raise exception 'INVALID_SHOP_STAFF_STATUS'; end if;
  if not public.has_shop_permission(p_location_id,'manage_staff',auth.uid()) then raise exception 'SHOP_PERMISSION_DENIED'; end if;
  select exists (
    select 1 from public.shop_staff ss
    where ss.location_id=p_location_id and ss.profile_id=auth.uid() and ss.status='active' and ss.role='owner'
  ) into v_is_owner;
  if p_role='owner' and not v_is_owner then raise exception 'ONLY_OWNER_CAN_GRANT_OWNER'; end if;
  insert into public.shop_staff(location_id,profile_id,role,status)
  values(p_location_id,p_profile_id,p_role,p_status)
  on conflict (location_id,profile_id)
  do update set role=excluded.role,status=excluded.status,updated_at=now()
  returning * into v;
  return v;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.validate_tournament_entry_scope()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_category_tournament uuid;
BEGIN
  SELECT tournament_id INTO v_category_tournament FROM public.tournament_categories WHERE id=NEW.category_id;
  IF v_category_tournament IS NULL OR v_category_tournament <> NEW.tournament_id THEN
    RAISE EXCEPTION 'category_id must belong to tournament_id';
  END IF;
  RETURN NEW;
END; $function$
;

CREATE OR REPLACE FUNCTION public.validate_tournament_fixture_scope()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_category_tournament uuid; v_stage_tournament uuid; v_stage_category uuid; v_entry_tournament uuid; v_entry_category uuid; v_group_stage uuid;
BEGIN
  SELECT tournament_id INTO v_category_tournament FROM public.tournament_categories WHERE id=NEW.category_id;
  IF v_category_tournament IS NULL OR v_category_tournament <> NEW.tournament_id THEN RAISE EXCEPTION 'fixture category must belong to tournament'; END IF;
  IF NEW.stage_id IS NOT NULL THEN
    SELECT tournament_id,category_id INTO v_stage_tournament,v_stage_category FROM public.tournament_stages WHERE id=NEW.stage_id;
    IF v_stage_tournament <> NEW.tournament_id OR v_stage_category <> NEW.category_id THEN RAISE EXCEPTION 'fixture stage scope mismatch'; END IF;
  END IF;
  IF NEW.group_id IS NOT NULL THEN
    SELECT stage_id INTO v_group_stage FROM public.tournament_groups WHERE id=NEW.group_id;
    IF v_group_stage IS NULL OR NEW.stage_id IS NULL OR v_group_stage <> NEW.stage_id THEN RAISE EXCEPTION 'fixture group must belong to fixture stage'; END IF;
  END IF;
  FOREACH v_entry_tournament IN ARRAY ARRAY[NEW.side_a_entry_id,NEW.side_b_entry_id,NEW.winner_entry_id] LOOP
    IF v_entry_tournament IS NOT NULL THEN
      SELECT tournament_id,category_id INTO v_entry_tournament,v_entry_category FROM public.tournament_entries WHERE id=v_entry_tournament;
      IF v_entry_tournament <> NEW.tournament_id OR v_entry_category <> NEW.category_id THEN RAISE EXCEPTION 'fixture entry scope mismatch'; END IF;
    END IF;
  END LOOP;
  RETURN NEW;
END; $function$
;

CREATE OR REPLACE FUNCTION public.validate_tournament_schedule(p_tournament_id uuid, p_slot_minutes integer DEFAULT 60, p_required_rest_slots integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_issues jsonb;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión';
  end if;

  if p_slot_minutes < 1 or p_slot_minutes > 240 then
    raise exception 'slot_minutes inválido';
  end if;

  if p_required_rest_slots < 0 or p_required_rest_slots > 5 then
    raise exception 'required_rest_slots inválido';
  end if;

  if not exists (
    select 1
    from public.tournaments t
    where t.id = p_tournament_id
      and (
        t.organizer_profile_id = auth.uid()
        or (
          t.organization_id is not null
          and public.has_organization_permission(t.organization_id, 'manage_tournaments', auth.uid())
        )
      )
  ) then
    raise exception 'No autorizado para validar este torneo';
  end if;

  with fixture_entries as (
    select
      f.id as fixture_id,
      f.tournament_id,
      f.category_id,
      f.scheduled_at,
      x.entry_id
    from public.tournament_fixtures f
    cross join lateral (
      values (f.side_a_entry_id), (f.side_b_entry_id)
    ) x(entry_id)
    where f.tournament_id = p_tournament_id
      and f.scheduled_at is not null
      and x.entry_id is not null
  ),
  fixture_players as (
    select distinct
      fe.fixture_id,
      fe.tournament_id,
      fe.category_id,
      fe.scheduled_at,
      tem.profile_id,
      fe.entry_id
    from fixture_entries fe
    join public.tournament_entry_members tem
      on tem.entry_id = fe.entry_id
     and tem.status = 'confirmed'
  ),
  player_pairs as (
    select
      a.profile_id,
      a.fixture_id as fixture_a_id,
      b.fixture_id as fixture_b_id,
      a.category_id as category_a_id,
      b.category_id as category_b_id,
      a.entry_id as entry_a_id,
      b.entry_id as entry_b_id,
      least(a.scheduled_at, b.scheduled_at) as first_start,
      greatest(a.scheduled_at, b.scheduled_at) as second_start,
      abs(extract(epoch from (a.scheduled_at - b.scheduled_at))) / 60.0 as start_gap_minutes
    from fixture_players a
    join fixture_players b
      on a.profile_id = b.profile_id
     and a.fixture_id < b.fixture_id
  ),
  issues as (
    select
      profile_id,
      fixture_a_id,
      fixture_b_id,
      category_a_id,
      category_b_id,
      entry_a_id,
      entry_b_id,
      first_start,
      second_start,
      start_gap_minutes,
      case
        when start_gap_minutes < p_slot_minutes then 'CRITICAL'
        when start_gap_minutes < (p_slot_minutes * (p_required_rest_slots + 1)) then 'CRITICAL'
        else 'OK'
      end as severity,
      case
        when start_gap_minutes < p_slot_minutes then 'SOLAPAMIENTO DE PARTIDOS'
        when start_gap_minutes < (p_slot_minutes * (p_required_rest_slots + 1)) then 'DESCANSO INSUFICIENTE'
        else null
      end as issue_type
    from player_pairs
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'severity', severity,
        'issue_type', issue_type,
        'profile_id', profile_id,
        'fixture_a_id', fixture_a_id,
        'fixture_b_id', fixture_b_id,
        'category_a_id', category_a_id,
        'category_b_id', category_b_id,
        'entry_a_id', entry_a_id,
        'entry_b_id', entry_b_id,
        'first_start', first_start,
        'second_start', second_start,
        'start_gap_minutes', round(start_gap_minutes::numeric, 2),
        'required_gap_minutes', p_slot_minutes * (p_required_rest_slots + 1),
        'blocks_publication', (severity = 'CRITICAL')
      )
      order by first_start, profile_id
    ) filter (where severity <> 'OK'),
    '[]'::jsonb
  ) into v_issues
  from issues;

  return jsonb_build_object(
    'tournament_id', p_tournament_id,
    'valid', jsonb_array_length(v_issues) = 0,
    'issue_count', jsonb_array_length(v_issues),
    'slot_minutes', p_slot_minutes,
    'required_rest_slots', p_required_rest_slots,
    'issues', v_issues
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.validate_tournament_stage_scope()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_category_tournament uuid;
BEGIN
  SELECT tournament_id INTO v_category_tournament FROM public.tournament_categories WHERE id=NEW.category_id;
  IF v_category_tournament IS NULL OR v_category_tournament <> NEW.tournament_id THEN
    RAISE EXCEPTION 'category_id must belong to tournament_id';
  END IF;
  RETURN NEW;
END; $function$
;

CREATE OR REPLACE FUNCTION public.vote_skill_submission(p_submission_id uuid, p_value integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ begin if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if; if p_value not between 1 and 5 then raise exception 'INVALID_VOTE'; end if; if not exists(select 1 from public.skill_submissions ss join public.skill_challenges sc on sc.id=ss.challenge_id where ss.id=p_submission_id and sc.status in ('SUBMITTED','VOTING')) then raise exception 'SUBMISSION_NOT_VOTABLE'; end if; if exists(select 1 from public.skill_submissions where id=p_submission_id and user_id=auth.uid()) then raise exception 'SELF_VOTE_NOT_ALLOWED'; end if; insert into public.skill_votes(submission_id,user_id,value) values(p_submission_id,auth.uid(),p_value) on conflict(submission_id,user_id) do update set value=excluded.value; update public.skill_submissions set votes=(select count(*) from public.skill_votes where submission_id=p_submission_id) where id=p_submission_id; end $function$
;

CREATE OR REPLACE FUNCTION public.withdraw_card_stake(p_challenge_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_uid uuid := auth.uid(); v_locked integer;
begin
  if v_uid is null then raise exception 'Debes iniciar sesión'; end if;
  perform 1 from public.challenges where id = p_challenge_id for update;
  if not found then raise exception 'Reto no encontrado'; end if;
  select count(*) into v_locked from public.challenge_card_stakes where challenge_id = p_challenge_id and status = 'locked';
  if v_locked >= 2 then raise exception 'Las cartas de este reto ya están bloqueadas'; end if;
  if exists (select 1 from public.match_results mr join public.matches m on m.id = mr.match_id where m.challenge_id = p_challenge_id) then
    raise exception 'Ya hay un resultado enviado para este reto';
  end if;
  update public.challenge_card_stakes set status = 'released', settled_at = now()
  where challenge_id = p_challenge_id and profile_id = v_uid and status = 'locked';
end $function$
;


-- ============================================================================
-- TRIGGERS (28)
-- ============================================================================

CREATE TRIGGER trg_enforce_bookable_resource_active BEFORE INSERT OR UPDATE OF organization_resource_id ON public.bookable_entities FOR EACH ROW EXECUTE FUNCTION enforce_bookable_resource_active();
CREATE TRIGGER trg_enforce_bookable_resource_ownership BEFORE INSERT OR UPDATE OF organization_resource_id ON public.bookable_entities FOR EACH ROW EXECUTE FUNCTION enforce_bookable_resource_ownership();
CREATE TRIGGER booking_conflict_guard BEFORE INSERT OR UPDATE OF bookable_id, starts_at, ends_at, quantity, status ON public.bookings FOR EACH ROW EXECUTE FUNCTION check_booking_conflict();
CREATE TRIGGER trg_enforce_booking_capacity BEFORE INSERT OR UPDATE OF bookable_id, starts_at, ends_at, quantity, status ON public.bookings FOR EACH ROW EXECUTE FUNCTION enforce_booking_capacity();
CREATE TRIGGER trg_enforce_booking_resource_active BEFORE INSERT ON public.bookings FOR EACH ROW EXECUTE FUNCTION enforce_booking_resource_active();
CREATE TRIGGER trg_handle_booking_capacity_release AFTER UPDATE OF status ON public.bookings FOR EACH ROW WHEN (((old.status = ANY (ARRAY['pending'::text, 'confirmed'::text])) AND (new.status = ANY (ARRAY['cancelled'::text, 'expired'::text])))) EXECUTE FUNCTION handle_booking_capacity_release();
CREATE TRIGGER trg_notify_booking_status_change AFTER UPDATE OF status ON public.bookings FOR EACH ROW EXECUTE FUNCTION notify_booking_status_change();
CREATE TRIGGER trg_challenge_participant_accept_creates_match AFTER UPDATE OF status ON public.challenge_participants FOR EACH ROW EXECUTE FUNCTION ensure_challenge_match_on_accept();
CREATE TRIGGER trg_challenge_created_add_creator AFTER INSERT ON public.challenges FOR EACH ROW EXECUTE FUNCTION on_challenge_created_add_creator();
CREATE TRIGGER trg_release_card_stakes_on_cancel AFTER UPDATE OF status ON public.challenges FOR EACH ROW EXECUTE FUNCTION release_card_stakes_on_challenge_cancel();
CREATE TRIGGER trg_protect_listing_privileged BEFORE INSERT OR UPDATE ON public.marketplace_listings FOR EACH ROW EXECUTE FUNCTION protect_listing_privileged();
CREATE TRIGGER trg_protect_seller_profile_privileged BEFORE INSERT OR UPDATE ON public.marketplace_seller_profiles FOR EACH ROW EXECUTE FUNCTION protect_seller_profile_privileged();
CREATE TRIGGER trg_apply_confirmed_match_progression AFTER INSERT OR UPDATE OF status ON public.match_results FOR EACH ROW EXECUTE FUNCTION apply_confirmed_match_progression();
CREATE TRIGGER trg_apply_confirmed_tournament_progression AFTER INSERT OR UPDATE OF status ON public.match_results FOR EACH ROW EXECUTE FUNCTION apply_confirmed_tournament_progression();
CREATE TRIGGER trg_settle_card_stakes AFTER INSERT OR UPDATE ON public.match_results FOR EACH ROW EXECUTE FUNCTION settle_challenge_card_stakes();
CREATE TRIGGER trg_post_paid_booking_to_finance AFTER UPDATE OF status ON public.payment_records FOR EACH ROW EXECUTE FUNCTION post_paid_booking_to_finance();
CREATE TRIGGER trg_post_payment_refund_to_finance_v2 AFTER UPDATE OF status ON public.payment_refunds FOR EACH ROW EXECUTE FUNCTION post_payment_refund_to_finance();
CREATE TRIGGER trg_player_sport_mint_base_card AFTER INSERT OR UPDATE OF relationship ON public.player_sports FOR EACH ROW EXECUTE FUNCTION on_player_sport_mint_base_card();
CREATE TRIGGER trg_protect_profile_system_fields BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION protect_profile_system_fields();
CREATE TRIGGER trg_enforce_provider_service_relationship BEFORE INSERT OR UPDATE OF provider_id, organization_id ON public.provider_services FOR EACH ROW EXECUTE FUNCTION enforce_provider_service_relationship();
CREATE TRIGGER trg_shop_pos_sale_permission BEFORE INSERT ON public.shop_pos_sales FOR EACH ROW EXECUTE FUNCTION enforce_shop_pos_sale_permission();
CREATE TRIGGER trg_shop_return_permission BEFORE INSERT ON public.shop_returns FOR EACH ROW EXECUTE FUNCTION enforce_shop_return_permission();
CREATE TRIGGER trg_validate_tournament_entry_scope BEFORE INSERT OR UPDATE OF tournament_id, category_id ON public.tournament_entries FOR EACH ROW EXECUTE FUNCTION validate_tournament_entry_scope();
CREATE TRIGGER trg_guard_tournament_fixture_status BEFORE UPDATE OF status ON public.tournament_fixtures FOR EACH ROW EXECUTE FUNCTION guard_tournament_fixture_status();
CREATE TRIGGER trg_validate_tournament_fixture_scope BEFORE INSERT OR UPDATE OF tournament_id, category_id, stage_id, group_id, side_a_entry_id, side_b_entry_id, winner_entry_id ON public.tournament_fixtures FOR EACH ROW EXECUTE FUNCTION validate_tournament_fixture_scope();
CREATE TRIGGER trg_guard_tournament_stage_status BEFORE UPDATE OF status ON public.tournament_stages FOR EACH ROW EXECUTE FUNCTION guard_tournament_stage_status();
CREATE TRIGGER trg_validate_tournament_stage_scope BEFORE INSERT OR UPDATE OF tournament_id, category_id ON public.tournament_stages FOR EACH ROW EXECUTE FUNCTION validate_tournament_stage_scope();
CREATE TRIGGER weekly_challenge_participants_updated_at BEFORE UPDATE ON public.weekly_challenge_participants FOR EACH ROW EXECUTE FUNCTION set_weekly_challenge_participant_updated_at();

-- ============================================================================
-- ACTIVAR ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE public.account_security_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_security_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_coach_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_daily_coach_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_evolution_agent_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_evolution_council_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_evolution_evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_evolution_locks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_evolution_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_evolution_outcomes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_evolution_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_evolution_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_memory_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_policy_evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_policy_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_policy_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_recommendation_outcomes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_request_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_usage_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_daily_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.background_job_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_plan_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_usage_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookable_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_availability_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_blackouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_dependencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_finance_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_payment_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_waitlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.card_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.card_delivery_failures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_card_stakes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_share_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_retention_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discovery_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discovery_controls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discovery_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discovery_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dynasty_card_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dynasty_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dynasty_mission_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dynasty_progression_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entity_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entity_sports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_recurring_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intelligence_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.locale_translations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_item_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_listing_analytics_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_listing_delivery_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_listing_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_order_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_order_refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_seller_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_seller_settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderation_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_activity_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_member_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pair_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_security_exceptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_test_assertions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_test_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_progression ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_rivalries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_season_progression ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_sport_streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_sports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_locale_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotion_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_organization_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_service_booking_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rate_limit_hits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rating_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recommendation_candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recommendation_explanations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recommendation_impressions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recommendation_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.relevance_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.relevance_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.search_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.share_event_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.share_event_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shareable_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_inventory_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_inventory_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_inventory_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_inventory_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_location_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_order_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_pos_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_pos_registers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_pos_sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_pos_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_registers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_return_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skill_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skill_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skill_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skill_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_share_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_share_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_share_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sport_rankings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_ticket_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supported_locales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_health_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_entry_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_fixtures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_group_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_prizes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_registration_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_sponsors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_challenge_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_challenge_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.xp_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zz_probe_cards ENABLE ROW LEVEL SECURITY;
-- (spatial_ref_sys no aparece aqui -- la crea solo CREATE EXTENSION postgis, con RLS
-- deshabilitado de fabrica; ese es el hallazgo de riesgo bajo ya registrado en la auditoria.)

-- ============================================================================
-- POLITICAS RLS (316)
-- ============================================================================

CREATE POLICY "security devices own" ON public.account_security_devices AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "security events own" ON public.account_security_events AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "achievements public read" ON public.achievements AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "ai_coach_interactions_owner_insert" ON public.ai_coach_interactions AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "ai_coach_interactions_owner_read" ON public.ai_coach_interactions AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "ai_conversations_owner_all" ON public.ai_conversations AS PERMISSIVE FOR ALL TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "ai_daily_coach_sessions_owner_all" ON public.ai_daily_coach_sessions AS PERMISSIVE FOR ALL TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "ai_evolution_agent_performance_service_only" ON public.ai_evolution_agent_performance AS PERMISSIVE FOR ALL TO public
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_ai_evolution_council_reviews" ON public.ai_evolution_council_reviews AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_ai_evolution_evaluations" ON public.ai_evolution_evaluations AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_ai_evolution_locks" ON public.ai_evolution_locks AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_ai_evolution_memory" ON public.ai_evolution_memory AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_ai_evolution_outcomes" ON public.ai_evolution_outcomes AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_ai_evolution_proposals" ON public.ai_evolution_proposals AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_ai_evolution_runs" ON public.ai_evolution_runs AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "ai_memory_notes_owner_all" ON public.ai_memory_notes AS PERMISSIVE FOR ALL TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "ai_messages_owner_all" ON public.ai_messages AS PERMISSIVE FOR ALL TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "ai_policy_versions_authenticated_read" ON public.ai_policy_versions AS PERMISSIVE FOR SELECT TO authenticated
  USING ((status = ANY (ARRAY['active'::text, 'canary'::text])));
CREATE POLICY "ai_recommendation_outcomes_owner_read" ON public.ai_recommendation_outcomes AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM ai_coach_interactions i
  WHERE ((i.id = ai_recommendation_outcomes.interaction_id) AND (i.profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "ai_request_reservations_service_only" ON public.ai_request_reservations AS PERMISSIVE FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);
CREATE POLICY "ai_usage_events_owner_read" ON public.ai_usage_events AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "analytics metrics owner read" ON public.analytics_daily_metrics AS PERMISSIVE FOR SELECT TO authenticated
  USING (((profile_id = ( SELECT auth.uid() AS uid)) OR (organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (seller_profile_id IN ( SELECT marketplace_seller_profiles.id
   FROM marketplace_seller_profiles
  WHERE (analytics_daily_metrics.profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "analytics events own insert" ON public.analytics_events AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((profile_id = ( SELECT auth.uid() AS uid)) OR (profile_id IS NULL)));
CREATE POLICY "audit logs actor read" ON public.audit_logs AS PERMISSIVE FOR SELECT TO authenticated
  USING (((actor_profile_id = ( SELECT auth.uid() AS uid)) OR (organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "background jobs deny client" ON public.background_job_runs AS PERMISSIVE FOR SELECT TO authenticated
  USING (false);
CREATE POLICY "billing entitlements owner read" ON public.billing_entitlements AS PERMISSIVE FOR SELECT TO authenticated
  USING (((profile_id = ( SELECT auth.uid() AS uid)) OR (organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (seller_profile_id IN ( SELECT marketplace_seller_profiles.id
   FROM marketplace_seller_profiles
  WHERE (billing_entitlements.profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "billing invoices owner read" ON public.billing_invoices AS PERMISSIVE FOR SELECT TO authenticated
  USING (((profile_id = ( SELECT auth.uid() AS uid)) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid)))) OR (seller_profile_id IN ( SELECT sp.id
   FROM marketplace_seller_profiles sp
  WHERE (sp.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "billing plan features public read" ON public.billing_plan_features AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "billing plans public read" ON public.billing_plans AS PERMISSIVE FOR SELECT TO public
  USING ((is_active = true));
CREATE POLICY "billing subscriptions owner read" ON public.billing_subscriptions AS PERMISSIVE FOR SELECT TO authenticated
  USING (((profile_id = ( SELECT auth.uid() AS uid)) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid)))) OR (seller_profile_id IN ( SELECT sp.id
   FROM marketplace_seller_profiles sp
  WHERE (sp.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "billing usage owner read" ON public.billing_usage_events AS PERMISSIVE FOR SELECT TO authenticated
  USING (((profile_id = ( SELECT auth.uid() AS uid)) OR (organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (seller_profile_id IN ( SELECT marketplace_seller_profiles.id
   FROM marketplace_seller_profiles
  WHERE (billing_usage_events.profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "bookables active public read" ON public.bookable_entities AS PERMISSIVE FOR SELECT TO public
  USING (((status = 'active'::text) OR (owner_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "bookables own insert" ON public.bookable_entities AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((owner_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "bookables own update" ON public.bookable_entities AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((owner_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((owner_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "availability owner delete" ON public.booking_availability_rules AS PERMISSIVE FOR DELETE TO authenticated
  USING ((bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "availability owner insert" ON public.booking_availability_rules AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "availability owner read" ON public.booking_availability_rules AS PERMISSIVE FOR SELECT TO public
  USING (((bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid)))) OR (bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.status = 'active'::text)))));
CREATE POLICY "availability owner update" ON public.booking_availability_rules AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid)))))
  WITH CHECK ((bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "blackouts owner manage" ON public.booking_blackouts AS PERMISSIVE FOR ALL TO authenticated
  USING ((bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid)))))
  WITH CHECK ((bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "booking dependencies owner manage" ON public.booking_dependencies AS PERMISSIVE FOR ALL TO authenticated
  USING ((parent_bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid)))))
  WITH CHECK ((parent_bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "bfl read" ON public.booking_finance_links AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM finance_transactions ft
  WHERE ((ft.id = booking_finance_links.finance_transaction_id) AND ((ft.profile_id = ( SELECT auth.uid() AS uid)) OR (ft.organization_id IN ( SELECT organizations.id
           FROM organizations
          WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))))))));
CREATE POLICY "booking groups participant read" ON public.booking_groups AS PERMISSIVE FOR SELECT TO authenticated
  USING ((requested_by = ( SELECT auth.uid() AS uid)));
CREATE POLICY "bpr delete" ON public.booking_payment_records AS PERMISSIVE FOR DELETE TO authenticated
  USING (((provider_id IN ( SELECT provider_profiles.id
   FROM provider_profiles
  WHERE (provider_profiles.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "bpr insert" ON public.booking_payment_records AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((provider_id IN ( SELECT provider_profiles.id
   FROM provider_profiles
  WHERE (provider_profiles.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "bpr read" ON public.booking_payment_records AS PERMISSIVE FOR SELECT TO authenticated
  USING (((provider_id IN ( SELECT provider_profiles.id
   FROM provider_profiles
  WHERE (provider_profiles.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "bpr update" ON public.booking_payment_records AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((provider_id IN ( SELECT provider_profiles.id
   FROM provider_profiles
  WHERE (provider_profiles.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid))))))
  WITH CHECK (((provider_id IN ( SELECT provider_profiles.id
   FROM provider_profiles
  WHERE (provider_profiles.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "booking policies owner delete" ON public.booking_policies AS PERMISSIVE FOR DELETE TO authenticated
  USING ((bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "booking policies owner insert" ON public.booking_policies AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "booking policies owner update" ON public.booking_policies AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid)))))
  WITH CHECK ((bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "booking policies public read" ON public.booking_policies AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "waitlist own cancel" ON public.booking_waitlist AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "waitlist own read" ON public.booking_waitlist AS PERMISSIVE FOR SELECT TO authenticated
  USING (((profile_id = ( SELECT auth.uid() AS uid)) OR (bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "waitlist user insert" ON public.booking_waitlist AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "bookings participant read" ON public.bookings AS PERMISSIVE FOR SELECT TO authenticated
  USING (((booked_by = ( SELECT auth.uid() AS uid)) OR (bookable_id IN ( SELECT be.id
   FROM bookable_entities be
  WHERE (be.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "bookings user insert" ON public.bookings AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (false);
CREATE POLICY "card definitions public read" ON public.card_definitions AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "challenge card stakes participants read" ON public.challenge_card_stakes AS PERMISSIVE FOR SELECT TO authenticated
  USING (((profile_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM challenge_participants cp
  WHERE ((cp.challenge_id = challenge_card_stakes.challenge_id) AND (cp.profile_id = ( SELECT auth.uid() AS uid)))))));
CREATE POLICY "invitations participant read" ON public.challenge_invitations AS PERMISSIVE FOR SELECT TO authenticated
  USING (((inviter_id = ( SELECT auth.uid() AS uid)) OR (invitee_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "challenge participants own read" ON public.challenge_participants AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "share links creator read" ON public.challenge_share_links AS PERMISSIVE FOR SELECT TO authenticated
  USING ((created_by = ( SELECT auth.uid() AS uid)));
CREATE POLICY "challenge participant read" ON public.challenges AS PERMISSIVE FOR SELECT TO authenticated
  USING (((creator_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM challenge_participants cp
  WHERE ((cp.challenge_id = challenges.id) AND (cp.profile_id = ( SELECT auth.uid() AS uid)))))));
CREATE POLICY "reports authenticated create" ON public.content_reports AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((reporter_profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "reports own create read" ON public.content_reports AS PERMISSIVE FOR SELECT TO authenticated
  USING ((reporter_profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "conversation messages participant insert" ON public.conversation_messages AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((sender_profile_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM conversation_participants cp
  WHERE ((cp.conversation_id = conversation_messages.conversation_id) AND (cp.profile_id = ( SELECT auth.uid() AS uid)))))));
CREATE POLICY "conversation messages participant read" ON public.conversation_messages AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM conversation_participants cp
  WHERE ((cp.conversation_id = conversation_messages.conversation_id) AND (cp.profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "conversation participants own read" ON public.conversation_participants AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "conversation participant read" ON public.conversations AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM conversation_participants cp
  WHERE ((cp.conversation_id = conversations.id) AND (cp.profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "retention policies deny client" ON public.data_retention_policies AS PERMISSIVE FOR SELECT TO authenticated
  USING (false);
CREATE POLICY "discovery blocks own delete" ON public.discovery_blocks AS PERMISSIVE FOR DELETE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "discovery blocks own insert" ON public.discovery_blocks AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "discovery blocks own read" ON public.discovery_blocks AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "discovery controls own insert" ON public.discovery_controls AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "discovery controls own read" ON public.discovery_controls AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "discovery controls own update" ON public.discovery_controls AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "discovery events own insert" ON public.discovery_events AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "discovery preferences own insert" ON public.discovery_preferences AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "discovery preferences own read" ON public.discovery_preferences AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "discovery preferences own update" ON public.discovery_preferences AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "dynasty card transfers authenticated read" ON public.dynasty_card_transfers AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
CREATE POLICY "dynasty cards authenticated read" ON public.dynasty_cards AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
CREATE POLICY "dynasty_mission_rewards_owner_read" ON public.dynasty_mission_rewards AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM user_missions um
  WHERE ((um.id = dynasty_mission_rewards.user_mission_id) AND (um.profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "dynasty_progression_events_owner_read" ON public.dynasty_progression_events AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "availability public read" ON public.entity_availability AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "entity sports public read" ON public.entity_sports AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "finance accounts organization owner delete" ON public.finance_accounts AS PERMISSIVE FOR DELETE TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance accounts organization owner insert" ON public.finance_accounts AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance accounts organization owner read" ON public.finance_accounts AS PERMISSIVE FOR SELECT TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance accounts organization owner update" ON public.finance_accounts AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))))
  WITH CHECK (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance categories organization owner delete" ON public.finance_categories AS PERMISSIVE FOR DELETE TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance categories organization owner insert" ON public.finance_categories AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance categories organization owner read" ON public.finance_categories AS PERMISSIVE FOR SELECT TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance categories organization owner update" ON public.finance_categories AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))))
  WITH CHECK (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance invoices organization owner delete" ON public.finance_invoices AS PERMISSIVE FOR DELETE TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance invoices organization owner insert" ON public.finance_invoices AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance invoices organization owner read" ON public.finance_invoices AS PERMISSIVE FOR SELECT TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance invoices organization owner update" ON public.finance_invoices AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))))
  WITH CHECK (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance recurring organization owner delete" ON public.finance_recurring_items AS PERMISSIVE FOR DELETE TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance recurring organization owner insert" ON public.finance_recurring_items AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance recurring organization owner read" ON public.finance_recurring_items AS PERMISSIVE FOR SELECT TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance recurring organization owner update" ON public.finance_recurring_items AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))))
  WITH CHECK (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance transactions organization owner delete" ON public.finance_transactions AS PERMISSIVE FOR DELETE TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance transactions organization owner insert" ON public.finance_transactions AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance transactions organization owner read" ON public.finance_transactions AS PERMISSIVE FOR SELECT TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "finance transactions organization owner update" ON public.finance_transactions AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))))
  WITH CHECK (((organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "intelligence signals own read" ON public.intelligence_signals AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "translations public read active locale" ON public.locale_translations AS PERMISSIVE FOR SELECT TO public
  USING ((EXISTS ( SELECT 1
   FROM supported_locales l
  WHERE ((l.code = locale_translations.locale_code) AND (l.is_active = true)))));
CREATE POLICY "deny_all_authenticated_marketplace_item_returns" ON public.marketplace_item_returns AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "marketplace analytics seller read" ON public.marketplace_listing_analytics_daily AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM marketplace_listings ml
  WHERE ((ml.id = marketplace_listing_analytics_daily.listing_id) AND (ml.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "marketplace delivery public read" ON public.marketplace_listing_delivery_options AS PERMISSIVE FOR SELECT TO public
  USING (((is_active = true) OR (EXISTS ( SELECT 1
   FROM marketplace_listings ml
  WHERE ((ml.id = marketplace_listing_delivery_options.listing_id) AND (ml.owner_id = ( SELECT auth.uid() AS uid)))))));
CREATE POLICY "marketplace delivery seller delete" ON public.marketplace_listing_delivery_options AS PERMISSIVE FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM marketplace_listings ml
  WHERE ((ml.id = marketplace_listing_delivery_options.listing_id) AND (ml.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "marketplace delivery seller insert" ON public.marketplace_listing_delivery_options AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM marketplace_listings ml
  WHERE ((ml.id = marketplace_listing_delivery_options.listing_id) AND (ml.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "marketplace delivery seller update" ON public.marketplace_listing_delivery_options AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM marketplace_listings ml
  WHERE ((ml.id = marketplace_listing_delivery_options.listing_id) AND (ml.owner_id = ( SELECT auth.uid() AS uid))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM marketplace_listings ml
  WHERE ((ml.id = marketplace_listing_delivery_options.listing_id) AND (ml.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "marketplace inventory seller manage" ON public.marketplace_listing_inventory AS PERMISSIVE FOR ALL TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM marketplace_listings ml
  WHERE ((ml.id = marketplace_listing_inventory.listing_id) AND (ml.owner_id = ( SELECT auth.uid() AS uid))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM marketplace_listings ml
  WHERE ((ml.id = marketplace_listing_inventory.listing_id) AND (ml.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "marketplace own insert" ON public.marketplace_listings AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((owner_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "marketplace own update" ON public.marketplace_listings AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((owner_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((owner_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "marketplace published read" ON public.marketplace_listings AS PERMISSIVE FOR SELECT TO public
  USING (((status = 'published'::text) OR (owner_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "deny_all_authenticated_marketplace_order_items" ON public.marketplace_order_items AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_marketplace_order_payments" ON public.marketplace_order_payments AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_marketplace_order_refunds" ON public.marketplace_order_refunds AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_marketplace_orders" ON public.marketplace_orders AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "marketplace promotions seller read" ON public.marketplace_promotions AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM marketplace_listings ml
  WHERE ((ml.id = marketplace_promotions.listing_id) AND (ml.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "seller profiles owner delete" ON public.marketplace_seller_profiles AS PERMISSIVE FOR DELETE TO authenticated
  USING ((owner_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "seller profiles owner insert" ON public.marketplace_seller_profiles AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((owner_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "seller profiles owner update" ON public.marketplace_seller_profiles AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((owner_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((owner_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "seller profiles public active read" ON public.marketplace_seller_profiles AS PERMISSIVE FOR SELECT TO public
  USING (((status = 'active'::text) OR (owner_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "deny_all_authenticated_marketplace_seller_settlements" ON public.marketplace_seller_settlements AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "match results public read" ON public.match_results AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "matches challenge participant read" ON public.matches AS PERMISSIVE FOR SELECT TO authenticated
  USING (((challenge_id IS NULL) OR (EXISTS ( SELECT 1
   FROM challenge_participants cp
  WHERE ((cp.challenge_id = matches.challenge_id) AND (cp.profile_id = ( SELECT auth.uid() AS uid)))))));
CREATE POLICY "missions_public_read" ON public.missions AS PERMISSIVE FOR SELECT TO public
  USING ((is_active = true));
CREATE POLICY "deny_all_authenticated_moderation_actions" ON public.moderation_actions AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "notification deliveries own read" ON public.notification_deliveries AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM notifications n
  WHERE ((n.id = notification_deliveries.notification_id) AND (n.profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "notification devices own" ON public.notification_devices AS PERMISSIVE FOR ALL TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "notification preferences own" ON public.notification_preferences AS PERMISSIVE FOR ALL TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "notifications own read" ON public.notifications AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "notifications own update" ON public.notifications AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "organization activities public read" ON public.organization_activities AS PERMISSIVE FOR SELECT TO public
  USING ((is_active = true));
CREATE POLICY "organization activity memberships own read" ON public.organization_activity_memberships AS PERMISSIVE FOR SELECT TO authenticated
  USING ((organization_membership_id IN ( SELECT organization_memberships.id
   FROM organization_memberships
  WHERE (organization_memberships.profile_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "organization locations public read" ON public.organization_locations AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "organization member roles own read" ON public.organization_member_roles AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM organization_memberships om
  WHERE ((om.id = organization_member_roles.membership_id) AND (om.profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "organization memberships own read" ON public.organization_memberships AS PERMISSIVE FOR SELECT TO authenticated
  USING (((profile_id = ( SELECT auth.uid() AS uid)) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "organization memberships owner delete" ON public.organization_memberships AS PERMISSIVE FOR DELETE TO authenticated
  USING ((organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "organization memberships owner insert" ON public.organization_memberships AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "organization memberships owner update" ON public.organization_memberships AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid)))))
  WITH CHECK ((organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "organization permissions read" ON public.organization_permissions AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);
CREATE POLICY "organization resources read" ON public.organization_resources AS PERMISSIVE FOR SELECT TO authenticated
  USING ((has_organization_permission(organization_id, 'manage_resources'::text) OR (EXISTS ( SELECT 1
   FROM organizations o
  WHERE ((o.id = organization_resources.organization_id) AND (o.owner_id = ( SELECT auth.uid() AS uid)))))));
CREATE POLICY "organization role permissions member read" ON public.organization_role_permissions AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM (organization_roles r
     JOIN organization_memberships om ON ((om.organization_id = r.organization_id)))
  WHERE ((r.id = organization_role_permissions.role_id) AND (om.profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "organization roles member read" ON public.organization_roles AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM organization_memberships om
  WHERE ((om.organization_id = organization_roles.organization_id) AND (om.profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "organizations owner insert" ON public.organizations AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((owner_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "organizations owner update" ON public.organizations AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((owner_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((owner_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "organizations public active read" ON public.organizations AS PERMISSIVE FOR SELECT TO public
  USING (((status = 'active'::text) OR (owner_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "pair_profiles_public_select" ON public.pair_profiles AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "partner_preferences_owner" ON public.partner_preferences AS PERMISSIVE FOR ALL TO public
  USING ((( SELECT auth.uid() AS uid) = user_id))
  WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "partner_requests_participant_select" ON public.partner_requests AS PERMISSIVE FOR SELECT TO public
  USING (((( SELECT auth.uid() AS uid) = requester_id) OR (( SELECT auth.uid() AS uid) = recipient_id)));
CREATE POLICY "payment records payer read" ON public.payment_records AS PERMISSIVE FOR SELECT TO authenticated
  USING ((payer_profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "payment refunds payer read" ON public.payment_refunds AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM payment_records p
  WHERE ((p.id = payment_refunds.payment_id) AND (p.payer_profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "platform_admins self read" ON public.platform_admins AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "deny_all_authenticated_platform_security_exceptions" ON public.platform_security_exceptions AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_platform_test_assertions" ON public.platform_test_assertions AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_platform_test_runs" ON public.platform_test_runs AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "player achievements owner read" ON public.player_achievements AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "availability active read" ON public.player_availability AS PERMISSIVE FOR SELECT TO public
  USING (((is_active = true) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "availability own delete" ON public.player_availability AS PERMISSIVE FOR DELETE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "availability own insert" ON public.player_availability AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "availability own update" ON public.player_availability AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "player cards owner read" ON public.player_cards AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "player progression owner read" ON public.player_progression AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "player_progression_public_read" ON public.player_progression AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "rivalries public read" ON public.player_rivalries AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "player_season_progression_owner_read" ON public.player_season_progression AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "player_sport_streaks_owner_read" ON public.player_sport_streaks AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "player_sport_streaks_public_read" ON public.player_sport_streaks AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "player sports own delete" ON public.player_sports AS PERMISSIVE FOR DELETE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "player sports own insert" ON public.player_sports AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "player sports own read" ON public.player_sports AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "player sports own update" ON public.player_sports AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "locale preferences own" ON public.profile_locale_preferences AS PERMISSIVE FOR ALL TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "profile location own insert" ON public.profile_locations AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "profile location own read" ON public.profile_locations AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "profile location own update" ON public.profile_locations AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "profiles discoverable read" ON public.profiles AS PERMISSIVE FOR SELECT TO public
  USING (((is_discoverable = true) OR (id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "profiles own insert" ON public.profiles AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "profiles own update" ON public.profiles AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "promotion events own read" ON public.promotion_events AS PERMISSIVE FOR SELECT TO authenticated
  USING ((promotion_id IN ( SELECT p.id
   FROM (promotions p
     JOIN marketplace_listings l ON ((l.id = p.listing_id)))
  WHERE (l.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "promotions own insert" ON public.promotions AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((listing_id IN ( SELECT marketplace_listings.id
   FROM marketplace_listings
  WHERE (marketplace_listings.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "promotions own read" ON public.promotions AS PERMISSIVE FOR SELECT TO authenticated
  USING ((listing_id IN ( SELECT marketplace_listings.id
   FROM marketplace_listings
  WHERE (marketplace_listings.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "provider availability authenticated read" ON public.provider_availability AS PERMISSIVE FOR SELECT TO authenticated
  USING (((is_available = true) OR (provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "provider availability own delete" ON public.provider_availability AS PERMISSIVE FOR DELETE TO authenticated
  USING ((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "provider availability own insert" ON public.provider_availability AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "provider availability own update" ON public.provider_availability AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))))
  WITH CHECK ((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "provider relationships organization owner delete" ON public.provider_organization_relationships AS PERMISSIVE FOR DELETE TO authenticated
  USING ((organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "provider relationships organization owner insert" ON public.provider_organization_relationships AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "provider relationships organization owner update" ON public.provider_organization_relationships AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid)))))
  WITH CHECK ((organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "provider relationships own read" ON public.provider_organization_relationships AS PERMISSIVE FOR SELECT TO authenticated
  USING (((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "provider profiles own delete" ON public.provider_profiles AS PERMISSIVE FOR DELETE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "provider profiles own insert" ON public.provider_profiles AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "provider profiles own update" ON public.provider_profiles AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "provider profiles public active read" ON public.provider_profiles AS PERMISSIVE FOR SELECT TO public
  USING (((status = 'active'::text) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "psbl delete" ON public.provider_service_booking_links AS PERMISSIVE FOR DELETE TO authenticated
  USING (((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "psbl insert" ON public.provider_service_booking_links AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "psbl read" ON public.provider_service_booking_links AS PERMISSIVE FOR SELECT TO authenticated
  USING (((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "psbl update" ON public.provider_service_booking_links AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid))))))
  WITH CHECK (((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "provider services own delete" ON public.provider_services AS PERMISSIVE FOR DELETE TO authenticated
  USING (((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "provider services own insert" ON public.provider_services AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "provider services own update" ON public.provider_services AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid))))))
  WITH CHECK (((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "provider services public active read" ON public.provider_services AS PERMISSIVE FOR SELECT TO public
  USING (((status = 'active'::text) OR (provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "provider students private access" ON public.provider_students AS PERMISSIVE FOR SELECT TO authenticated
  USING (((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))) OR (profile_id = ( SELECT auth.uid() AS uid)) OR (organization_id IN ( SELECT o.id
   FROM organizations o
  WHERE (o.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "provider students provider delete" ON public.provider_students AS PERMISSIVE FOR DELETE TO authenticated
  USING ((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "provider students provider insert" ON public.provider_students AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "provider students provider update" ON public.provider_students AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))))
  WITH CHECK ((provider_id IN ( SELECT pp.id
   FROM provider_profiles pp
  WHERE (pp.profile_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "rating_history_owner_read" ON public.rating_history AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "recommendation candidates public read" ON public.recommendation_candidates AS PERMISSIVE FOR SELECT TO public
  USING (((visibility = 'public'::text) AND (status = 'active'::text)));
CREATE POLICY "recommendation explanations own read" ON public.recommendation_explanations AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "recommendation impressions own" ON public.recommendation_impressions AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "recommendation impressions own insert" ON public.recommendation_impressions AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((profile_id = ( SELECT auth.uid() AS uid)) OR (profile_id IS NULL)));
CREATE POLICY "recommendation preferences own" ON public.recommendation_preferences AS PERMISSIVE FOR ALL TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "referral code own insert" ON public.referral_codes AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "referral code own update" ON public.referral_codes AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "referral codes public read active" ON public.referral_codes AS PERMISSIVE FOR SELECT TO public
  USING (((is_active = true) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "referrals own read" ON public.referrals AS PERMISSIVE FOR SELECT TO authenticated
  USING (((referrer_id = ( SELECT auth.uid() AS uid)) OR (referred_profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "feedback own insert" ON public.relevance_feedback AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "feedback own read" ON public.relevance_feedback AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "relevance rules active read" ON public.relevance_rules AS PERMISSIVE FOR SELECT TO authenticated
  USING ((is_active = true));
CREATE POLICY "search documents public read" ON public.search_documents AS PERMISSIVE FOR SELECT TO public
  USING (((visibility = 'public'::text) AND (status = 'active'::text)));
CREATE POLICY "seasons_public_read" ON public.seasons AS PERMISSIVE FOR SELECT TO public
  USING ((status = ANY (ARRAY['active'::text, 'completed'::text])));
CREATE POLICY "security events own read" ON public.security_events AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "security rate limits deny client" ON public.security_rate_limits AS PERMISSIVE FOR SELECT TO authenticated
  USING (false);
CREATE POLICY "share actions own read" ON public.share_event_actions AS PERMISSIVE FOR SELECT TO authenticated
  USING ((actor_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "share templates public read" ON public.share_event_templates AS PERMISSIVE FOR SELECT TO public
  USING ((is_active = true));
CREATE POLICY "shareable own insert" ON public.shareable_events AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "shareable own update" ON public.shareable_events AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "shareable public read" ON public.shareable_events AS PERMISSIVE FOR SELECT TO public
  USING (((visibility = 'public'::text) OR (profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "shop cart items own" ON public.shop_cart_items AS PERMISSIVE FOR ALL TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM shop_carts c
  WHERE ((c.id = shop_cart_items.cart_id) AND (c.profile_id = ( SELECT auth.uid() AS uid))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM shop_carts c
  WHERE ((c.id = shop_cart_items.cart_id) AND (c.profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "shop carts own" ON public.shop_carts AS PERMISSIVE FOR ALL TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "shop coupons active read" ON public.shop_coupons AS PERMISSIVE FOR SELECT TO authenticated
  USING (((is_active = true) AND ((starts_at IS NULL) OR (starts_at <= now())) AND ((ends_at IS NULL) OR (ends_at >= now()))));
CREATE POLICY "shop_customers_service_only" ON public.shop_customers AS PERMISSIVE FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);
CREATE POLICY "deny_all_authenticated_shop_inventory_adjustments" ON public.shop_inventory_adjustments AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_shop_inventory_levels" ON public.shop_inventory_levels AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "shop_inventory_movements_service_only" ON public.shop_inventory_movements AS PERMISSIVE FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);
CREATE POLICY "shop inventory reservations own read" ON public.shop_inventory_reservations AS PERMISSIVE FOR SELECT TO public
  USING ((order_id IN ( SELECT shop_orders.id
   FROM shop_orders
  WHERE (shop_orders.profile_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "shop_invoices_service_only" ON public.shop_invoices AS PERMISSIVE FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);
CREATE POLICY "shop_location_inventory_service_only" ON public.shop_location_inventory AS PERMISSIVE FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);
CREATE POLICY "shop_locations_service_only" ON public.shop_locations AS PERMISSIVE FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);
CREATE POLICY "shop order items own read" ON public.shop_order_items AS PERMISSIVE FOR SELECT TO authenticated
  USING ((order_id IN ( SELECT shop_orders.id
   FROM shop_orders
  WHERE (shop_orders.profile_id = ( SELECT auth.uid() AS uid)))));
CREATE POLICY "shop order payments owner read" ON public.shop_order_payments AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM shop_orders o
  WHERE ((o.id = shop_order_payments.order_id) AND (o.profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "shop orders own read" ON public.shop_orders AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "deny_all_authenticated_shop_pos_payments" ON public.shop_pos_payments AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_shop_pos_registers" ON public.shop_pos_registers AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_shop_pos_sale_items" ON public.shop_pos_sale_items AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "shop_pos_sales_service_only" ON public.shop_pos_sales AS PERMISSIVE FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);
CREATE POLICY "shop variants public read" ON public.shop_product_variants AS PERMISSIVE FOR SELECT TO public
  USING (((is_active = true) AND (product_id IN ( SELECT shop_products.id
   FROM shop_products
  WHERE (shop_products.status = 'active'::text)))));
CREATE POLICY "shop products public read" ON public.shop_products AS PERMISSIVE FOR SELECT TO public
  USING ((status = 'active'::text));
CREATE POLICY "shop_registers_service_only" ON public.shop_registers AS PERMISSIVE FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);
CREATE POLICY "deny_all_authenticated_shop_return_items" ON public.shop_return_items AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "deny_all_authenticated_shop_returns" ON public.shop_returns AS PERMISSIVE FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);
CREATE POLICY "shop_staff_member_read" ON public.shop_staff AS PERMISSIVE FOR SELECT TO authenticated
  USING (((profile_id = ( SELECT auth.uid() AS uid)) OR has_shop_permission(location_id, 'manage_staff'::text, ( SELECT auth.uid() AS uid))));
CREATE POLICY "skill_challenges_public_select" ON public.skill_challenges AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "skill_challenges_self_insert" ON public.skill_challenges AS PERMISSIVE FOR INSERT TO public
  WITH CHECK ((( SELECT auth.uid() AS uid) = creator_id));
CREATE POLICY "skill_comments_public_select" ON public.skill_comments AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "skill_comments_self_insert" ON public.skill_comments AS PERMISSIVE FOR INSERT TO public
  WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "skill_submissions_public_select" ON public.skill_submissions AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "skill_submissions_self_insert" ON public.skill_submissions AS PERMISSIVE FOR INSERT TO public
  WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "skill_votes_public_select" ON public.skill_votes AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "skill_votes_self_insert" ON public.skill_votes AS PERMISSIVE FOR INSERT TO public
  WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "social comments own delete" ON public.social_comments AS PERMISSIVE FOR DELETE TO authenticated
  USING ((author_profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "social comments own insert" ON public.social_comments AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((author_profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "social comments own update" ON public.social_comments AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((author_profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((author_profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "social comments visible read" ON public.social_comments AS PERMISSIVE FOR SELECT TO public
  USING (((status = 'visible'::text) OR (author_profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "social follows own delete" ON public.social_follows AS PERMISSIVE FOR DELETE TO authenticated
  USING ((follower_profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "social follows own insert" ON public.social_follows AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((follower_profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "social follows own update" ON public.social_follows AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((follower_profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((follower_profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "social follows participant read" ON public.social_follows AS PERMISSIVE FOR SELECT TO authenticated
  USING (((follower_profile_id = ( SELECT auth.uid() AS uid)) OR (followed_profile_id = ( SELECT auth.uid() AS uid))));
CREATE POLICY "social posts own delete" ON public.social_posts AS PERMISSIVE FOR DELETE TO authenticated
  USING ((author_profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "social posts own insert" ON public.social_posts AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((author_profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "social posts own update" ON public.social_posts AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((author_profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((author_profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "social posts read by visibility" ON public.social_posts AS PERMISSIVE FOR SELECT TO public
  USING (((visibility = 'public'::text) OR (author_profile_id = ( SELECT auth.uid() AS uid)) OR ((visibility = 'followers'::text) AND (EXISTS ( SELECT 1
   FROM social_follows sf
  WHERE ((sf.follower_profile_id = ( SELECT auth.uid() AS uid)) AND (sf.followed_profile_id = social_posts.author_profile_id)))))));
CREATE POLICY "social reactions actor read" ON public.social_reactions AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "social reactions own delete" ON public.social_reactions AS PERMISSIVE FOR DELETE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "social reactions own insert" ON public.social_reactions AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "social reactions own update" ON public.social_reactions AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "share actions own create read" ON public.social_share_actions AS PERMISSIVE FOR ALL TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "share cards source owner read" ON public.social_share_cards AS PERMISSIVE FOR SELECT TO authenticated
  USING (((profile_id = ( SELECT auth.uid() AS uid)) OR (profile_id IS NULL)));
CREATE POLICY "social share events own read" ON public.social_share_events AS PERMISSIVE FOR SELECT TO authenticated
  USING ((actor_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "sport_rankings_public_read" ON public.sport_rankings AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "public read active sports" ON public.sports AS PERMISSIVE FOR SELECT TO public
  USING ((is_active = true));
CREATE POLICY "ticket messages participant read" ON public.support_ticket_messages AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM support_tickets t
  WHERE ((t.id = support_ticket_messages.ticket_id) AND (t.requester_profile_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "ticket messages requester create" ON public.support_ticket_messages AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((author_profile_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM support_tickets t
  WHERE ((t.id = support_ticket_messages.ticket_id) AND (t.requester_profile_id = ( SELECT auth.uid() AS uid)))))));
CREATE POLICY "tickets own" ON public.support_tickets AS PERMISSIVE FOR ALL TO authenticated
  USING ((requester_profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((requester_profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "locales public read" ON public.supported_locales AS PERMISSIVE FOR SELECT TO public
  USING ((is_active = true));
CREATE POLICY "health checks deny client" ON public.system_health_checks AS PERMISSIVE FOR SELECT TO authenticated
  USING (false);
CREATE POLICY "tournament categories organizer write" ON public.tournament_categories AS PERMISSIVE FOR ALL TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM tournaments t
  WHERE ((t.id = tournament_categories.tournament_id) AND ((t.organizer_profile_id = auth.uid()) OR ((t.organization_id IS NOT NULL) AND has_organization_permission(t.organization_id, 'manage_tournaments'::text, auth.uid())))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM tournaments t
  WHERE ((t.id = tournament_categories.tournament_id) AND ((t.organizer_profile_id = auth.uid()) OR ((t.organization_id IS NOT NULL) AND has_organization_permission(t.organization_id, 'manage_tournaments'::text, auth.uid())))))));
CREATE POLICY "tournament categories read" ON public.tournament_categories AS PERMISSIVE FOR SELECT TO public
  USING ((EXISTS ( SELECT 1
   FROM tournaments t
  WHERE ((t.id = tournament_categories.tournament_id) AND ((t.visibility = 'public'::text) OR (t.organizer_profile_id = ( SELECT auth.uid() AS uid)) OR (t.organization_id IN ( SELECT o.id
           FROM organizations o
          WHERE (o.owner_id = ( SELECT auth.uid() AS uid)))))))));
CREATE POLICY "tournament checkin participant read" ON public.tournament_checkins AS PERMISSIVE FOR SELECT TO authenticated
  USING (((profile_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM tournament_entries te
  WHERE ((te.id = tournament_checkins.entry_id) AND (te.captain_profile_id = ( SELECT auth.uid() AS uid)))))));
CREATE POLICY "tournament entries public read" ON public.tournament_entries AS PERMISSIVE FOR SELECT TO public
  USING ((EXISTS ( SELECT 1
   FROM tournaments t
  WHERE ((t.id = tournament_entries.tournament_id) AND ((t.visibility = 'public'::text) OR (t.organizer_profile_id = auth.uid()) OR ((t.organization_id IS NOT NULL) AND has_organization_permission(t.organization_id, 'manage_tournaments'::text, auth.uid())))))));
CREATE POLICY "tournament entry own read" ON public.tournament_entries AS PERMISSIVE FOR SELECT TO authenticated
  USING (((captain_profile_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM tournament_entry_members tem
  WHERE ((tem.entry_id = tournament_entries.id) AND (tem.profile_id = ( SELECT auth.uid() AS uid)))))));
CREATE POLICY "tournament entry member own read" ON public.tournament_entry_members AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "tournament entry members public read" ON public.tournament_entry_members AS PERMISSIVE FOR SELECT TO public
  USING ((EXISTS ( SELECT 1
   FROM (tournament_entries te
     JOIN tournaments t ON ((t.id = te.tournament_id)))
  WHERE ((te.id = tournament_entry_members.entry_id) AND ((t.visibility = 'public'::text) OR (t.organizer_profile_id = auth.uid()) OR ((t.organization_id IS NOT NULL) AND has_organization_permission(t.organization_id, 'manage_tournaments'::text, auth.uid())))))));
CREATE POLICY "tournament fixtures organizer write" ON public.tournament_fixtures AS PERMISSIVE FOR ALL TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM tournaments t
  WHERE ((t.id = tournament_fixtures.tournament_id) AND ((t.organizer_profile_id = auth.uid()) OR ((t.organization_id IS NOT NULL) AND has_organization_permission(t.organization_id, 'manage_tournaments'::text, auth.uid())))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM tournaments t
  WHERE ((t.id = tournament_fixtures.tournament_id) AND ((t.organizer_profile_id = auth.uid()) OR ((t.organization_id IS NOT NULL) AND has_organization_permission(t.organization_id, 'manage_tournaments'::text, auth.uid())))))));
CREATE POLICY "tournament fixtures visibility read" ON public.tournament_fixtures AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM tournaments t
  WHERE ((t.id = tournament_fixtures.tournament_id) AND ((t.visibility = 'public'::text) OR (t.organizer_profile_id = ( SELECT auth.uid() AS uid)) OR (t.organization_id IN ( SELECT o.id
           FROM organizations o
          WHERE (o.owner_id = ( SELECT auth.uid() AS uid)))))))));
CREATE POLICY "tournament standings public read" ON public.tournament_group_entries AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "tournament groups organizer write" ON public.tournament_groups AS PERMISSIVE FOR ALL TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM (tournament_stages s
     JOIN tournaments t ON ((t.id = s.tournament_id)))
  WHERE ((s.id = tournament_groups.stage_id) AND ((t.organizer_profile_id = auth.uid()) OR ((t.organization_id IS NOT NULL) AND has_organization_permission(t.organization_id, 'manage_tournaments'::text, auth.uid())))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM (tournament_stages s
     JOIN tournaments t ON ((t.id = s.tournament_id)))
  WHERE ((s.id = tournament_groups.stage_id) AND ((t.organizer_profile_id = auth.uid()) OR ((t.organization_id IS NOT NULL) AND has_organization_permission(t.organization_id, 'manage_tournaments'::text, auth.uid())))))));
CREATE POLICY "tournament groups visibility read" ON public.tournament_groups AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM (tournament_stages s
     JOIN tournaments t ON ((t.id = s.tournament_id)))
  WHERE ((s.id = tournament_groups.stage_id) AND ((t.visibility = 'public'::text) OR (t.organizer_profile_id = ( SELECT auth.uid() AS uid)) OR (t.organization_id IN ( SELECT o.id
           FROM organizations o
          WHERE (o.owner_id = ( SELECT auth.uid() AS uid)))))))));
CREATE POLICY "tournament prizes public read" ON public.tournament_prizes AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "tournament payments entry owner read" ON public.tournament_registration_payments AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM tournament_entries e
  WHERE ((e.id = tournament_registration_payments.entry_id) AND ((e.captain_profile_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
           FROM tournament_entry_members m
          WHERE ((m.entry_id = e.id) AND (m.profile_id = ( SELECT auth.uid() AS uid))))))))));
CREATE POLICY "tournament payments organizer read" ON public.tournament_registration_payments AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM (tournament_entries te
     JOIN tournaments t ON ((t.id = te.tournament_id)))
  WHERE ((te.id = tournament_registration_payments.entry_id) AND ((t.organizer_profile_id = auth.uid()) OR ((t.organization_id IS NOT NULL) AND has_organization_permission(t.organization_id, 'manage_tournaments'::text, auth.uid())))))));
CREATE POLICY "tournament sponsors public read" ON public.tournament_sponsors AS PERMISSIVE FOR SELECT TO public
  USING (true);
CREATE POLICY "tournament stages organizer write" ON public.tournament_stages AS PERMISSIVE FOR ALL TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM tournaments t
  WHERE ((t.id = tournament_stages.tournament_id) AND ((t.organizer_profile_id = auth.uid()) OR ((t.organization_id IS NOT NULL) AND has_organization_permission(t.organization_id, 'manage_tournaments'::text, auth.uid())))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM tournaments t
  WHERE ((t.id = tournament_stages.tournament_id) AND ((t.organizer_profile_id = auth.uid()) OR ((t.organization_id IS NOT NULL) AND has_organization_permission(t.organization_id, 'manage_tournaments'::text, auth.uid())))))));
CREATE POLICY "tournament stages visibility read" ON public.tournament_stages AS PERMISSIVE FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM tournaments t
  WHERE ((t.id = tournament_stages.tournament_id) AND ((t.visibility = 'public'::text) OR (t.organizer_profile_id = ( SELECT auth.uid() AS uid)) OR (t.organization_id IN ( SELECT o.id
           FROM organizations o
          WHERE (o.owner_id = ( SELECT auth.uid() AS uid)))))))));
CREATE POLICY "public tournaments read" ON public.tournaments AS PERMISSIVE FOR SELECT TO public
  USING (((visibility = 'public'::text) OR (organizer_profile_id = ( SELECT auth.uid() AS uid)) OR (organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "tournament organizer delete" ON public.tournaments AS PERMISSIVE FOR DELETE TO authenticated
  USING (((organizer_profile_id = ( SELECT auth.uid() AS uid)) OR (organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "tournament organizer insert" ON public.tournaments AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (((organizer_profile_id = ( SELECT auth.uid() AS uid)) OR (organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "tournament organizer update" ON public.tournaments AS PERMISSIVE FOR UPDATE TO authenticated
  USING (((organizer_profile_id = ( SELECT auth.uid() AS uid)) OR (organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid))))))
  WITH CHECK (((organizer_profile_id = ( SELECT auth.uid() AS uid)) OR (organization_id IN ( SELECT organizations.id
   FROM organizations
  WHERE (organizations.owner_id = ( SELECT auth.uid() AS uid))))));
CREATE POLICY "blocks own" ON public.user_blocks AS PERMISSIVE FOR ALL TO authenticated
  USING ((blocker_profile_id = ( SELECT auth.uid() AS uid)))
  WITH CHECK ((blocker_profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "user_missions_owner_read" ON public.user_missions AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));
CREATE POLICY "weekly_challenge_participants_service_role" ON public.weekly_challenge_participants AS PERMISSIVE FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);
CREATE POLICY "weekly_challenge_submissions_service_role" ON public.weekly_challenge_submissions AS PERMISSIVE FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);
CREATE POLICY "xp events owner read" ON public.xp_events AS PERMISSIVE FOR SELECT TO authenticated
  USING ((profile_id = ( SELECT auth.uid() AS uid)));

-- ============================================================================
-- PERMISOS (anon / authenticated) -- restricciones mas alla de RLS
-- ============================================================================

-- Supabase ya otorga por defecto, en cualquier proyecto nuevo, DELETE/INSERT/REFERENCES/
-- SELECT/TRIGGER/TRUNCATE/UPDATE sobre cada tabla nueva a los roles anon/authenticated/
-- service_role. En produccion, para TODAS las tablas de la app se revoco REFERENCES y
-- TRUNCATE (nadie desde la app necesita crear llaves foraneas apuntando a estas tablas, ni
-- vaciar una tabla completa), y para las tablas mas sensibles (pagos, auditoria, IA interna,
-- caja/POS) se revoco ademas INSERT/UPDATE/DELETE o el acceso completo -- la proteccion real
-- la hacen las politicas RLS de arriba, pero esto es una segunda capa (defensa en profundidad).
-- service_role no se toca: mantiene siempre el acceso completo por defecto.

REVOKE ALL ON TABLE public.account_security_devices FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.account_security_devices TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.account_security_devices TO authenticated;

REVOKE ALL ON TABLE public.account_security_events FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.account_security_events TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.account_security_events TO authenticated;

REVOKE ALL ON TABLE public.achievements FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.achievements TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.achievements TO authenticated;

REVOKE ALL ON TABLE public.ai_coach_interactions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_coach_interactions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_coach_interactions TO authenticated;

REVOKE ALL ON TABLE public.ai_conversations FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_conversations TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_conversations TO authenticated;

REVOKE ALL ON TABLE public.ai_daily_coach_sessions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_daily_coach_sessions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_daily_coach_sessions TO authenticated;

REVOKE ALL ON TABLE public.ai_evolution_agent_performance FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_evolution_agent_performance TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_evolution_agent_performance TO authenticated;

REVOKE ALL ON TABLE public.ai_evolution_council_reviews FROM anon, authenticated;

REVOKE ALL ON TABLE public.ai_evolution_evaluations FROM anon, authenticated;

REVOKE ALL ON TABLE public.ai_evolution_locks FROM anon, authenticated;

REVOKE ALL ON TABLE public.ai_evolution_memory FROM anon, authenticated;

REVOKE ALL ON TABLE public.ai_evolution_outcomes FROM anon, authenticated;

REVOKE ALL ON TABLE public.ai_evolution_proposals FROM anon, authenticated;

REVOKE ALL ON TABLE public.ai_evolution_runs FROM anon, authenticated;

REVOKE ALL ON TABLE public.ai_memory_notes FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_memory_notes TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_memory_notes TO authenticated;

REVOKE ALL ON TABLE public.ai_messages FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_messages TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_messages TO authenticated;

REVOKE ALL ON TABLE public.ai_policy_evaluations FROM anon, authenticated;

REVOKE ALL ON TABLE public.ai_policy_events FROM anon, authenticated;

REVOKE ALL ON TABLE public.ai_policy_versions FROM anon, authenticated;
GRANT SELECT ON TABLE public.ai_policy_versions TO authenticated;

REVOKE ALL ON TABLE public.ai_recommendation_outcomes FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_recommendation_outcomes TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_recommendation_outcomes TO authenticated;

REVOKE ALL ON TABLE public.ai_request_reservations FROM anon, authenticated;

REVOKE ALL ON TABLE public.ai_usage_events FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.ai_usage_events TO anon;
GRANT SELECT ON TABLE public.ai_usage_events TO authenticated;

REVOKE ALL ON TABLE public.analytics_daily_metrics FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.analytics_daily_metrics TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.analytics_daily_metrics TO authenticated;

REVOKE ALL ON TABLE public.analytics_events FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.analytics_events TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.analytics_events TO authenticated;

REVOKE ALL ON TABLE public.audit_logs FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.audit_logs TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.audit_logs TO authenticated;

REVOKE ALL ON TABLE public.background_job_runs FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.background_job_runs TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.background_job_runs TO authenticated;

REVOKE ALL ON TABLE public.billing_entitlements FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.billing_entitlements TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.billing_entitlements TO authenticated;

REVOKE ALL ON TABLE public.billing_invoices FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.billing_invoices TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.billing_invoices TO authenticated;

REVOKE ALL ON TABLE public.billing_plan_features FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.billing_plan_features TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.billing_plan_features TO authenticated;

REVOKE ALL ON TABLE public.billing_plans FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.billing_plans TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.billing_plans TO authenticated;

REVOKE ALL ON TABLE public.billing_subscriptions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.billing_subscriptions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.billing_subscriptions TO authenticated;

REVOKE ALL ON TABLE public.billing_usage_events FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.billing_usage_events TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.billing_usage_events TO authenticated;

REVOKE ALL ON TABLE public.bookable_entities FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.bookable_entities TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.bookable_entities TO authenticated;

REVOKE ALL ON TABLE public.booking_availability_rules FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_availability_rules TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_availability_rules TO authenticated;

REVOKE ALL ON TABLE public.booking_blackouts FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_blackouts TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_blackouts TO authenticated;

REVOKE ALL ON TABLE public.booking_dependencies FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_dependencies TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_dependencies TO authenticated;

REVOKE ALL ON TABLE public.booking_finance_links FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_finance_links TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_finance_links TO authenticated;

REVOKE ALL ON TABLE public.booking_groups FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_groups TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_groups TO authenticated;

REVOKE ALL ON TABLE public.booking_payment_records FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_payment_records TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_payment_records TO authenticated;

REVOKE ALL ON TABLE public.booking_policies FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_policies TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_policies TO authenticated;

REVOKE ALL ON TABLE public.booking_waitlist FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_waitlist TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.booking_waitlist TO authenticated;

REVOKE ALL ON TABLE public.bookings FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.bookings TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.bookings TO authenticated;

REVOKE ALL ON TABLE public.card_definitions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.card_definitions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.card_definitions TO authenticated;

REVOKE ALL ON TABLE public.challenge_card_stakes FROM anon, authenticated;
GRANT SELECT ON TABLE public.challenge_card_stakes TO authenticated;

REVOKE ALL ON TABLE public.challenge_invitations FROM anon, authenticated;
GRANT SELECT ON TABLE public.challenge_invitations TO anon;
GRANT SELECT ON TABLE public.challenge_invitations TO authenticated;

REVOKE ALL ON TABLE public.challenge_participants FROM anon, authenticated;
GRANT SELECT ON TABLE public.challenge_participants TO anon;
GRANT SELECT ON TABLE public.challenge_participants TO authenticated;

REVOKE ALL ON TABLE public.challenge_share_links FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.challenge_share_links TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.challenge_share_links TO authenticated;

REVOKE ALL ON TABLE public.challenges FROM anon, authenticated;
GRANT SELECT ON TABLE public.challenges TO anon;
GRANT SELECT ON TABLE public.challenges TO authenticated;

REVOKE ALL ON TABLE public.content_reports FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.content_reports TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.content_reports TO authenticated;

REVOKE ALL ON TABLE public.conversation_messages FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.conversation_messages TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.conversation_messages TO authenticated;

REVOKE ALL ON TABLE public.conversation_participants FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.conversation_participants TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.conversation_participants TO authenticated;

REVOKE ALL ON TABLE public.conversations FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.conversations TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.conversations TO authenticated;

REVOKE ALL ON TABLE public.data_retention_policies FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.data_retention_policies TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.data_retention_policies TO authenticated;

REVOKE ALL ON TABLE public.discovery_blocks FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.discovery_blocks TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.discovery_blocks TO authenticated;

REVOKE ALL ON TABLE public.discovery_controls FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.discovery_controls TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.discovery_controls TO authenticated;

REVOKE ALL ON TABLE public.discovery_events FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.discovery_events TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.discovery_events TO authenticated;

REVOKE ALL ON TABLE public.discovery_preferences FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.discovery_preferences TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.discovery_preferences TO authenticated;

REVOKE ALL ON TABLE public.dynasty_card_transfers FROM anon, authenticated;
GRANT SELECT ON TABLE public.dynasty_card_transfers TO authenticated;

REVOKE ALL ON TABLE public.dynasty_cards FROM anon, authenticated;
GRANT SELECT ON TABLE public.dynasty_cards TO authenticated;

REVOKE ALL ON TABLE public.dynasty_mission_rewards FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.dynasty_mission_rewards TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.dynasty_mission_rewards TO authenticated;

REVOKE ALL ON TABLE public.dynasty_progression_events FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.dynasty_progression_events TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.dynasty_progression_events TO authenticated;

REVOKE ALL ON TABLE public.entity_availability FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.entity_availability TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.entity_availability TO authenticated;

REVOKE ALL ON TABLE public.entity_sports FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.entity_sports TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.entity_sports TO authenticated;

REVOKE ALL ON TABLE public.finance_accounts FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.finance_accounts TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.finance_accounts TO authenticated;

REVOKE ALL ON TABLE public.finance_categories FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.finance_categories TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.finance_categories TO authenticated;

REVOKE ALL ON TABLE public.finance_invoices FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.finance_invoices TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.finance_invoices TO authenticated;

REVOKE ALL ON TABLE public.finance_recurring_items FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.finance_recurring_items TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.finance_recurring_items TO authenticated;

REVOKE ALL ON TABLE public.finance_transactions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.finance_transactions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.finance_transactions TO authenticated;

REVOKE ALL ON TABLE public.intelligence_signals FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.intelligence_signals TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.intelligence_signals TO authenticated;

REVOKE ALL ON TABLE public.locale_translations FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.locale_translations TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.locale_translations TO authenticated;

REVOKE ALL ON TABLE public.marketplace_item_returns FROM anon, authenticated;

REVOKE ALL ON TABLE public.marketplace_listing_analytics_daily FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.marketplace_listing_analytics_daily TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.marketplace_listing_analytics_daily TO authenticated;

REVOKE ALL ON TABLE public.marketplace_listing_delivery_options FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.marketplace_listing_delivery_options TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.marketplace_listing_delivery_options TO authenticated;

REVOKE ALL ON TABLE public.marketplace_listing_inventory FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.marketplace_listing_inventory TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.marketplace_listing_inventory TO authenticated;

REVOKE ALL ON TABLE public.marketplace_listings FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.marketplace_listings TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.marketplace_listings TO authenticated;

REVOKE ALL ON TABLE public.marketplace_order_items FROM anon, authenticated;

REVOKE ALL ON TABLE public.marketplace_order_payments FROM anon, authenticated;

REVOKE ALL ON TABLE public.marketplace_order_refunds FROM anon, authenticated;

REVOKE ALL ON TABLE public.marketplace_orders FROM anon, authenticated;

REVOKE ALL ON TABLE public.marketplace_promotions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.marketplace_promotions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.marketplace_promotions TO authenticated;

REVOKE ALL ON TABLE public.marketplace_seller_profiles FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.marketplace_seller_profiles TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.marketplace_seller_profiles TO authenticated;

REVOKE ALL ON TABLE public.marketplace_seller_settlements FROM anon, authenticated;

REVOKE ALL ON TABLE public.match_results FROM anon, authenticated;
GRANT SELECT ON TABLE public.match_results TO anon;
GRANT SELECT ON TABLE public.match_results TO authenticated;

REVOKE ALL ON TABLE public.matches FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.matches TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.matches TO authenticated;

REVOKE ALL ON TABLE public.missions FROM anon, authenticated;
GRANT SELECT ON TABLE public.missions TO anon;
GRANT SELECT ON TABLE public.missions TO authenticated;

REVOKE ALL ON TABLE public.moderation_actions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.moderation_actions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.moderation_actions TO authenticated;

REVOKE ALL ON TABLE public.notification_deliveries FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.notification_deliveries TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.notification_deliveries TO authenticated;

REVOKE ALL ON TABLE public.notification_devices FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.notification_devices TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.notification_devices TO authenticated;

REVOKE ALL ON TABLE public.notification_preferences FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.notification_preferences TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.notification_preferences TO authenticated;

REVOKE ALL ON TABLE public.notifications FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.notifications TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.notifications TO authenticated;

REVOKE ALL ON TABLE public.organization_activities FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_activities TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_activities TO authenticated;

REVOKE ALL ON TABLE public.organization_activity_memberships FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_activity_memberships TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_activity_memberships TO authenticated;

REVOKE ALL ON TABLE public.organization_locations FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_locations TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_locations TO authenticated;

REVOKE ALL ON TABLE public.organization_member_roles FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_member_roles TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_member_roles TO authenticated;

REVOKE ALL ON TABLE public.organization_memberships FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_memberships TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_memberships TO authenticated;

REVOKE ALL ON TABLE public.organization_permissions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_permissions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_permissions TO authenticated;

REVOKE ALL ON TABLE public.organization_resources FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_resources TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_resources TO authenticated;

REVOKE ALL ON TABLE public.organization_role_permissions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_role_permissions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_role_permissions TO authenticated;

REVOKE ALL ON TABLE public.organization_roles FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_roles TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organization_roles TO authenticated;

REVOKE ALL ON TABLE public.organizations FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organizations TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.organizations TO authenticated;

REVOKE ALL ON TABLE public.pair_profiles FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.pair_profiles TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.pair_profiles TO authenticated;

REVOKE ALL ON TABLE public.partner_preferences FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.partner_preferences TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.partner_preferences TO authenticated;

REVOKE ALL ON TABLE public.partner_requests FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.partner_requests TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.partner_requests TO authenticated;

REVOKE ALL ON TABLE public.payment_records FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.payment_records TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.payment_records TO authenticated;

REVOKE ALL ON TABLE public.payment_refunds FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.payment_refunds TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.payment_refunds TO authenticated;

REVOKE ALL ON TABLE public.platform_admins FROM anon, authenticated;
GRANT SELECT ON TABLE public.platform_admins TO authenticated;

REVOKE ALL ON TABLE public.platform_security_exceptions FROM anon, authenticated;

REVOKE ALL ON TABLE public.platform_test_assertions FROM anon, authenticated;

REVOKE ALL ON TABLE public.platform_test_runs FROM anon, authenticated;

REVOKE ALL ON TABLE public.player_achievements FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_achievements TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_achievements TO authenticated;

REVOKE ALL ON TABLE public.player_availability FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_availability TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_availability TO authenticated;

REVOKE ALL ON TABLE public.player_cards FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_cards TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_cards TO authenticated;

REVOKE ALL ON TABLE public.player_progression FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_progression TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_progression TO authenticated;

REVOKE ALL ON TABLE public.player_rivalries FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_rivalries TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_rivalries TO authenticated;

REVOKE ALL ON TABLE public.player_season_progression FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_season_progression TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_season_progression TO authenticated;

REVOKE ALL ON TABLE public.player_sport_streaks FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_sport_streaks TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_sport_streaks TO authenticated;

REVOKE ALL ON TABLE public.player_sports FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_sports TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.player_sports TO authenticated;

REVOKE ALL ON TABLE public.profile_locale_preferences FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.profile_locale_preferences TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.profile_locale_preferences TO authenticated;

REVOKE ALL ON TABLE public.profile_locations FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.profile_locations TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.profile_locations TO authenticated;

REVOKE ALL ON TABLE public.profiles FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.profiles TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.profiles TO authenticated;

REVOKE ALL ON TABLE public.promotion_events FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.promotion_events TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.promotion_events TO authenticated;

REVOKE ALL ON TABLE public.promotions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.promotions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.promotions TO authenticated;

REVOKE ALL ON TABLE public.provider_availability FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.provider_availability TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.provider_availability TO authenticated;

REVOKE ALL ON TABLE public.provider_organization_relationships FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.provider_organization_relationships TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.provider_organization_relationships TO authenticated;

REVOKE ALL ON TABLE public.provider_profiles FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.provider_profiles TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.provider_profiles TO authenticated;

REVOKE ALL ON TABLE public.provider_service_booking_links FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.provider_service_booking_links TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.provider_service_booking_links TO authenticated;

REVOKE ALL ON TABLE public.provider_services FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.provider_services TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.provider_services TO authenticated;

REVOKE ALL ON TABLE public.provider_students FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.provider_students TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.provider_students TO authenticated;

REVOKE ALL ON TABLE public.rating_history FROM anon, authenticated;
GRANT SELECT ON TABLE public.rating_history TO anon;
GRANT SELECT ON TABLE public.rating_history TO authenticated;

REVOKE ALL ON TABLE public.recommendation_candidates FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.recommendation_candidates TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.recommendation_candidates TO authenticated;

REVOKE ALL ON TABLE public.recommendation_explanations FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.recommendation_explanations TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.recommendation_explanations TO authenticated;

REVOKE ALL ON TABLE public.recommendation_impressions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.recommendation_impressions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.recommendation_impressions TO authenticated;

REVOKE ALL ON TABLE public.recommendation_preferences FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.recommendation_preferences TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.recommendation_preferences TO authenticated;

REVOKE ALL ON TABLE public.referral_codes FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.referral_codes TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.referral_codes TO authenticated;

REVOKE ALL ON TABLE public.referrals FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.referrals TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.referrals TO authenticated;

REVOKE ALL ON TABLE public.relevance_feedback FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.relevance_feedback TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.relevance_feedback TO authenticated;

REVOKE ALL ON TABLE public.relevance_rules FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.relevance_rules TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.relevance_rules TO authenticated;

REVOKE ALL ON TABLE public.search_documents FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.search_documents TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.search_documents TO authenticated;

REVOKE ALL ON TABLE public.seasons FROM anon, authenticated;
GRANT SELECT ON TABLE public.seasons TO anon;
GRANT SELECT ON TABLE public.seasons TO authenticated;

REVOKE ALL ON TABLE public.security_events FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.security_events TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.security_events TO authenticated;

REVOKE ALL ON TABLE public.security_rate_limits FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.security_rate_limits TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.security_rate_limits TO authenticated;

REVOKE ALL ON TABLE public.share_event_actions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.share_event_actions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.share_event_actions TO authenticated;

REVOKE ALL ON TABLE public.share_event_templates FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.share_event_templates TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.share_event_templates TO authenticated;

REVOKE ALL ON TABLE public.shareable_events FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shareable_events TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shareable_events TO authenticated;

REVOKE ALL ON TABLE public.shop_cart_items FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_cart_items TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_cart_items TO authenticated;

REVOKE ALL ON TABLE public.shop_carts FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_carts TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_carts TO authenticated;

REVOKE ALL ON TABLE public.shop_coupons FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_coupons TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_coupons TO authenticated;

REVOKE ALL ON TABLE public.shop_customers FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_customers TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_customers TO authenticated;

REVOKE ALL ON TABLE public.shop_inventory_adjustments FROM anon, authenticated;

REVOKE ALL ON TABLE public.shop_inventory_levels FROM anon, authenticated;

REVOKE ALL ON TABLE public.shop_inventory_movements FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_inventory_movements TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_inventory_movements TO authenticated;

REVOKE ALL ON TABLE public.shop_inventory_reservations FROM anon, authenticated;

REVOKE ALL ON TABLE public.shop_invoices FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_invoices TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_invoices TO authenticated;

REVOKE ALL ON TABLE public.shop_location_inventory FROM anon, authenticated;

REVOKE ALL ON TABLE public.shop_locations FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_locations TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_locations TO authenticated;

REVOKE ALL ON TABLE public.shop_order_items FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_order_items TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_order_items TO authenticated;

REVOKE ALL ON TABLE public.shop_order_payments FROM anon, authenticated;
GRANT SELECT ON TABLE public.shop_order_payments TO authenticated;

REVOKE ALL ON TABLE public.shop_orders FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_orders TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_orders TO authenticated;

REVOKE ALL ON TABLE public.shop_pos_payments FROM anon, authenticated;

REVOKE ALL ON TABLE public.shop_pos_registers FROM anon, authenticated;

REVOKE ALL ON TABLE public.shop_pos_sale_items FROM anon, authenticated;

REVOKE ALL ON TABLE public.shop_pos_sales FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_pos_sales TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_pos_sales TO authenticated;

REVOKE ALL ON TABLE public.shop_product_variants FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_product_variants TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_product_variants TO authenticated;

REVOKE ALL ON TABLE public.shop_products FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_products TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_products TO authenticated;

REVOKE ALL ON TABLE public.shop_registers FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_registers TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_registers TO authenticated;

REVOKE ALL ON TABLE public.shop_return_items FROM anon, authenticated;

REVOKE ALL ON TABLE public.shop_returns FROM anon, authenticated;

REVOKE ALL ON TABLE public.shop_staff FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_staff TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.shop_staff TO authenticated;

REVOKE ALL ON TABLE public.skill_challenges FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.skill_challenges TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.skill_challenges TO authenticated;

REVOKE ALL ON TABLE public.skill_comments FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.skill_comments TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.skill_comments TO authenticated;

REVOKE ALL ON TABLE public.skill_submissions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.skill_submissions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.skill_submissions TO authenticated;

REVOKE ALL ON TABLE public.skill_votes FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.skill_votes TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.skill_votes TO authenticated;

REVOKE ALL ON TABLE public.social_comments FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.social_comments TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.social_comments TO authenticated;

REVOKE ALL ON TABLE public.social_follows FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.social_follows TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.social_follows TO authenticated;

REVOKE ALL ON TABLE public.social_posts FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.social_posts TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.social_posts TO authenticated;

REVOKE ALL ON TABLE public.social_reactions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.social_reactions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.social_reactions TO authenticated;

REVOKE ALL ON TABLE public.social_share_actions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.social_share_actions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.social_share_actions TO authenticated;

REVOKE ALL ON TABLE public.social_share_cards FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.social_share_cards TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.social_share_cards TO authenticated;

REVOKE ALL ON TABLE public.social_share_events FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.social_share_events TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.social_share_events TO authenticated;

REVOKE ALL ON TABLE public.sport_rankings FROM anon, authenticated;
GRANT SELECT ON TABLE public.sport_rankings TO anon;
GRANT SELECT ON TABLE public.sport_rankings TO authenticated;

REVOKE ALL ON TABLE public.sports FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.sports TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.sports TO authenticated;

REVOKE ALL ON TABLE public.support_ticket_messages FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.support_ticket_messages TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.support_ticket_messages TO authenticated;

REVOKE ALL ON TABLE public.support_tickets FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.support_tickets TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.support_tickets TO authenticated;

REVOKE ALL ON TABLE public.supported_locales FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.supported_locales TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.supported_locales TO authenticated;

REVOKE ALL ON TABLE public.system_health_checks FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.system_health_checks TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.system_health_checks TO authenticated;

REVOKE ALL ON TABLE public.tournament_categories FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_categories TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_categories TO authenticated;

REVOKE ALL ON TABLE public.tournament_checkins FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_checkins TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_checkins TO authenticated;

REVOKE ALL ON TABLE public.tournament_entries FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_entries TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_entries TO authenticated;

REVOKE ALL ON TABLE public.tournament_entry_members FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_entry_members TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_entry_members TO authenticated;

REVOKE ALL ON TABLE public.tournament_fixtures FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_fixtures TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_fixtures TO authenticated;

REVOKE ALL ON TABLE public.tournament_group_entries FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_group_entries TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_group_entries TO authenticated;

REVOKE ALL ON TABLE public.tournament_groups FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_groups TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_groups TO authenticated;

REVOKE ALL ON TABLE public.tournament_prizes FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_prizes TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_prizes TO authenticated;

REVOKE ALL ON TABLE public.tournament_registration_payments FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_registration_payments TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_registration_payments TO authenticated;

REVOKE ALL ON TABLE public.tournament_sponsors FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_sponsors TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_sponsors TO authenticated;

REVOKE ALL ON TABLE public.tournament_stages FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_stages TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournament_stages TO authenticated;

REVOKE ALL ON TABLE public.tournaments FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournaments TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.tournaments TO authenticated;

REVOKE ALL ON TABLE public.user_blocks FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.user_blocks TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.user_blocks TO authenticated;

REVOKE ALL ON TABLE public.user_missions FROM anon, authenticated;
GRANT SELECT ON TABLE public.user_missions TO anon;
GRANT SELECT ON TABLE public.user_missions TO authenticated;

REVOKE ALL ON TABLE public.weekly_challenge_participants FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.weekly_challenge_participants TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.weekly_challenge_participants TO authenticated;

REVOKE ALL ON TABLE public.weekly_challenge_submissions FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.weekly_challenge_submissions TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.weekly_challenge_submissions TO authenticated;

REVOKE ALL ON TABLE public.xp_events FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.xp_events TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.xp_events TO authenticated;

REVOKE ALL ON TABLE public.zz_probe_cards FROM anon, authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.zz_probe_cards TO anon;
GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE public.zz_probe_cards TO authenticated;
