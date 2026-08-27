
-- Dynasty AI Core v2
-- Non-destructive reference migration for repository parity.
-- The live project already contains this model; review migration history before reapplying.

create table if not exists ai_conversations (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  mode text not null check (mode = any(array['coach','fitness','club','coach_business','tournament','commerce'])),
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references ai_conversations(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  role text not null check (role = any(array['user','assistant','system'])),
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists ai_memory_notes (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  scope text not null,
  note_key text not null,
  note_value jsonb not null,
  confidence numeric check (confidence >= 0 and confidence <= 1),
  source_message_id uuid references ai_messages(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(profile_id, scope, note_key)
);

create table if not exists ai_daily_coach_sessions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  session_date date not null default current_date,
  status text not null default 'planned',
  plan jsonb not null default '{}'::jsonb,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  unique(profile_id, session_date)
);

create table if not exists ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  mode text not null,
  provider text,
  model text,
  input_tokens integer,
  output_tokens integer,
  estimated_cost numeric,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table ai_conversations enable row level security;
alter table ai_messages enable row level security;
alter table ai_memory_notes enable row level security;
alter table ai_daily_coach_sessions enable row level security;
alter table ai_usage_events enable row level security;
