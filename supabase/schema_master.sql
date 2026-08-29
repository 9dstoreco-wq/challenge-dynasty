-- CHALLENGE DYNASTY — MASTER SUPABASE SCHEMA
-- One-shot schema for a multi-sport competitive social network.
-- Run this file on a fresh Supabase project.

create extension if not exists "pgcrypto";

-- =========================
-- ENUMS
-- =========================
do $$ begin create type challenge_status as enum ('PENDING','ACCEPTED','REJECTED','COMPLETED'); exception when duplicate_object then null; end $$;
do $$ begin create type match_type as enum ('DIRECT','INSTANT'); exception when duplicate_object then null; end $$;
do $$ begin create type post_type as enum ('USER_POST','AUTO_MATCH_RESULT','SKILL_RESULT','RANKING_UPDATE'); exception when duplicate_object then null; end $$;
do $$ begin create type skill_challenge_status as enum ('OPEN','SUBMITTED','VOTING','COMPLETED'); exception when duplicate_object then null; end $$;
do $$ begin create type skill_difficulty as enum ('BEGINNER','INTERMEDIATE','ADVANCED','PRO','ELITE'); exception when duplicate_object then null; end $$;

-- =========================
-- SPORTS
-- =========================
create table if not exists sports (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  icon text,
  color text,
  team_size integer not null default 1 check (team_size > 0),
  scoring_type text not null default 'POINTS',
  created_at timestamptz not null default now()
);

insert into sports(name,slug,icon,color,team_size,scoring_type) values
('Pádel','padel','🎾','#00F0FF',2,'SETS'),
('Tenis','tennis','🎾','#00E676',1,'SETS'),
('Fútbol','football','⚽','#FFD700',11,'GOALS'),
('Baloncesto','basketball','🏀','#FF8A00',5,'POINTS'),
('Voleibol','volleyball','🏐','#FF3D00',6,'SETS'),
('Running','running','🏃','#C084FC',1,'TIME'),
('Ciclismo','cycling','🚴','#22D3EE',1,'TIME'),
('Natación','swimming','🏊','#60A5FA',1,'TIME'),
('Boxeo','boxing','🥊','#F43F5E',1,'ROUNDS'),
('Tenis de mesa','table-tennis','🏓','#A3E635',1,'SETS'),
('Golf','golf','⛳','#84CC16',1,'STROKES')
on conflict (slug) do nothing;

-- =========================
-- CLUBS / PROFILES
-- =========================
create table if not exists clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text not null,
  address text,
  logo_url text,
  created_at timestamptz not null default now()
);

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  full_name text not null,
  avatar_url text,
  ranking_position integer not null default 999999,
  country_rank integer not null default 999999,
  city_rank integer not null default 999999,
  ranking_points integer not null default 1000,
  wins integer not null default 0,
  losses integer not null default 0,
  streak integer not null default 0,
  club_id uuid references clubs(id) on delete set null,
  city text,
  country text not null default 'CO',
  skill_points integer not null default 0,
  reputation_score integer not null default 100 check (reputation_score between 0 and 100),
  created_at timestamptz not null default now()
);

create table if not exists profile_sports (
  profile_id uuid not null references profiles(id) on delete cascade,
  sport_id uuid not null references sports(id) on delete cascade,
  skill_level text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  primary key(profile_id,sport_id)
);

create unique index if not exists profiles_username_lower_unique on profiles(lower(username));

-- =========================
-- CHALLENGES / MATCHES
-- =========================
create table if not exists challenges (
  id uuid primary key default gen_random_uuid(),
  challenger_id uuid not null references profiles(id) on delete cascade,
  challenged_id uuid not null references profiles(id) on delete cascade,
  sport_id uuid not null references sports(id) on delete restrict,
  status challenge_status not null default 'PENDING',
  match_date timestamptz not null,
  club_id uuid references clubs(id) on delete set null,
  match_type match_type not null default 'DIRECT',
  points integer not null default 100 check(points > 0 and points <= 5000),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  check(challenger_id <> challenged_id)
);

create table if not exists sport_challenges (
  id uuid primary key default gen_random_uuid(),
  sport_id uuid not null references sports(id) on delete cascade,
  challenge_id uuid not null unique references challenges(id) on delete cascade,
  format text,
  team_size integer not null default 1 check(team_size > 0),
  created_at timestamptz not null default now()
);

create table if not exists matches (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid unique not null references challenges(id) on delete cascade,
  score_set1 text,
  score_set2 text,
  score_set3 text,
  result_data jsonb not null default '{}'::jsonb,
  winner_id uuid not null references profiles(id),
  loser_id uuid not null references profiles(id),
  confirmed_by_winner boolean not null default false,
  confirmed_by_loser boolean not null default false,
  validated_at timestamptz,
  auto_confirmed boolean not null default false,
  created_at timestamptz not null default now(),
  check(winner_id <> loser_id)
);

-- =========================
-- SOCIAL
-- =========================
create table if not exists posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  type post_type not null default 'USER_POST',
  title text,
  content text,
  match_id uuid references matches(id) on delete set null,
  likes_count integer not null default 0,
  comments_count integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  content text not null check(length(trim(content)) > 0),
  created_at timestamptz not null default now()
);

create table if not exists follows (
  follower_id uuid not null references profiles(id) on delete cascade,
  following_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(follower_id,following_id),
  check(follower_id <> following_id)
);

create table if not exists post_likes (
  post_id uuid not null references posts(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(post_id,user_id)
);

create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  actor_id uuid references profiles(id) on delete set null,
  type text not null,
  entity_id uuid,
  message text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

-- =========================
-- RANKING / SEASONS / MISSIONS
-- =========================
create table if not exists sport_rankings (
  id uuid primary key default gen_random_uuid(),
  sport_id uuid not null references sports(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  ranking_position integer,
  rating integer not null default 1000,
  wins integer not null default 0,
  losses integer not null default 0,
  streak integer not null default 0,
  season_points integer not null default 0,
  updated_at timestamptz not null default now(),
  unique(sport_id,profile_id)
);

create table if not exists seasons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sport_id uuid references sports(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  is_active boolean not null default false,
  check(ends_at > starts_at)
);

create table if not exists missions (
  id uuid primary key default gen_random_uuid(),
  season_id uuid references seasons(id) on delete cascade,
  sport_id uuid references sports(id) on delete cascade,
  code text unique not null,
  name text not null,
  description text not null,
  points integer not null default 50 check(points >= 0),
  target integer not null default 1 check(target > 0),
  active boolean not null default true
);

create table if not exists user_missions (
  user_id uuid not null references profiles(id) on delete cascade,
  mission_id uuid not null references missions(id) on delete cascade,
  progress integer not null default 0,
  completed_at timestamptz,
  primary key(user_id,mission_id)
);

create table if not exists rewards (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  badge_key text unique,
  season_id uuid references seasons(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- =========================
-- SKILL / TRICK CHALLENGES
-- =========================
create table if not exists skill_challenges (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references profiles(id) on delete cascade,
  sport_id uuid not null references sports(id) on delete cascade,
  title text not null,
  description text,
  category text not null,
  difficulty skill_difficulty not null default 'INTERMEDIATE',
  target_votes integer not null default 100 check(target_votes > 0),
  points integer not null default 100 check(points >= 0),
  status skill_challenge_status not null default 'OPEN',
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists skill_submissions (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references skill_challenges(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  video_url text not null,
  caption text,
  votes integer not null default 0,
  skill_points_awarded integer not null default 0,
  created_at timestamptz not null default now(),
  unique(challenge_id,user_id)
);

create table if not exists skill_votes (
  submission_id uuid not null references skill_submissions(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  value integer not null default 1 check(value between 1 and 5),
  created_at timestamptz not null default now(),
  primary key(submission_id,user_id)
);

create table if not exists skill_comments (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references skill_submissions(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  content text not null check(length(trim(content)) > 0),
  created_at timestamptz not null default now()
);

create table if not exists sport_skill_challenges (
  id uuid primary key default gen_random_uuid(),
  sport_id uuid not null references sports(id) on delete cascade,
  title text not null,
  category text,
  difficulty text,
  points integer not null default 100,
  created_at timestamptz not null default now()
);

-- =========================
-- PARTNERS / DOUBLES
-- =========================
create table if not exists partner_preferences (
  user_id uuid not null references profiles(id) on delete cascade,
  sport_id uuid not null references sports(id) on delete cascade,
  preferred_level text,
  max_distance_km numeric(5,2) not null default 10 check(max_distance_km > 0),
  availability text,
  notes text,
  updated_at timestamptz not null default now(),
  primary key(user_id,sport_id)
);

create table if not exists partner_requests (
  id uuid primary key default gen_random_uuid(),
  sport_id uuid not null references sports(id) on delete cascade,
  requester_id uuid not null references profiles(id) on delete cascade,
  recipient_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'PENDING' check(status in ('PENDING','ACCEPTED','REJECTED','CANCELLED')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique(sport_id,requester_id,recipient_id),
  check(requester_id <> recipient_id)
);

create table if not exists pair_profiles (
  id uuid primary key default gen_random_uuid(),
  sport_id uuid not null references sports(id) on delete cascade,
  player_1 uuid not null references profiles(id) on delete cascade,
  player_2 uuid not null references profiles(id) on delete cascade,
  ranking_points integer not null default 1000,
  wins integer not null default 0,
  losses integer not null default 0,
  reputation_score integer not null default 100 check(reputation_score between 0 and 100),
  created_at timestamptz not null default now(),
  check(player_1 <> player_2),
  unique(sport_id,player_1,player_2)
);

create table if not exists doubles_challenges (
  id uuid primary key default gen_random_uuid(),
  sport_id uuid not null references sports(id) on delete cascade,
  team_a_player_1 uuid not null references profiles(id) on delete cascade,
  team_a_player_2 uuid not null references profiles(id) on delete cascade,
  team_b_player_1 uuid not null references profiles(id) on delete cascade,
  team_b_player_2 uuid not null references profiles(id) on delete cascade,
  match_date timestamptz not null,
  club_id uuid references clubs(id) on delete set null,
  status challenge_status not null default 'PENDING',
  points integer not null default 100 check(points > 0 and points <= 5000),
  created_at timestamptz not null default now(),
  check(team_a_player_1 <> team_a_player_2),
  check(team_b_player_1 <> team_b_player_2)
);

-- =========================
-- INDEXES
-- =========================
create index if not exists idx_challenges_status_date on challenges(status,match_date);
create index if not exists idx_challenges_sport on challenges(sport_id,created_at desc);
create index if not exists idx_posts_created on posts(created_at desc);
create index if not exists idx_notifications_user_created on notifications(user_id,created_at desc);
create index if not exists idx_sport_rankings_sport_rank on sport_rankings(sport_id,ranking_position);
create index if not exists idx_skill_challenges_sport_created on skill_challenges(sport_id,created_at desc);
create index if not exists idx_skill_submissions_challenge on skill_submissions(challenge_id,created_at desc);

-- =========================
-- RLS
-- =========================
alter table sports enable row level security;
alter table clubs enable row level security;
alter table profiles enable row level security;
alter table profile_sports enable row level security;
alter table challenges enable row level security;
alter table sport_challenges enable row level security;
alter table matches enable row level security;
alter table posts enable row level security;
alter table comments enable row level security;
alter table follows enable row level security;
alter table post_likes enable row level security;
alter table notifications enable row level security;
alter table sport_rankings enable row level security;
alter table seasons enable row level security;
alter table missions enable row level security;
alter table user_missions enable row level security;
alter table rewards enable row level security;
alter table skill_challenges enable row level security;
alter table skill_submissions enable row level security;
alter table skill_votes enable row level security;
alter table skill_comments enable row level security;
alter table sport_skill_challenges enable row level security;
alter table partner_preferences enable row level security;
alter table partner_requests enable row level security;
alter table pair_profiles enable row level security;
alter table doubles_challenges enable row level security;

-- Public read / self write policies. State changes with security impact happen through RPCs.
drop policy if exists sports_public_select on sports;
drop policy if exists clubs_public_select on clubs;
drop policy if exists profiles_public_select on profiles;
drop policy if exists profile_sports_public_select on profile_sports;
drop policy if exists profile_sports_self_write on profile_sports;
drop policy if exists challenges_public_select on challenges;
drop policy if exists sport_challenges_public_select on sport_challenges;
drop policy if exists matches_public_select on matches;
drop policy if exists posts_public_select on posts;
drop policy if exists posts_self_insert on posts;
drop policy if exists comments_public_select on comments;
drop policy if exists comments_self_insert on comments;
drop policy if exists follows_public_select on follows;
drop policy if exists follows_self_insert on follows;
drop policy if exists follows_self_delete on follows;
drop policy if exists post_likes_public_select on post_likes;
drop policy if exists post_likes_self_insert on post_likes;
drop policy if exists post_likes_self_delete on post_likes;
drop policy if exists notifications_self_select on notifications;
drop policy if exists sport_rankings_public_select on sport_rankings;
drop policy if exists seasons_public_select on seasons;
drop policy if exists missions_public_select on missions;
drop policy if exists user_missions_self_select on user_missions;
drop policy if exists rewards_public_select on rewards;
drop policy if exists skill_challenges_public_select on skill_challenges;
drop policy if exists skill_challenges_self_insert on skill_challenges;
drop policy if exists skill_submissions_public_select on skill_submissions;
drop policy if exists skill_submissions_self_insert on skill_submissions;
drop policy if exists skill_votes_public_select on skill_votes;
drop policy if exists skill_votes_self_insert on skill_votes;
drop policy if exists skill_comments_public_select on skill_comments;
drop policy if exists skill_comments_self_insert on skill_comments;
drop policy if exists sport_skill_challenges_public_select on sport_skill_challenges;
drop policy if exists partner_preferences_public_select on partner_preferences;
drop policy if exists partner_preferences_self_write on partner_preferences;
drop policy if exists partner_requests_participant_select on partner_requests;
drop policy if exists pair_profiles_public_select on pair_profiles;
drop policy if exists doubles_challenges_public_select on doubles_challenges;
create policy sports_public_select on sports for select using(true);
create policy clubs_public_select on clubs for select using(true);
create policy profiles_public_select on profiles for select using(true);
create policy profile_sports_public_select on profile_sports for select using(true);
create policy profile_sports_self_write on profile_sports for all using(auth.uid()=profile_id) with check(auth.uid()=profile_id);
create policy challenges_public_select on challenges for select using(true);
create policy sport_challenges_public_select on sport_challenges for select using(true);
create policy matches_public_select on matches for select using(true);
create policy posts_public_select on posts for select using(true);
create policy posts_self_insert on posts for insert with check(auth.uid()=user_id);
create policy comments_public_select on comments for select using(true);
create policy comments_self_insert on comments for insert with check(auth.uid()=user_id);
create policy follows_public_select on follows for select using(true);
create policy follows_self_insert on follows for insert with check(auth.uid()=follower_id);
create policy follows_self_delete on follows for delete using(auth.uid()=follower_id);
create policy post_likes_public_select on post_likes for select using(true);
create policy post_likes_self_insert on post_likes for insert with check(auth.uid()=user_id);
create policy post_likes_self_delete on post_likes for delete using(auth.uid()=user_id);
create policy notifications_self_select on notifications for select using(auth.uid()=user_id);
create policy sport_rankings_public_select on sport_rankings for select using(true);
create policy seasons_public_select on seasons for select using(true);
create policy missions_public_select on missions for select using(true);
create policy user_missions_self_select on user_missions for select using(auth.uid()=user_id);
create policy rewards_public_select on rewards for select using(true);
create policy skill_challenges_public_select on skill_challenges for select using(true);
create policy skill_challenges_self_insert on skill_challenges for insert with check(auth.uid()=creator_id);
create policy skill_submissions_public_select on skill_submissions for select using(true);
create policy skill_submissions_self_insert on skill_submissions for insert with check(auth.uid()=user_id);
create policy skill_votes_public_select on skill_votes for select using(true);
create policy skill_votes_self_insert on skill_votes for insert with check(auth.uid()=user_id);
create policy skill_comments_public_select on skill_comments for select using(true);
create policy skill_comments_self_insert on skill_comments for insert with check(auth.uid()=user_id);
create policy sport_skill_challenges_public_select on sport_skill_challenges for select using(true);
create policy partner_preferences_public_select on partner_preferences for select using(true);
create policy partner_preferences_self_write on partner_preferences for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy partner_requests_participant_select on partner_requests for select using(auth.uid()=requester_id or auth.uid()=recipient_id);
create policy pair_profiles_public_select on pair_profiles for select using(true);
create policy doubles_challenges_public_select on doubles_challenges for select using(true);

-- =========================
-- HELPERS / TRIGGERS
-- =========================
create or replace function public.ensure_primary_sport()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.is_primary then
    update profile_sports set is_primary=false where profile_id=new.profile_id and sport_id<>new.sport_id;
  end if;
  return new;
end $$;

drop trigger if exists profile_sports_primary_guard on profile_sports;
create trigger profile_sports_primary_guard before insert or update on profile_sports for each row execute function public.ensure_primary_sport();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
declare base_username text; candidate text; suffix integer:=0;
begin
  base_username := lower(regexp_replace(coalesce(new.raw_user_meta_data->>'username', split_part(coalesce(new.email,''),'@',1), 'player'),'[^a-zA-Z0-9_]+','','g'));
  base_username := left(case when base_username='' then 'player' else base_username end, 24);
  candidate := base_username;
  while exists(select 1 from profiles where username=candidate) loop
    suffix := suffix + 1;
    candidate := left(base_username, greatest(1,24-length(suffix::text)-1)) || '_' || suffix;
  end loop;
  insert into profiles(id,username,full_name) values(new.id,candidate,coalesce(new.raw_user_meta_data->>'full_name','Jugador'));
  return new;
end $$;

drop trigger if exists on_auth_user_created_challenge on auth.users;
create trigger on_auth_user_created_challenge after insert on auth.users for each row execute function public.handle_new_user();

-- =========================
-- CHALLENGE RPCs
-- =========================
create or replace function public.update_profile(
  p_full_name text default null,
  p_username text default null,
  p_avatar_url text default null,
  p_city text default null,
  p_country text default null,
  p_club_id uuid default null
)
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  update profiles
  set full_name=coalesce(nullif(trim(p_full_name),''),full_name),
      username=coalesce(nullif(lower(regexp_replace(trim(p_username),'[^a-zA-Z0-9_]+','','g')),''),username),
      avatar_url=coalesce(p_avatar_url,avatar_url),
      city=coalesce(p_city,city),
      country=coalesce(p_country,country),
      club_id=coalesce(p_club_id,club_id)
  where id=auth.uid();
  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
end $$;

create or replace function public.create_challenge(
  p_challenged_id uuid,
  p_sport_id uuid,
  p_match_date timestamptz,
  p_club_id uuid default null,
  p_match_type match_type default 'DIRECT',
  p_points integer default 100
)
returns uuid language plpgsql security definer set search_path=public as $$
declare new_id uuid; team_size_value integer;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if auth.uid()=p_challenged_id then raise exception 'SELF_CHALLENGE_NOT_ALLOWED'; end if;
  if not exists(select 1 from profiles where id=p_challenged_id) then raise exception 'PLAYER_NOT_FOUND'; end if;
  select team_size into team_size_value from sports where id=p_sport_id;
  if team_size_value is null then raise exception 'SPORT_NOT_FOUND'; end if;
  if not exists(select 1 from profile_sports where profile_id=p_challenged_id and sport_id=p_sport_id) then raise exception 'PLAYER_NOT_IN_SPORT'; end if;
  if not exists(select 1 from profile_sports where profile_id=auth.uid() and sport_id=p_sport_id) then raise exception 'SPORT_NOT_CONFIGURED'; end if;
  if p_club_id is not null and not exists(select 1 from clubs where id=p_club_id) then raise exception 'CLUB_NOT_FOUND'; end if;
  if p_match_date <= now() then raise exception 'MATCH_DATE_MUST_BE_FUTURE'; end if;
  if p_match_date > now()+interval '90 days' then raise exception 'MATCH_DATE_TOO_FAR'; end if;
  if exists(
    select 1 from challenges
    where sport_id=p_sport_id
      and status in ('PENDING','ACCEPTED')
      and match_date >= now()
      and ((challenger_id=auth.uid() and challenged_id=p_challenged_id) or (challenger_id=p_challenged_id and challenged_id=auth.uid()))
  ) then raise exception 'ACTIVE_CHALLENGE_EXISTS'; end if;
  insert into challenges(challenger_id,challenged_id,sport_id,match_date,club_id,match_type,points,expires_at)
  values(auth.uid(),p_challenged_id,p_sport_id,p_match_date,p_club_id,p_match_type,greatest(1,least(p_points,5000)),least(p_match_date,now()+interval '24 hours'))
  returning id into new_id;
  insert into sport_challenges(sport_id,challenge_id,format,team_size) values(p_sport_id,new_id,null,team_size_value);
  insert into notifications(user_id,actor_id,type,entity_id,message)
  values(p_challenged_id,auth.uid(),'CHALLENGE_RECEIVED',new_id,'Te han enviado un nuevo reto.');
  return new_id;
end $$;

create or replace function public.respond_to_challenge(p_challenge_id uuid,p_response challenge_status)
returns void language plpgsql security definer set search_path=public as $$
declare c challenges;
begin
  select * into c from challenges where id=p_challenge_id for update;
  if not found then raise exception 'CHALLENGE_NOT_FOUND'; end if;
  if auth.uid()<>c.challenged_id then raise exception 'ONLY_CHALLENGED_USER_CAN_RESPOND'; end if;
  if c.status<>'PENDING' then raise exception 'CHALLENGE_NOT_PENDING'; end if;
  if c.expires_at is not null and c.expires_at<now() then raise exception 'CHALLENGE_EXPIRED'; end if;
  if p_response not in ('ACCEPTED','REJECTED') then raise exception 'INVALID_RESPONSE'; end if;
  update challenges set status=p_response where id=p_challenge_id;
  insert into notifications(user_id,actor_id,type,entity_id,message)
  values(c.challenger_id,auth.uid(),'CHALLENGE_RESPONSE',p_challenge_id,case when p_response='ACCEPTED' then 'Tu reto fue aceptado.' else 'Tu reto fue rechazado.' end);
end $$;

create or replace function public.submit_match_result(
  p_challenge_id uuid,p_score_set1 text,p_score_set2 text,p_score_set3 text,p_winner_id uuid,p_result_data jsonb default '{}'::jsonb
)
returns uuid language plpgsql security definer set search_path=public as $$
declare c challenges; m_id uuid; loser uuid;
begin
  select * into c from challenges where id=p_challenge_id for update;
  if not found then raise exception 'CHALLENGE_NOT_FOUND'; end if;
  if auth.uid()<>c.challenger_id and auth.uid()<>c.challenged_id then raise exception 'NOT_PARTICIPANT'; end if;
  if c.status<>'ACCEPTED' then raise exception 'CHALLENGE_NOT_ACCEPTED'; end if;
  if now() < c.match_date - interval '2 hours' then raise exception 'MATCH_NOT_READY'; end if;
  if p_winner_id not in (c.challenger_id,c.challenged_id) then raise exception 'INVALID_WINNER'; end if;
  if exists(select 1 from matches where challenge_id=p_challenge_id and validated_at is not null) then raise exception 'MATCH_ALREADY_VALIDATED'; end if;
  if exists(select 1 from matches where challenge_id=p_challenge_id and (confirmed_by_winner or confirmed_by_loser)) then raise exception 'MATCH_ALREADY_CONFIRMED'; end if;
  if coalesce(trim(p_score_set1),'')='' and coalesce(trim(p_score_set2),'')='' and p_result_data='{}'::jsonb then raise exception 'RESULT_REQUIRED'; end if;
  if coalesce(trim(p_score_set1),'')<>'' and trim(p_score_set1) !~ '^[0-9]{1,2}[-:][0-9]{1,2}$' then raise exception 'INVALID_SET_1'; end if;
  if coalesce(trim(p_score_set2),'')<>'' and trim(p_score_set2) !~ '^[0-9]{1,2}[-:][0-9]{1,2}$' then raise exception 'INVALID_SET_2'; end if;
  if coalesce(trim(p_score_set3),'')<>'' and trim(p_score_set3) !~ '^[0-9]{1,2}[-:][0-9]{1,2}$' then raise exception 'INVALID_SET_3'; end if;
  loser:=case when p_winner_id=c.challenger_id then c.challenged_id else c.challenger_id end;
  insert into matches(challenge_id,score_set1,score_set2,score_set3,result_data,winner_id,loser_id,confirmed_by_winner,confirmed_by_loser)
  values(p_challenge_id,nullif(p_score_set1,''),nullif(p_score_set2,''),nullif(p_score_set3,''),coalesce(p_result_data,'{}'::jsonb),p_winner_id,loser,false,false)
  on conflict(challenge_id) do update set score_set1=excluded.score_set1,score_set2=excluded.score_set2,score_set3=excluded.score_set3,result_data=excluded.result_data,winner_id=excluded.winner_id,loser_id=excluded.loser_id,confirmed_by_winner=false,confirmed_by_loser=false,validated_at=null,auto_confirmed=false
  returning id into m_id;
  return m_id;
end $$;

create or replace function public.confirm_match(p_match_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare m matches;
begin
  select * into m from matches where id=p_match_id for update;
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  if auth.uid()=m.winner_id then update matches set confirmed_by_winner=true where id=p_match_id;
  elsif auth.uid()=m.loser_id then update matches set confirmed_by_loser=true where id=p_match_id;
  else raise exception 'NOT_PARTICIPANT'; end if;
  perform public.validate_match_if_confirmed(p_match_id);
end $$;

create or replace function public.validate_match_if_confirmed(p_match_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare m matches; c challenges; delta integer:=32; sid uuid;
begin
  select * into m from matches where id=p_match_id for update;
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  if m.confirmed_by_winner and m.confirmed_by_loser and m.validated_at is null then
    select * into c from challenges where id=m.challenge_id for update;
    sid:=c.sport_id;
    update matches set validated_at=now() where id=p_match_id;
    insert into sport_rankings(sport_id,profile_id) values(sid,m.winner_id),(sid,m.loser_id) on conflict(sport_id,profile_id) do nothing;
    update sport_rankings set rating=rating+delta,wins=wins+1,streak=streak+1,season_points=season_points+delta,updated_at=now() where sport_id=sid and profile_id=m.winner_id;
    update sport_rankings set rating=greatest(0,rating-delta),losses=losses+1,streak=0,season_points=greatest(0,season_points-delta),updated_at=now() where sport_id=sid and profile_id=m.loser_id;
    with ranked as (
      select profile_id,row_number() over(order by rating desc,wins desc,updated_at asc) rn from sport_rankings where sport_id=sid
    ) update sport_rankings sr set ranking_position=r.rn where sr.sport_id=sid and sr.profile_id in(select profile_id from ranked);
    update profiles p set wins=p.wins+1,streak=p.streak+1 where p.id=m.winner_id;
    update profiles p set losses=p.losses+1,streak=0 where p.id=m.loser_id;
    update challenges set status='COMPLETED' where id=m.challenge_id;
  end if;
end $$;

create or replace function public.auto_confirm_due_matches()
returns integer language plpgsql security definer set search_path=public as $$
declare m matches; processed integer:=0;
begin
  for m in select * from matches where validated_at is null and confirmed_by_winner <> confirmed_by_loser and created_at <= now()-interval '12 hours' loop
    update matches set confirmed_by_winner=true,confirmed_by_loser=true,auto_confirmed=true where id=m.id;
    perform public.validate_match_if_confirmed(m.id);
    processed:=processed+1;
  end loop;
  return processed;
end $$;

-- =========================
-- AUTO POSTS / SOCIAL COUNTERS
-- =========================
create or replace function public.publish_validated_match_post()
returns trigger language plpgsql security definer set search_path=public as $$
declare w_name text; l_name text; msg text;
begin
  if new.validated_at is not null and (old.validated_at is null or old.validated_at is distinct from new.validated_at) then
    select full_name into w_name from profiles where id=new.winner_id;
    select full_name into l_name from profiles where id=new.loser_id;
    msg:=coalesce(w_name,'Ganador')||' venció a '||coalesce(l_name,'Rival')||' '||coalesce(new.score_set1,'')||case when new.score_set2 is not null then ' / '||new.score_set2 else '' end||case when new.score_set3 is not null then ' / '||new.score_set3 else '' end;
    insert into posts(user_id,type,title,content,match_id)
    select new.winner_id,'AUTO_MATCH_RESULT','RESULTADO OFICIAL',msg,new.id
    where not exists(select 1 from posts where match_id=new.id and type='AUTO_MATCH_RESULT');
  end if;
  return new;
end $$;

drop trigger if exists trg_publish_validated_match_post on matches;
create trigger trg_publish_validated_match_post after update of validated_at on matches for each row execute function public.publish_validated_match_post();

create or replace function public.increment_comment_count()
returns trigger language plpgsql security definer set search_path=public as $$
begin update posts set comments_count=comments_count+1 where id=new.post_id; return new; end $$;
drop trigger if exists trg_increment_comment_count on comments;
create trigger trg_increment_comment_count after insert on comments for each row execute function public.increment_comment_count();

create or replace function public.increment_like_count()
returns trigger language plpgsql security definer set search_path=public as $$
begin update posts set likes_count=likes_count+1 where id=new.post_id; return new; end $$;
drop trigger if exists trg_increment_like_count on post_likes;
create trigger trg_increment_like_count after insert on post_likes for each row execute function public.increment_like_count();

create or replace function public.decrement_like_count()
returns trigger language plpgsql security definer set search_path=public as $$
begin update posts set likes_count=greatest(0,likes_count-1) where id=old.post_id; return old; end $$;
drop trigger if exists trg_decrement_like_count on post_likes;
create trigger trg_decrement_like_count after delete on post_likes for each row execute function public.decrement_like_count();

-- =========================
-- PARTNER RPC
-- =========================

-- =========================
-- MATCHMAKING / DISCOVERY RPCs
-- =========================
create or replace function public.find_best_challenge_opponents(
  p_sport_id uuid,
  p_limit integer default 12
)
returns table(
  profile_id uuid,
  username text,
  full_name text,
  city text,
  country text,
  ranking_position integer,
  ranking_points integer,
  wins integer,
  losses integer,
  streak integer,
  distance_score integer,
  fit_score integer
) language sql security definer set search_path=public as $$
  with me as (
    select p.id, p.city, p.country,
           coalesce(sr.rating, p.ranking_points, 1000) as my_rating
    from profiles p
    left join sport_rankings sr on sr.profile_id=p.id and sr.sport_id=p_sport_id
    where p.id=auth.uid()
    limit 1
  ),
  base as (
    select p.id as profile_id,p.username,p.full_name,p.city,p.country,
           coalesce(sr.ranking_position,p.ranking_position,999999) as ranking_position,
           coalesce(sr.season_points,p.ranking_points,1000) as ranking_points,
           coalesce(sr.wins,p.wins,0) as wins,
           coalesce(sr.losses,p.losses,0) as losses,
           coalesce(sr.streak,p.streak,0) as streak,
           case when p.city is not null and m.city is not null and lower(p.city)=lower(m.city) then 100 else 60 end as distance_score,
           greatest(0,100-abs(coalesce(sr.rating,p.ranking_points,1000)-m.my_rating)/8) as rating_score
    from profiles p
    cross join me m
    left join sport_rankings sr on sr.profile_id=p.id and sr.sport_id=p_sport_id
    where p.id<>auth.uid()
      and exists(select 1 from profile_sports ps where ps.profile_id=p.id and ps.sport_id=p_sport_id)
  )
  select profile_id,username,full_name,city,country,ranking_position,ranking_points,wins,losses,streak,
         distance_score,
         least(100,greatest(0,round((rating_score*0.7)+(distance_score*0.3))))::integer as fit_score
  from base
  order by fit_score desc, abs(ranking_position-coalesce((select ranking_position from sport_rankings where profile_id=auth.uid() and sport_id=p_sport_id limit 1),999999)) asc
  limit greatest(1,least(coalesce(p_limit,12),50));
$$;

create or replace function public.request_partner(p_sport_id uuid,p_recipient_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare new_id uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if auth.uid()=p_recipient_id then raise exception 'SELF_PARTNER_NOT_ALLOWED'; end if;
  if not exists(select 1 from sports where id=p_sport_id) then raise exception 'SPORT_NOT_FOUND'; end if;
  if not exists(select 1 from profiles where id=p_recipient_id) then raise exception 'PLAYER_NOT_FOUND'; end if;
  insert into partner_requests(sport_id,requester_id,recipient_id)
  values(p_sport_id,auth.uid(),p_recipient_id)
  on conflict(sport_id,requester_id,recipient_id) do update set status='PENDING',responded_at=null
  returning id into new_id;
  insert into notifications(user_id,actor_id,type,entity_id,message)
  values(p_recipient_id,auth.uid(),'PARTNER_REQUEST',new_id,'Te han enviado una invitación para formar pareja.');
  return new_id;
end $$;


-- =========================
-- SOCIAL / PROFILE RPCs
-- =========================
create or replace function public.respond_to_partner_request(p_request_id uuid,p_response text)
returns void language plpgsql security definer set search_path=public as $$
declare r partner_requests;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into r from partner_requests where id=p_request_id for update;
  if not found then raise exception 'PARTNER_REQUEST_NOT_FOUND'; end if;
  if auth.uid()<>r.recipient_id then raise exception 'ONLY_RECIPIENT_CAN_RESPOND'; end if;
  if r.status<>'PENDING' then raise exception 'PARTNER_REQUEST_NOT_PENDING'; end if;
  if p_response not in ('ACCEPTED','REJECTED') then raise exception 'INVALID_RESPONSE'; end if;
  update partner_requests set status=p_response,responded_at=now() where id=r.id;
  if p_response='ACCEPTED' then
    insert into pair_profiles(sport_id,player_1,player_2) values(r.sport_id,least(r.requester_id,r.recipient_id),greatest(r.requester_id,r.recipient_id)) on conflict(sport_id,player_1,player_2) do nothing;
  end if;
  insert into notifications(user_id,actor_id,type,entity_id,message) values(r.requester_id,auth.uid(),'PARTNER_RESPONSE',r.id,case when p_response='ACCEPTED' then 'Tu invitación de partner fue aceptada.' else 'Tu invitación de partner fue rechazada.' end);
end $$;

create or replace function public.get_profile_rivalries(p_profile_id uuid,p_sport_id uuid default null,p_limit integer default 8)
returns table(opponent_id uuid,opponent_username text,opponent_name text,played integer,wins integer,losses integer,last_played timestamptz)
language sql security definer set search_path=public as $$
  select x.opponent_id, p.username, p.full_name, count(*)::int as played,
         count(*) filter(where x.winner_id=p_profile_id)::int as wins,
         count(*) filter(where x.loser_id=p_profile_id)::int as losses, max(x.validated_at)
  from (
    select case when m.winner_id=p_profile_id then m.loser_id else m.winner_id end opponent_id,m.winner_id,m.loser_id,m.validated_at,c.sport_id
    from matches m join challenges c on c.id=m.challenge_id
    where m.validated_at is not null and (m.winner_id=p_profile_id or m.loser_id=p_profile_id) and (p_sport_id is null or c.sport_id=p_sport_id)
  ) x join profiles p on p.id=x.opponent_id
  group by x.opponent_id,p.username,p.full_name order by played desc,last_played desc limit greatest(1,least(coalesce(p_limit,8),20));
$$;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  update notifications set read_at=coalesce(read_at,now()) where id=p_notification_id and user_id=auth.uid();
  if not found then raise exception 'NOTIFICATION_NOT_FOUND'; end if;
end $$;

create or replace function public.mark_all_notifications_read()
returns integer language plpgsql security definer set search_path=public as $$
declare n integer; begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  update notifications set read_at=now() where user_id=auth.uid() and read_at is null;
  get diagnostics n=row_count; return n;
end $$;

-- =========================
-- SEED CURRENT SEASON / MISSION
-- =========================
insert into seasons(name,sport_id,starts_at,ends_at,is_active)
select 'Temporada 01',s.id,date_trunc('month',now()),date_trunc('month',now())+interval '1 month',true
from sports s where s.slug='padel' and not exists(select 1 from seasons where name='Temporada 01' and sport_id=s.id);


-- NOTE: For automatic 12h confirmations, configure a Supabase Scheduled Function/cron to call:
-- select public.auto_confirm_due_matches();

-- =========================
-- DYNASTY CORE EXPANSION 5
-- =========================
create table if not exists rating_history (
  id uuid primary key default gen_random_uuid(),
  sport_id uuid not null references sports(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  match_id uuid references matches(id) on delete set null,
  rating_before integer not null,
  rating_after integer not null,
  delta integer not null,
  reason text not null,
  created_at timestamptz not null default now()
);

create table if not exists moderation_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles(id) on delete cascade,
  target_user_id uuid references profiles(id) on delete cascade,
  post_id uuid references posts(id) on delete cascade,
  match_id uuid references matches(id) on delete cascade,
  reason text not null,
  details text,
  status text not null default 'OPEN' check(status in ('OPEN','REVIEWING','RESOLVED','DISMISSED')),
  created_at timestamptz not null default now()
);

create table if not exists blocked_profiles (
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id, blocked_id),
  check(blocker_id <> blocked_id)
);

alter table rating_history enable row level security;
alter table moderation_reports enable row level security;
alter table blocked_profiles enable row level security;

drop policy if exists rating_history_public_select on rating_history;
drop policy if exists moderation_reports_self_insert on moderation_reports;
drop policy if exists moderation_reports_self_select on moderation_reports;
drop policy if exists blocked_profiles_self_all on blocked_profiles;
create policy rating_history_public_select on rating_history for select using(true);
create policy moderation_reports_self_insert on moderation_reports for insert with check(auth.uid()=reporter_id);
create policy moderation_reports_self_select on moderation_reports for select using(auth.uid()=reporter_id);
create policy blocked_profiles_self_all on blocked_profiles for all using(auth.uid()=blocker_id) with check(auth.uid()=blocker_id);

create index if not exists idx_rating_history_profile_sport_created on rating_history(profile_id,sport_id,created_at desc);
create index if not exists idx_reports_status_created on moderation_reports(status,created_at desc);
create index if not exists idx_blocks_blocker_blocked on blocked_profiles(blocker_id,blocked_id);

-- Harden challenge creation against blocked opponents and add an explicit cancellation path.
create or replace function public.create_challenge(
  p_challenged_id uuid,
  p_sport_id uuid,
  p_match_date timestamptz,
  p_club_id uuid default null,
  p_match_type match_type default 'DIRECT',
  p_points integer default 100
)
returns uuid language plpgsql security definer set search_path=public as $$
declare new_id uuid; team_size_value integer;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if auth.uid()=p_challenged_id then raise exception 'SELF_CHALLENGE_NOT_ALLOWED'; end if;
  if exists(select 1 from blocked_profiles where blocker_id=auth.uid() and blocked_id=p_challenged_id)
     or exists(select 1 from blocked_profiles where blocker_id=p_challenged_id and blocked_id=auth.uid()) then
    raise exception 'PLAYER_BLOCKED';
  end if;
  if not exists(select 1 from profiles where id=p_challenged_id) then raise exception 'PLAYER_NOT_FOUND'; end if;
  select team_size into team_size_value from sports where id=p_sport_id;
  if team_size_value is null then raise exception 'SPORT_NOT_FOUND'; end if;
  if not exists(select 1 from profile_sports where profile_id=p_challenged_id and sport_id=p_sport_id) then raise exception 'PLAYER_NOT_IN_SPORT'; end if;
  if not exists(select 1 from profile_sports where profile_id=auth.uid() and sport_id=p_sport_id) then raise exception 'SPORT_NOT_CONFIGURED'; end if;
  if p_club_id is not null and not exists(select 1 from clubs where id=p_club_id) then raise exception 'CLUB_NOT_FOUND'; end if;
  if p_match_date <= now() then raise exception 'MATCH_DATE_MUST_BE_FUTURE'; end if;
  if p_match_date > now()+interval '90 days' then raise exception 'MATCH_DATE_TOO_FAR'; end if;
  if exists(
    select 1 from challenges
    where sport_id=p_sport_id
      and status in ('PENDING','ACCEPTED')
      and match_date >= now()
      and ((challenger_id=auth.uid() and challenged_id=p_challenged_id) or (challenger_id=p_challenged_id and challenged_id=auth.uid()))
  ) then raise exception 'ACTIVE_CHALLENGE_EXISTS'; end if;
  insert into challenges(challenger_id,challenged_id,sport_id,match_date,club_id,match_type,points,expires_at)
  values(auth.uid(),p_challenged_id,p_sport_id,p_match_date,p_club_id,p_match_type,greatest(1,least(p_points,5000)),least(p_match_date,now()+interval '24 hours'))
  returning id into new_id;
  insert into sport_challenges(sport_id,challenge_id,format,team_size) values(p_sport_id,new_id,null,team_size_value);
  insert into notifications(user_id,actor_id,type,entity_id,message)
  values(p_challenged_id,auth.uid(),'CHALLENGE_RECEIVED',new_id,'Te han enviado un nuevo reto.');
  return new_id;
end $$;

create or replace function public.cancel_challenge(p_challenge_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare c challenges;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into c from challenges where id=p_challenge_id for update;
  if not found then raise exception 'CHALLENGE_NOT_FOUND'; end if;
  if auth.uid()<>c.challenger_id and auth.uid()<>c.challenged_id then raise exception 'NOT_PARTICIPANT'; end if;
  if c.status not in ('PENDING','ACCEPTED') then raise exception 'CHALLENGE_NOT_CANCELLABLE'; end if;
  update challenges set status='REJECTED', expires_at=now() where id=p_challenge_id;
  insert into notifications(user_id,actor_id,type,entity_id,message)
  select case when auth.uid()=c.challenger_id then c.challenged_id else c.challenger_id end,
         auth.uid(),'CHALLENGE_CANCELLED',p_challenge_id,'El reto fue cancelado.';
end $$;

-- Result integrity: if set scores are supplied, the winner must actually win a majority of reported sets.
create or replace function public.submit_match_result(
  p_challenge_id uuid,p_score_set1 text,p_score_set2 text,p_score_set3 text,p_winner_id uuid,p_result_data jsonb default '{}'::jsonb
)
returns uuid language plpgsql security definer set search_path=public as $$
declare c challenges; m_id uuid; loser uuid; set_wins integer:=0; set_losses integer:=0; a integer; b integer; s text; supplied integer:=0;
begin
  select * into c from challenges where id=p_challenge_id for update;
  if not found then raise exception 'CHALLENGE_NOT_FOUND'; end if;
  if auth.uid()<>c.challenger_id and auth.uid()<>c.challenged_id then raise exception 'NOT_PARTICIPANT'; end if;
  if c.status<>'ACCEPTED' then raise exception 'CHALLENGE_NOT_ACCEPTED'; end if;
  if now() < c.match_date - interval '2 hours' then raise exception 'MATCH_NOT_READY'; end if;
  if p_winner_id not in (c.challenger_id,c.challenged_id) then raise exception 'INVALID_WINNER'; end if;
  if exists(select 1 from matches where challenge_id=p_challenge_id and validated_at is not null) then raise exception 'MATCH_ALREADY_VALIDATED'; end if;
  if exists(select 1 from matches where challenge_id=p_challenge_id and (confirmed_by_winner or confirmed_by_loser)) then raise exception 'MATCH_ALREADY_CONFIRMED'; end if;
  foreach s in array array[p_score_set1,p_score_set2,p_score_set3] loop
    if coalesce(trim(s),'')<>'' then
      supplied:=supplied+1;
      if trim(s) !~ '^[0-9]{1,2}[-:][0-9]{1,2}$' then raise exception 'INVALID_SCORE_FORMAT'; end if;
      a:=split_part(replace(trim(s),':','-'),'-',1)::integer;
      b:=split_part(replace(trim(s),':','-'),'-',2)::integer;
      if a=b then raise exception 'TIED_SET_NOT_ALLOWED'; end if;
      if a>25 or b>25 then raise exception 'SCORE_OUT_OF_RANGE'; end if;
      if a>b then set_wins:=set_wins+1; else set_losses:=set_losses+1; end if;
    end if;
  end loop;
  if supplied=0 and coalesce(p_result_data,'{}'::jsonb)='{}'::jsonb then raise exception 'RESULT_REQUIRED'; end if;
  if supplied>=2 and not ((set_wins>set_losses and p_winner_id=c.challenger_id) or (set_losses>set_wins and p_winner_id=c.challenged_id)) then
    raise exception 'WINNER_DOES_NOT_MATCH_SCORE';
  end if;
  loser:=case when p_winner_id=c.challenger_id then c.challenged_id else c.challenger_id end;
  insert into matches(challenge_id,score_set1,score_set2,score_set3,result_data,winner_id,loser_id,confirmed_by_winner,confirmed_by_loser)
  values(p_challenge_id,nullif(trim(p_score_set1),''),nullif(trim(p_score_set2),''),nullif(trim(p_score_set3),''),coalesce(p_result_data,'{}'::jsonb),p_winner_id,loser,false,false)
  returning id into m_id;
  insert into notifications(user_id,actor_id,type,entity_id,message)
  select case when auth.uid()=c.challenger_id then c.challenged_id else c.challenger_id end,
         auth.uid(),'MATCH_RESULT_SUBMITTED',m_id,'Se ha enviado el resultado del partido para confirmación.';
  return m_id;
end $$;

-- ELO-style rating with guardrails, rating history and winner/loser notifications.
create or replace function public.validate_match_if_confirmed(p_match_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare m matches; c challenges; sid uuid; rw integer; rl integer; ew numeric; delta integer; winner_new integer; loser_new integer; k integer:=32; winner_name text; loser_name text;
begin
  select * into m from matches where id=p_match_id for update;
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  if m.confirmed_by_winner and m.confirmed_by_loser and m.validated_at is null then
    select * into c from challenges where id=m.challenge_id for update;
    sid:=c.sport_id;
    insert into sport_rankings(sport_id,profile_id) values(sid,m.winner_id),(sid,m.loser_id) on conflict(sport_id,profile_id) do nothing;
    select rating into rw from sport_rankings where sport_id=sid and profile_id=m.winner_id for update;
    select rating into rl from sport_rankings where sport_id=sid and profile_id=m.loser_id for update;
    ew := 1.0/(1.0+power(10.0,((rl-rw)::numeric)/400.0));
    delta := greatest(8,least(48,round(k*(1-ew))))::integer;
    winner_new:=rw+delta;
    loser_new:=greatest(0,rl-delta);
    update sport_rankings set rating=winner_new,wins=wins+1,streak=streak+1,season_points=season_points+delta,updated_at=now() where sport_id=sid and profile_id=m.winner_id;
    update sport_rankings set rating=loser_new,losses=losses+1,streak=0,season_points=greatest(0,season_points-delta),updated_at=now() where sport_id=sid and profile_id=m.loser_id;
    insert into rating_history(sport_id,profile_id,match_id,rating_before,rating_after,delta,reason) values
      (sid,m.winner_id,m.id,rw,winner_new,delta,'MATCH_WIN'),
      (sid,m.loser_id,m.id,rl,loser_new,-delta,'MATCH_LOSS');
    with ranked as (select profile_id,row_number() over(order by rating desc,wins desc,updated_at asc) rn from sport_rankings where sport_id=sid)
    update sport_rankings sr set ranking_position=r.rn where sr.sport_id=sid and sr.profile_id in(select profile_id from ranked);
    update profiles p set wins=p.wins+1,streak=p.streak+1 where p.id=m.winner_id;
    update profiles p set losses=p.losses+1,streak=0 where p.id=m.loser_id;
    update challenges set status='COMPLETED' where id=m.challenge_id;
    update matches set validated_at=now() where id=m.id;
    select full_name into winner_name from profiles where id=m.winner_id;
    select full_name into loser_name from profiles where id=m.loser_id;
    insert into notifications(user_id,actor_id,type,entity_id,message) values
      (m.winner_id,m.loser_id,'MATCH_VALIDATED',m.id,coalesce(winner_name,'Ganador')||' ganó y recibió '||delta||' rating.'),
      (m.loser_id,m.winner_id,'MATCH_VALIDATED',m.id,coalesce(loser_name,'Jugador')||' perdió '||delta||' rating en el partido validado.');
  end if;
end $$;

-- Keep social discovery clean: do not recommend people blocked in either direction.
create or replace function public.find_best_challenge_opponents(
  p_sport_id uuid,
  p_limit integer default 12
)
returns table(profile_id uuid,username text,full_name text,city text,country text,ranking_position integer,ranking_points integer,wins integer,losses integer,streak integer,distance_score integer,fit_score integer)
language sql security definer set search_path=public as $$
with me as (
  select p.id,p.city,p.country,coalesce(sr.rating,1000) my_rating
  from profiles p left join sport_rankings sr on sr.profile_id=p.id and sr.sport_id=p_sport_id where p.id=auth.uid() limit 1
), base as (
  select p.id profile_id,p.username,p.full_name,p.city,p.country,
    coalesce(sr.ranking_position,999999) ranking_position,
    coalesce(sr.season_points,0) ranking_points,
    coalesce(sr.wins,0) wins,coalesce(sr.losses,0) losses,coalesce(sr.streak,0) streak,
    case when p.city is not null and m.city is not null and lower(p.city)=lower(m.city) then 100 else 60 end distance_score,
    greatest(0,100-abs(coalesce(sr.rating,1000)-m.my_rating)/8) rating_score
  from profiles p cross join me m
  left join sport_rankings sr on sr.profile_id=p.id and sr.sport_id=p_sport_id
  where p.id<>auth.uid()
    and exists(select 1 from profile_sports ps where ps.profile_id=p.id and ps.sport_id=p_sport_id)
    and not exists(select 1 from blocked_profiles b where (b.blocker_id=auth.uid() and b.blocked_id=p.id) or (b.blocker_id=p.id and b.blocked_id=auth.uid()))
)
select profile_id,username,full_name,city,country,ranking_position,ranking_points,wins,losses,streak,distance_score,
least(100,greatest(0,round((rating_score*.7)+(distance_score*.3))))::integer fit_score
from base order by fit_score desc,abs(ranking_position-coalesce((select ranking_position from sport_rankings where profile_id=auth.uid() and sport_id=p_sport_id limit 1),999999)) asc
limit greatest(1,least(coalesce(p_limit,12),50));
$$;

create or replace function public.block_profile(p_blocked_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if auth.uid()=p_blocked_id then raise exception 'SELF_BLOCK_NOT_ALLOWED'; end if;
  if not exists(select 1 from profiles where id=p_blocked_id) then raise exception 'PLAYER_NOT_FOUND'; end if;
  insert into blocked_profiles(blocker_id,blocked_id) values(auth.uid(),p_blocked_id) on conflict do nothing;
  delete from follows where follower_id=auth.uid() and following_id=p_blocked_id;
  delete from follows where follower_id=p_blocked_id and following_id=auth.uid();
end $$;

create or replace function public.unblock_profile(p_blocked_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  delete from blocked_profiles where blocker_id=auth.uid() and blocked_id=p_blocked_id;
end $$;

create or replace function public.report_content(p_target_user_id uuid default null,p_post_id uuid default null,p_match_id uuid default null,p_reason text default 'OTHER',p_details text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare rid uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_target_user_id is null and p_post_id is null and p_match_id is null then raise exception 'REPORT_TARGET_REQUIRED'; end if;
  insert into moderation_reports(reporter_id,target_user_id,post_id,match_id,reason,details) values(auth.uid(),p_target_user_id,p_post_id,p_match_id,upper(trim(p_reason)),left(trim(coalesce(p_details,'')),1000)) returning id into rid;
  return rid;
end $$;

create or replace function public.update_profile_sport(p_sport_id uuid,p_skill_level text,p_is_primary boolean default false)
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not exists(select 1 from sports where id=p_sport_id) then raise exception 'SPORT_NOT_FOUND'; end if;
  insert into profile_sports(profile_id,sport_id,skill_level,is_primary) values(auth.uid(),p_sport_id,nullif(trim(p_skill_level),''),p_is_primary)
  on conflict(profile_id,sport_id) do update set skill_level=excluded.skill_level,is_primary=excluded.is_primary;
end $$;

-- Progress season missions after an official match. Mission codes may use PLAY_N / WIN_N.
create or replace function public.progress_match_missions(p_user_id uuid,p_sport_id uuid,p_won boolean)
returns void language plpgsql security definer set search_path=public as $$
declare m missions; inc integer;
begin
  for m in select * from missions where active and (sport_id is null or sport_id=p_sport_id) loop
    inc:=0;
    if m.code like 'PLAY_%' then inc:=1; end if;
    if p_won and m.code like 'WIN_%' then inc:=1; end if;
    if inc>0 then
      insert into user_missions(user_id,mission_id,progress) values(p_user_id,m.id,least(m.target,inc))
      on conflict(user_id,mission_id) do update set progress=least(m.target,user_missions.progress+inc),completed_at=case when least(m.target,user_missions.progress+inc)>=m.target then coalesce(user_missions.completed_at,now()) else user_missions.completed_at end;
    end if;
  end loop;
end $$;

-- Trigger mission progression after a validated match.
create or replace function public.progress_validated_match_missions()
returns trigger language plpgsql security definer set search_path=public as $$
declare c challenges;
begin
  if new.validated_at is not null and (old.validated_at is null or old.validated_at is distinct from new.validated_at) then
    select * into c from challenges where id=new.challenge_id;
    perform public.progress_match_missions(new.winner_id,c.sport_id,true);
    perform public.progress_match_missions(new.loser_id,c.sport_id,false);
  end if;
  return new;
end $$;

drop trigger if exists trg_progress_match_missions on matches;
create trigger trg_progress_match_missions after update of validated_at on matches for each row execute function public.progress_validated_match_missions();

-- =========================
-- CORE FUNCTIONAL 6 · SAFETY / INTEGRITY HARDENING
-- =========================

-- Prevent duplicate open partner requests from generating notification spam.
create or replace function public.request_partner(p_sport_id uuid,p_recipient_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare new_id uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if auth.uid()=p_recipient_id then raise exception 'SELF_PARTNER_NOT_ALLOWED'; end if;
  if not exists(select 1 from sports where id=p_sport_id) then raise exception 'SPORT_NOT_FOUND'; end if;
  if not exists(select 1 from profiles where id=p_recipient_id) then raise exception 'PLAYER_NOT_FOUND'; end if;
  if exists(select 1 from blocked_profiles where (blocker_id=auth.uid() and blocked_id=p_recipient_id) or (blocker_id=p_recipient_id and blocked_id=auth.uid())) then raise exception 'PLAYER_BLOCKED'; end if;
  if exists(select 1 from pair_profiles where sport_id=p_sport_id and ((player_1=least(auth.uid(),p_recipient_id) and player_2=greatest(auth.uid(),p_recipient_id)))) then raise exception 'PAIR_ALREADY_EXISTS'; end if;
  insert into partner_requests(sport_id,requester_id,recipient_id)
  values(p_sport_id,auth.uid(),p_recipient_id)
  on conflict(sport_id,requester_id,recipient_id) do update set status='PENDING',responded_at=null
  returning id into new_id;
  if not exists(select 1 from notifications where user_id=p_recipient_id and actor_id=auth.uid() and type='PARTNER_REQUEST' and entity_id=new_id and created_at > now()-interval '5 minutes') then
    insert into notifications(user_id,actor_id,type,entity_id,message)
    values(p_recipient_id,auth.uid(),'PARTNER_REQUEST',new_id,'Te han enviado una invitación para formar pareja.');
  end if;
  return new_id;
end $$;

-- Search must ignore blocked users, matching matchmaking behavior.
create or replace function public.search_players(p_query text,p_limit integer default 30)
returns table(profile_id uuid,username text,full_name text,city text,country text)
language sql security definer set search_path=public as $$
  select p.id,p.username,p.full_name,p.city,p.country
  from profiles p
  where auth.uid() is not null
    and p.id<>auth.uid()
    and not exists(select 1 from blocked_profiles b where (b.blocker_id=auth.uid() and b.blocked_id=p.id) or (b.blocker_id=p.id and b.blocked_id=auth.uid()))
    and (coalesce(trim(p_query),'')='' or p.username ilike '%'||trim(p_query)||'%' or p.full_name ilike '%'||trim(p_query)||'%' or coalesce(p.city,'') ilike '%'||trim(p_query)||'%')
  order by p.full_name asc
  limit greatest(1,least(coalesce(p_limit,30),50));
$$;

-- Never expose moderation reports to other users.
drop policy if exists moderation_reports_public_select on moderation_reports;

-- Rating history is personal analytics; public rankings remain in sport_rankings.
drop policy if exists rating_history_public_select on rating_history;
create policy rating_history_self_select on rating_history for select using(auth.uid()=profile_id);

-- Prevent direct profile-sport assignment to another user through the table API.
drop policy if exists profile_sports_self_insert on profile_sports;
drop policy if exists profile_sports_self_update on profile_sports;
create policy profile_sports_self_insert on profile_sports for insert with check(auth.uid()=profile_id);
create policy profile_sports_self_update on profile_sports for update using(auth.uid()=profile_id) with check(auth.uid()=profile_id);



-- =========================
-- DYNASTY BUSINESS ENGINE · subscriptions, club coaches and promotion
-- =========================
create table if not exists subscription_accounts (
  id uuid primary key default gen_random_uuid(),
  owner_profile_id uuid references profiles(id) on delete cascade,
  owner_type text not null check (owner_type in ('PLAYER','CLUB','COACH','ORGANIZER','SELLER')),
  plan_code text not null default 'FREE',
  status text not null default 'ACTIVE' check (status in ('ACTIVE','PAST_DUE','GRACE','RESTRICTED','SUSPENDED','CANCELLED')),
  grace_until timestamptz, current_period_end timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists subscription_accounts_owner_idx on subscription_accounts(owner_profile_id,owner_type,status);

create table if not exists club_coaches (
  club_id uuid not null references clubs(id) on delete cascade,
  coach_profile_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','INVITED','INACTIVE')),
  created_at timestamptz not null default now(),
  primary key(club_id,coach_profile_id)
);

create table if not exists promotion_campaigns (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references profiles(id) on delete set null,
  campaign_type text not null check (campaign_type in ('TOURNAMENT_FEATURED','BOOST','DYNASTY_PROMOTE','SPONSOR')),
  status text not null default 'DRAFT' check (status in ('DRAFT','PENDING','ACTIVE','PAUSED','ENDED')),
  entity_type text, entity_id uuid, starts_at timestamptz, ends_at timestamptz, created_at timestamptz not null default now()
);

alter table subscription_accounts enable row level security;
alter table club_coaches enable row level security;
alter table promotion_campaigns enable row level security;
create policy subscription_accounts_self_select on subscription_accounts for select using(auth.uid()=owner_profile_id);
create policy subscription_accounts_self_update on subscription_accounts for update using(auth.uid()=owner_profile_id);
create policy club_coaches_self_select on club_coaches for select using(auth.uid()=coach_profile_id or exists(select 1 from clubs c where c.id=club_coaches.club_id and c.owner_id=auth.uid()));
create policy promotion_campaigns_self_all on promotion_campaigns for all using(auth.uid()=profile_id) with check(auth.uid()=profile_id);
