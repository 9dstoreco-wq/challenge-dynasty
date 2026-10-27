-- FEATURE PEDIDA POR LUIS (2026-10-26): "hay jugadores que juegan dos categorias (mixto, quinta,
-- sexta...) -- que no les den partidos a la misma hora, y que el organizador pueda cuadrar las
-- horas el mismo". El generador automatico de cuadros (generateBracket/generateNextSwissRound/
-- generateKnockoutStage, en lib/tournamentBracketActions.ts) le pone una hora de relleno a cada
-- partido (ahora + 24h, +2h por ronda) SIN mirar si ese jugador ya tiene otro partido a esa hora
-- en OTRA categoria -- de ahi el riesgo de choques que Luis señalo. La deteccion de choques ya
-- existe (validate_tournament_schedule, usada en /competitions/organize), pero hasta ahora no
-- habia ninguna forma de que el organizador corrigiera la hora de un partido puntual: esta RPC es
-- esa pieza que faltaba.
--
-- Al cambiar la hora de un partido se le borra la marca "ya se avisó" (schedule_notified_at) de
-- su metadata, para que la proxima vez que el organizador use "Avisar a los jugadores" le llegue
-- a cada jugador la hora CORREGIDA, no la vieja.

CREATE OR REPLACE FUNCTION public.reschedule_tournament_fixture(p_fixture_id uuid, p_scheduled_at timestamptz)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_fx public.tournament_fixtures%rowtype;
  v_t public.tournaments%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  if p_scheduled_at is null then
    raise exception 'scheduled_at_required';
  end if;

  select * into v_fx from public.tournament_fixtures where id = p_fixture_id for update;
  if not found then
    raise exception 'fixture_not_found';
  end if;

  select * into v_t from public.tournaments where id = v_fx.tournament_id;
  if not found then
    raise exception 'tournament_not_found';
  end if;

  if not (
    v_t.organizer_profile_id = auth.uid()
    or (v_t.organization_id is not null and public.has_organization_permission(v_t.organization_id, 'manage_tournaments', auth.uid()))
  ) then
    raise exception 'forbidden';
  end if;

  if v_fx.status in ('completed', 'cancelled') then
    raise exception 'fixture_already_finalized';
  end if;

  update public.tournament_fixtures
  set scheduled_at = p_scheduled_at,
      metadata = coalesce(metadata, '{}'::jsonb) - 'schedule_notified_at'
  where id = p_fixture_id;

  return jsonb_build_object('ok', true, 'fixture_id', p_fixture_id, 'scheduled_at', p_scheduled_at);
end;
$function$;

GRANT EXECUTE ON FUNCTION public.reschedule_tournament_fixture(uuid, timestamptz) TO authenticated;
