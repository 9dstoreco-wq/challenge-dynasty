-- Dynasty collectible cards v1 (2026-10-04)
--
-- Cartas coleccionables que cambian de dueño: cuando dos jugadores acuerdan poner una carta
-- en juego en un reto, quien gana (resultado CONFIRMADO) se queda con la carta del perdedor.
--
-- Reglas de producto (acordadas con Luis Castillo):
--   * Cada jugador tiene una carta BASE por deporte que nunca se puede apostar ni perder.
--   * Apostar carta es opcional y se acuerda por reto: solo cuenta si AMBOS ponen una carta.
--   * Las cartas se ganan jugando (no hay compra de cartas en esta version).
--   * Ganar un reto sin cartas en juego da una carta TROFEO (la del rival vencido).
--   * Ninguna de estas funciones puede bloquear la confirmacion de un resultado: el trigger
--     captura cualquier error y solo emite un WARNING.
--
-- No toca review_challenge_result ni apply_confirmed_match_progression: se engancha con un
-- trigger propio en match_results (se ejecuta DESPUES del de progresion, por orden alfabetico).

create table if not exists public.dynasty_cards (
  id uuid primary key default gen_random_uuid(),
  serial bigint generated always as identity,
  sport_id uuid not null references public.sports(id),
  owner_profile_id uuid not null references public.profiles(id) on delete cascade,
  original_profile_id uuid not null references public.profiles(id) on delete cascade,
  rarity text not null default 'common' check (rarity in ('common','rare','epic','legendary')),
  origin text not null check (origin in ('base','win_reward')),
  is_protected boolean not null default false,
  source_match_id uuid references public.matches(id) on delete set null,
  stats jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint dynasty_cards_base_is_protected check ((origin = 'base') = is_protected)
);
create unique index if not exists dynasty_cards_one_base_per_player_sport
  on public.dynasty_cards (original_profile_id, sport_id) where origin = 'base';
create unique index if not exists dynasty_cards_one_reward_per_match
  on public.dynasty_cards (source_match_id) where origin = 'win_reward';
create index if not exists dynasty_cards_owner_idx on public.dynasty_cards (owner_profile_id);
create index if not exists dynasty_cards_original_idx on public.dynasty_cards (original_profile_id);
create index if not exists dynasty_cards_sport_idx on public.dynasty_cards (sport_id);

create table if not exists public.dynasty_card_transfers (
  id uuid primary key default gen_random_uuid(),
  card_id uuid not null references public.dynasty_cards(id) on delete cascade,
  from_profile_id uuid not null references public.profiles(id) on delete cascade,
  to_profile_id uuid not null references public.profiles(id) on delete cascade,
  challenge_id uuid references public.challenges(id) on delete set null,
  match_id uuid references public.matches(id) on delete set null,
  reason text not null default 'challenge_stake' check (reason in ('challenge_stake')),
  created_at timestamptz not null default now()
);
create unique index if not exists dynasty_card_transfers_card_match_uq
  on public.dynasty_card_transfers (card_id, match_id) where match_id is not null;
create index if not exists dynasty_card_transfers_card_idx on public.dynasty_card_transfers (card_id);
create index if not exists dynasty_card_transfers_from_idx on public.dynasty_card_transfers (from_profile_id);
create index if not exists dynasty_card_transfers_to_idx on public.dynasty_card_transfers (to_profile_id);
create index if not exists dynasty_card_transfers_challenge_idx on public.dynasty_card_transfers (challenge_id);
create index if not exists dynasty_card_transfers_match_idx on public.dynasty_card_transfers (match_id);

create table if not exists public.challenge_card_stakes (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  card_id uuid not null references public.dynasty_cards(id) on delete cascade,
  status text not null default 'locked' check (status in ('locked','settled','released')),
  created_at timestamptz not null default now(),
  settled_at timestamptz
);
-- Un jugador solo puede tener una carta en juego por reto, y una carta solo puede estar
-- bloqueada en un reto a la vez.
create unique index if not exists challenge_card_stakes_one_locked_per_player
  on public.challenge_card_stakes (challenge_id, profile_id) where status = 'locked';
create unique index if not exists challenge_card_stakes_one_locked_per_card
  on public.challenge_card_stakes (card_id) where status = 'locked';
create index if not exists challenge_card_stakes_challenge_idx on public.challenge_card_stakes (challenge_id);
create index if not exists challenge_card_stakes_profile_idx on public.challenge_card_stakes (profile_id);
create index if not exists challenge_card_stakes_card_idx on public.challenge_card_stakes (card_id);

-- RLS: lectura para usuarios autenticados; NINGUNA escritura directa (solo funciones SECURITY DEFINER).
alter table public.dynasty_cards enable row level security;
alter table public.dynasty_card_transfers enable row level security;
alter table public.challenge_card_stakes enable row level security;

drop policy if exists "dynasty cards authenticated read" on public.dynasty_cards;
create policy "dynasty cards authenticated read" on public.dynasty_cards
  for select to authenticated using (true);

drop policy if exists "dynasty card transfers authenticated read" on public.dynasty_card_transfers;
create policy "dynasty card transfers authenticated read" on public.dynasty_card_transfers
  for select to authenticated using (true);

drop policy if exists "challenge card stakes participants read" on public.challenge_card_stakes;
create policy "challenge card stakes participants read" on public.challenge_card_stakes
  for select to authenticated using (
    profile_id = (select auth.uid())
    or exists (
      select 1 from public.challenge_participants cp
      where cp.challenge_id = challenge_card_stakes.challenge_id and cp.profile_id = (select auth.uid())
    )
  );

revoke all on public.dynasty_cards, public.dynasty_card_transfers, public.challenge_card_stakes from anon, authenticated;
grant select on public.dynasty_cards, public.dynasty_card_transfers, public.challenge_card_stakes to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Emision de cartas (interna)
-- ---------------------------------------------------------------------------------------------
create or replace function public.mint_dynasty_card(
  p_owner uuid, p_original uuid, p_sport uuid, p_rarity text, p_origin text, p_protected boolean,
  p_source_match uuid default null
) returns uuid
language plpgsql security definer set search_path to 'public', 'pg_temp'
as $$
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
end $$;

-- Carta base automatica al registrar un deporte en el que el jugador compite.
create or replace function public.on_player_sport_mint_base_card()
returns trigger
language plpgsql security definer set search_path to 'public', 'pg_temp'
as $$
begin
  if new.relationship in ('active', 'primary', 'secondary', 'learning') then
    perform public.mint_dynasty_card(new.profile_id, new.profile_id, new.sport_id, 'common', 'base', true, null);
  end if;
  return new;
end $$;

drop trigger if exists trg_player_sport_mint_base_card on public.player_sports;
create trigger trg_player_sport_mint_base_card
  after insert or update of relationship on public.player_sports
  for each row execute function public.on_player_sport_mint_base_card();

-- Carta base para quienes ya tenian un deporte registrado.
insert into public.dynasty_cards(owner_profile_id, original_profile_id, sport_id, rarity, origin, is_protected, stats)
select ps.profile_id, ps.profile_id, ps.sport_id, 'common', 'base', true,
       jsonb_build_object('rating', coalesce(sr.rating, 1000), 'level', coalesce(pp.level, 1))
from public.player_sports ps
left join public.sport_rankings sr on sr.profile_id = ps.profile_id and sr.sport_id = ps.sport_id
left join public.player_progression pp on pp.profile_id = ps.profile_id
where ps.relationship in ('active', 'primary', 'secondary', 'learning')
on conflict do nothing;

-- ---------------------------------------------------------------------------------------------
-- Poner / retirar una carta en juego (RPC para usuarios autenticados)
-- ---------------------------------------------------------------------------------------------
create or replace function public.stake_card_on_challenge(p_challenge_id uuid, p_card_id uuid)
returns public.challenge_card_stakes
language plpgsql security definer set search_path to 'public', 'pg_temp'
as $$
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

  delete from public.challenge_card_stakes where challenge_id = p_challenge_id and profile_id = v_uid and status = 'locked';
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
end $$;

create or replace function public.withdraw_card_stake(p_challenge_id uuid)
returns void
language plpgsql security definer set search_path to 'public', 'pg_temp'
as $$
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
end $$;

-- ---------------------------------------------------------------------------------------------
-- Liquidacion al confirmarse un resultado (interna, nunca bloquea la confirmacion)
-- ---------------------------------------------------------------------------------------------
create or replace function public.settle_challenge_card_stakes()
returns trigger
language plpgsql security definer set search_path to 'public', 'pg_temp'
as $$
declare
  v_match public.matches;
  v_win public.challenge_card_stakes;
  v_lose public.challenge_card_stakes;
  v_have_win boolean; v_have_lose boolean;
  v_loser uuid; v_wins integer; v_rarity text;
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

    -- Sin acuerdo de cartas: se liberan las que hubiera y el ganador recibe una carta trofeo.
    update public.challenge_card_stakes set status = 'released', settled_at = now()
      where challenge_id = v_match.challenge_id and status = 'locked';

    select cp.profile_id into v_loser from public.challenge_participants cp
      where cp.challenge_id = v_match.challenge_id and cp.status = 'accepted' and cp.profile_id <> new.winner_profile_id
      order by cp.joined_at limit 1;
    if v_loser is not null then
      select count(*) into v_wins from public.match_results mr join public.matches m on m.id = mr.match_id
        where mr.status = 'confirmed' and mr.winner_profile_id = new.winner_profile_id
          and m.sport_id = v_match.sport_id and m.challenge_id is not null;
      v_rarity := case when v_wins % 25 = 0 then 'legendary' when v_wins % 10 = 0 then 'epic' when v_wins % 5 = 0 then 'rare' else 'common' end;
      perform public.mint_dynasty_card(new.winner_profile_id, v_loser, v_match.sport_id, v_rarity, 'win_reward', false, v_match.id);
    end if;
  exception when others then
    raise warning 'settle_challenge_card_stakes failed for match %: %', new.match_id, sqlerrm;
  end;
  return new;
end $$;

drop trigger if exists trg_settle_card_stakes on public.match_results;
create trigger trg_settle_card_stakes
  after insert or update on public.match_results
  for each row execute function public.settle_challenge_card_stakes();

-- Si el reto se cancela, las cartas en juego se liberan.
create or replace function public.release_card_stakes_on_challenge_cancel()
returns trigger
language plpgsql security definer set search_path to 'public', 'pg_temp'
as $$
begin
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    update public.challenge_card_stakes set status = 'released', settled_at = now()
      where challenge_id = new.id and status = 'locked';
  end if;
  return new;
end $$;

drop trigger if exists trg_release_card_stakes_on_cancel on public.challenges;
create trigger trg_release_card_stakes_on_cancel
  after update of status on public.challenges
  for each row execute function public.release_card_stakes_on_challenge_cancel();

-- ---------------------------------------------------------------------------------------------
-- Permisos de funciones
-- ---------------------------------------------------------------------------------------------
revoke all on function public.mint_dynasty_card(uuid, uuid, uuid, text, text, boolean, uuid) from public, anon, authenticated;
revoke all on function public.on_player_sport_mint_base_card() from public, anon, authenticated;
revoke all on function public.settle_challenge_card_stakes() from public, anon, authenticated;
revoke all on function public.release_card_stakes_on_challenge_cancel() from public, anon, authenticated;
revoke all on function public.stake_card_on_challenge(uuid, uuid) from public, anon;
revoke all on function public.withdraw_card_stake(uuid) from public, anon;
grant execute on function public.stake_card_on_challenge(uuid, uuid) to authenticated;
grant execute on function public.withdraw_card_stake(uuid) to authenticated;
