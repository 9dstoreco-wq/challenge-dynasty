-- Challenge Dynasty — endurecimiento de retos y cartas (auditoria 2026-10-05)
-- Aplicada a mano en produccion el 2026-10-05 (funciones 1, 2 y 3).
-- Pendiente de autorizar: dedup de retos abiertos en create_challenge (no aplicado).
-- Todo es CREATE OR REPLACE: se puede re-ejecutar sin riesgo.
--
-- 1. Liquidacion de cartas: tope de cartas trofeo por rival, rareza solo con rivales distintos,
--    aviso al ganador, y si algo falla las apuestas se liberan (nunca quedan atrapadas).
-- 2. cancel_challenge: no permite cancelar un reto que ya tiene resultado.
-- 3. respond_to_challenge_invitation: al rechazar, el reto se cancela y libera las cartas.

create or replace function public.settle_challenge_card_stakes()
returns trigger
language plpgsql security definer set search_path to 'public', 'pg_temp'
as $$
declare
  v_match public.matches;
  v_win public.challenge_card_stakes;
  v_lose public.challenge_card_stakes;
  v_have_win boolean; v_have_lose boolean;
  v_loser uuid; v_wins integer; v_rarity text; v_recent integer; v_distinct integer;
  c_max_trophies_per_rival constant integer := 2;   -- cartas trofeo por rival en 7 dias
  c_min_rivals_for_rarity constant integer := 3;    -- rivales distintos para rareza > comun
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

    -- Sin acuerdo de cartas: se liberan las que hubiera y el ganador recibe una carta trofeo (con limites).
    update public.challenge_card_stakes set status = 'released', settled_at = now()
      where challenge_id = v_match.challenge_id and status = 'locked';

    select cp.profile_id into v_loser from public.challenge_participants cp
      where cp.challenge_id = v_match.challenge_id and cp.status = 'accepted' and cp.profile_id <> new.winner_profile_id
      order by cp.joined_at limit 1;

    if v_loser is not null then
      -- Anti-trampa: tope de cartas trofeo contra el mismo rival en 7 dias.
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

      select count(*) into v_wins from public.match_results mr join public.matches m on m.id = mr.match_id
        where mr.status = 'confirmed' and mr.winner_profile_id = new.winner_profile_id
          and m.sport_id = v_match.sport_id and m.challenge_id is not null;

      -- La rareza superior exige haber ganado a varios rivales distintos.
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
    raise warning 'settle_challenge_card_stakes failed for match %: %', new.match_id, sqlerrm;
    -- Si algo falla, las cartas no deben quedar bloqueadas para siempre.
    begin
      update public.challenge_card_stakes set status = 'released', settled_at = now()
        where challenge_id = (select challenge_id from public.matches where id = new.match_id) and status = 'locked';
    exception when others then null;
    end;
  end;
  return new;
end $$;

create or replace function public.cancel_challenge(p_challenge_id uuid)
returns boolean
language plpgsql security definer set search_path to 'public', 'pg_temp'
as $$
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
end; $$;

create or replace function public.respond_to_challenge_invitation(p_invitation_id uuid, p_accept boolean)
returns challenge_invitations
language plpgsql security definer set search_path to 'public', 'pg_temp'
as $$
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
    -- Al rechazarse, el reto se cierra (y el trigger libera las cartas que el creador hubiera puesto).
    update public.challenges set status = 'cancelled', updated_at = now() where id = v_inv.challenge_id and status = 'open';
    insert into public.notifications(profile_id, category, type, title, body, action_type, action_payload, source_type, source_id, priority)
    values (v_inv.inviter_id, 'challenge', 'challenge_invitation_declined', 'Reto rechazado', 'Tu invitación fue rechazada.', 'open_challenge', jsonb_build_object('challenge_id', v_inv.challenge_id), 'challenge', v_inv.challenge_id, 'normal')
    on conflict do nothing;
  end if;
  return v_inv;
end; $$;
