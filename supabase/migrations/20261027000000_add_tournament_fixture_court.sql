-- FEATURE PEDIDA POR LUIS (2026-10-27): agregar un campo de cancha a los partidos de torneo.
-- Hoy tournament_fixtures solo guarda la hora (scheduled_at); no hay donde decir "cancha 2" o
-- "pista central". Se agrega una columna de texto libre (no un id de recurso de reservas: un
-- torneo puede jugarse en canchas que no son recursos reservables de la app, p.ej. canchas
-- prestadas o de otro club) y se deja que el organizador la edite en el mismo panel donde ya
-- cuadra las horas (TournamentScheduleEditor.tsx).
--
-- IMPORTANTE: en vez de reemplazar reschedule_tournament_fixture(uuid, timestamptz) -- lo que
-- obligaria a un DROP FUNCTION, y DROP de cualquier tipo en este proyecto se cuelga mas de 3
-- minutos sin dejar rastro (ver notas de infraestructura) -- se crea un OVERLOAD nuevo con un
-- tercer parametro obligatorio (p_court). Postgres distingue las dos funciones por aridad (2
-- argumentos vs 3), asi que no hay ambiguedad para PostgREST y la version vieja de 2 argumentos
-- queda intacta (por si algun llamador viejo quedara pendiente de actualizar).

ALTER TABLE public.tournament_fixtures ADD COLUMN IF NOT EXISTS court text;

CREATE OR REPLACE FUNCTION public.reschedule_tournament_fixture(p_fixture_id uuid, p_scheduled_at timestamptz, p_court text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_fx public.tournament_fixtures%rowtype;
  v_t public.tournaments%rowtype;
  v_court text;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  if p_scheduled_at is null then
    raise exception 'scheduled_at_required';
  end if;

  v_court := nullif(trim(coalesce(p_court, '')), '');

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
      court = v_court,
      metadata = coalesce(metadata, '{}'::jsonb) - 'schedule_notified_at'
  where id = p_fixture_id;

  return jsonb_build_object('ok', true, 'fixture_id', p_fixture_id, 'scheduled_at', p_scheduled_at, 'court', v_court);
end;
$function$;

GRANT EXECUTE ON FUNCTION public.reschedule_tournament_fixture(uuid, timestamptz, text) TO authenticated;

-- notify_category_fixture_schedule: incluir la cancha en el mensaje cuando el organizador la puso.
CREATE OR REPLACE FUNCTION public.notify_category_fixture_schedule(p_category_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_cat public.tournament_categories%rowtype;
  v_t public.tournaments%rowtype;
  v_notified integer := 0;
  v_fx record;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into v_cat from public.tournament_categories where id = p_category_id;
  if not found then raise exception 'category_not_found'; end if;
  select * into v_t from public.tournaments where id = v_cat.tournament_id;
  if not found then raise exception 'tournament_not_found'; end if;
  if not (v_t.organizer_profile_id = auth.uid() or (v_t.organization_id is not null and public.has_organization_permission(v_t.organization_id, 'manage_tournaments', auth.uid()))) then
    raise exception 'forbidden';
  end if;
  for v_fx in
    select f.* from public.tournament_fixtures f
    where f.category_id = p_category_id and f.side_a_entry_id is not null and f.side_b_entry_id is not null
      and f.status <> 'cancelled' and coalesce(f.metadata ->> 'schedule_notified_at', '') = ''
  loop
    insert into public.notifications(profile_id, category, type, title, body, action_type, action_payload, source_type, source_id, priority)
    select tem.profile_id, 'tournament', 'tournament_fixture_scheduled',
      'Ya tienes partido: ' || v_cat.name,
      trim('Ronda ' || coalesce(v_fx.round_number::text, '-') || ' vs ' || coalesce((
          select string_agg(p2.display_name, ' / ' order by p2.display_name)
          from public.tournament_entry_members tem2 join public.profiles p2 on p2.id = tem2.profile_id
          where tem2.entry_id = (case when tem.entry_id = v_fx.side_a_entry_id then v_fx.side_b_entry_id else v_fx.side_a_entry_id end)
            and tem2.status = 'confirmed'
        ), 'rival por definir')
        || coalesce(' — ' || to_char(v_fx.scheduled_at at time zone 'America/Bogota', 'DD/MM/YYYY HH12:MI AM'), '')
        || coalesce(' — Cancha ' || v_fx.court, '')
        || coalesce(' — ' || v_t.location_name, '')),
      'open_tournament', jsonb_build_object('tournament_id', v_t.id, 'fixture_id', v_fx.id, 'category_id', p_category_id),
      'tournament_fixture', v_fx.id, 'high'
    from public.tournament_entry_members tem
    where tem.entry_id in (v_fx.side_a_entry_id, v_fx.side_b_entry_id) and tem.status = 'confirmed'
    on conflict do nothing;
    update public.tournament_fixtures set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('schedule_notified_at', now()) where id = v_fx.id;
    v_notified := v_notified + 1;
  end loop;
  return jsonb_build_object('ok', true, 'category_id', p_category_id, 'fixtures_notified', v_notified);
end;
$function$;

GRANT EXECUTE ON FUNCTION public.notify_category_fixture_schedule(uuid) TO authenticated;
