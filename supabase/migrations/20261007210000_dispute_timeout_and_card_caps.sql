-- Challenge Dynasty -- tres arreglos pedidos en el repaso de hoy sobre cartas y disputas:
-- (a) un vencimiento automatico para que un reto no pueda quedar atascado para siempre en un
--     ciclo de disputa con las dos cartas bloqueadas;
-- (b) un tope GLOBAL (no solo por rival) de cartas trofeo por semana;
-- (c) que un fallo al entregar una carta avise a los jugadores y se reintente solo, en vez de
--     quedar como una simple advertencia en el log que nadie ve.
-- ESTADO: ESCRITA, NO APLICADA. El sistema de permisos bloqueo aplicarla desde Claude porque es
-- un deploy a produccion sin revision humana; la corre Luis en el editor SQL de Supabase.

-- =====================================================================================
-- (a) Vencimiento automatico del ciclo de disputa
-- =====================================================================================
-- Hoy: si A envia un resultado y B lo disputa, B puede enviar su propia version, y si A la
-- disputa tambien, esto puede repetirse sin limite -- el reto nunca se confirma y las dos cartas
-- apostadas quedan bloqueadas para siempre. Esta funcion busca resultados "pending" o "disputed"
-- de mas de 48 horas sin movimiento y los confirma automaticamente con la ULTIMA version
-- registrada (la mas reciente que alguien envio). Al poner status='confirmed' se disparan los
-- mismos triggers que ya existen para una confirmacion normal (progresion, ranking, reparto de
-- cartas apostadas), asi que no hace falta duplicar esa logica aqui.
create or replace function public.expire_stale_challenge_disputes()
returns integer
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
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
$function$;

-- La corre el sistema (pg_cron), no un usuario: nadie fuera de la base de datos la necesita.
revoke all on function public.expire_stale_challenge_disputes() from public, authenticated, anon;

-- Se programa cada 15 minutos. select cron.unschedule() primero por si ya existia con otro id
-- (por ejemplo si esta migracion se corre dos veces).
select cron.unschedule(jobid) from cron.job where jobname = 'expire_stale_challenge_disputes';
select cron.schedule('expire_stale_challenge_disputes', '*/15 * * * *', $cron$select public.expire_stale_challenge_disputes()$cron$);

-- =====================================================================================
-- (b) y (c): reemplaza settle_challenge_card_stakes con tope global + registro de fallos
-- =====================================================================================
-- Tabla para (c): si algo falla al repartir la carta de un reto, se registra aqui en vez de
-- perderse en un simple "warning" del log de Postgres que nadie revisa. Sin policies (RLS
-- activado, cero policies): solo las funciones SECURITY DEFINER de abajo la tocan.
create table if not exists public.card_delivery_failures (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  match_id uuid not null references public.matches(id) on delete cascade,
  winner_profile_id uuid not null,
  loser_profile_id uuid,
  sport_id uuid,
  rarity text,
  step text not null, -- 'card_transfer' (apuesta) o 'trophy_mint' (carta trofeo sin apuesta)
  stake_loser_card_id uuid,
  error_message text,
  attempts integer not null default 0,
  resolved boolean not null default false,
  created_at timestamptz not null default now(),
  last_attempt_at timestamptz
);
create index if not exists card_delivery_failures_pending_idx
  on public.card_delivery_failures (resolved, attempts) where not resolved;
alter table public.card_delivery_failures enable row level security;

create or replace function public.settle_challenge_card_stakes()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
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
$function$;

-- Reintento automatico para (c). Revisa los fallos registrados (hasta 5 intentos cada uno) y
-- vuelve a intentar SOLO el paso que fallo. Antes de reintentar comprueba si ya existe la carta o
-- la transferencia (por si en realidad si se habia aplicado y solo fallo algo despues, como el
-- aviso) para nunca repartir una carta dos veces.
create or replace function public.retry_failed_card_deliveries()
returns integer
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
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
$function$;

revoke all on function public.retry_failed_card_deliveries() from public, authenticated, anon;

select cron.unschedule(jobid) from cron.job where jobname = 'retry_failed_card_deliveries';
select cron.schedule('retry_failed_card_deliveries', '*/15 * * * *', $cron$select public.retry_failed_card_deliveries()$cron$);
