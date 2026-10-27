-- FEATURE PEDIDA POR LUIS (2026-10-26): "cuando salgan los cuadros, que le llegue una alerta a
-- la gente: juegas hoy a tal hora, cancha tanto". Ya existia `publish_tournament_schedule`, pero
-- esa funcion solo manda un aviso generico ("la programacion ya esta disponible"), sin decirle a
-- cada jugador contra quien juega ni a que hora. Esta funcion nueva manda, a cada jugador
-- confirmado de un partido ya generado, una notificacion con el rival y la hora de SU partido.
--
-- Nota para Luis: la cancha/numero de pista todavia no se guarda en ningun lado de la base de
-- datos (tournament_fixtures no tiene esa columna) -- si quiere que la alerta incluya "cancha 3"
-- habria que agregar ese campo con otra migracion y una pantalla para que el organizador lo
-- asigne. Por ahora, si el torneo tiene una sede (location_name) se incluye esa en el mensaje.
--
-- Se puede llamar varias veces sobre la misma categoria sin duplicar avisos: cada fixture
-- avisado se marca en su metadata (schedule_notified_at), asi que una segunda llamada (por
-- ejemplo despues de generar la siguiente ronda de un sistema suizo) solo avisa los partidos
-- nuevos que todavia no se habian avisado.

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
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select * into v_cat from public.tournament_categories where id = p_category_id;
  if not found then
    raise exception 'category_not_found';
  end if;

  select * into v_t from public.tournaments where id = v_cat.tournament_id;
  if not found then
    raise exception 'tournament_not_found';
  end if;

  if not (
    v_t.organizer_profile_id = auth.uid()
    or (v_t.organization_id is not null and public.has_organization_permission(v_t.organization_id, 'manage_tournaments', auth.uid()))
  ) then
    raise exception 'forbidden';
  end if;

  for v_fx in
    select f.*
    from public.tournament_fixtures f
    where f.category_id = p_category_id
      and f.side_a_entry_id is not null
      and f.side_b_entry_id is not null
      and f.status <> 'cancelled'
      and coalesce(f.metadata ->> 'schedule_notified_at', '') = ''
  loop
    insert into public.notifications(profile_id, category, type, title, body, action_type, action_payload, source_type, source_id, priority)
    select
      tem.profile_id,
      'tournament',
      'tournament_fixture_scheduled',
      'Ya tienes partido: ' || v_cat.name,
      trim(
        'Ronda ' || coalesce(v_fx.round_number::text, '-')
        || ' vs ' || coalesce((
            select string_agg(p2.display_name, ' / ' order by p2.display_name)
            from public.tournament_entry_members tem2
            join public.profiles p2 on p2.id = tem2.profile_id
            where tem2.entry_id = (case when tem.entry_id = v_fx.side_a_entry_id then v_fx.side_b_entry_id else v_fx.side_a_entry_id end)
              and tem2.status = 'confirmed'
          ), 'rival por definir')
        || coalesce(' — ' || to_char(v_fx.scheduled_at at time zone 'America/Bogota', 'DD/MM/YYYY HH12:MI AM'), '')
        || coalesce(' — ' || v_t.location_name, '')
      ),
      'open_tournament',
      jsonb_build_object('tournament_id', v_t.id, 'fixture_id', v_fx.id, 'category_id', p_category_id),
      'tournament_fixture',
      v_fx.id,
      'high'
    from public.tournament_entry_members tem
    where tem.entry_id in (v_fx.side_a_entry_id, v_fx.side_b_entry_id)
      and tem.status = 'confirmed'
    on conflict do nothing;

    update public.tournament_fixtures
    set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('schedule_notified_at', now())
    where id = v_fx.id;

    v_notified := v_notified + 1;
  end loop;

  return jsonb_build_object('ok', true, 'category_id', p_category_id, 'fixtures_notified', v_notified);
end;
$function$;

GRANT EXECUTE ON FUNCTION public.notify_category_fixture_schedule(uuid) TO authenticated;
