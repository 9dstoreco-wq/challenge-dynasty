-- Enforce club opening hours (booking_availability_rules) and blackout dates
-- (booking_blackouts) when a booking is created or rescheduled.
--
-- Contexto: estas dos tablas ya existian en el esquema pero no estaban
-- conectadas a nada -- un cliente podia reservar una cancha a cualquier hora,
-- incluso fuera del horario que el club configurara, y en fechas que el club
-- hubiera bloqueado (mantenimiento, torneo privado, etc.).
--
-- La proteccion contra doble-reserva/sobrecupo (capacity) YA EXISTE desde
-- antes via los triggers booking_conflict_guard / trg_enforce_booking_capacity
-- (funciones check_booking_conflict / enforce_booking_capacity) -- esta
-- migracion NO la toca, solo agrega las dos piezas que faltaban.
--
-- Verificado con BEGIN...ROLLBACK contra un snapshot de produccion:
--   1) reserva valida dentro de horario -> succeeds
--   2) reserva fuera de horario (mismo dia)            -> OUTSIDE_AVAILABILITY_HOURS
--   3) reserva que cruza parcialmente el cierre         -> OUTSIDE_AVAILABILITY_HOURS
--   4) reserva que se solapa con un blackout            -> BOOKABLE_BLACKED_OUT
--   5) doble-reserva sobre cupo ya tomado                -> BOOKING_CAPACITY_EXCEEDED (trigger existente)
--   6) bookable_entity SIN reglas configuradas           -> sigue funcionando igual que hoy (retro-compatible)

create or replace function public.check_booking_availability_hours()
returns trigger
language plpgsql
-- SECURITY DEFINER: booking_blackouts solo es legible por el dueño del club (RLS). Sin esto,
-- una reserva hecha con permisos del jugador veria 0 bloqueos y se saltaria la validacion.
-- La funcion solo LEE esas tablas; search_path fijo.
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_rule_count integer;
  v_matched boolean := false;
  r record;
  v_tz text;
  v_local_start timestamp;
  v_local_end timestamp;
  v_local_date date;
  v_window_start timestamp;
  v_window_end timestamp;
begin
  -- Solo validar reservas que realmente ocupan el recurso.
  if new.status not in ('pending','confirmed') then
    return new;
  end if;

  -- Pasar de pending -> confirmed (p.ej. el webhook de Wompi al aprobar el pago) sin mover
  -- horario ni recurso NO se vuelve a validar: si el club agrega un bloqueo o cambia el
  -- horario despues de que el jugador reservo, un pago ya hecho no puede fallar al guardarse.
  if tg_op = 'UPDATE'
     and old.status in ('pending','confirmed')
     and new.bookable_id = old.bookable_id
     and new.starts_at = old.starts_at
     and new.ends_at = old.ends_at then
    return new;
  end if;

  select count(*) into v_rule_count
  from public.booking_availability_rules
  where bookable_id = new.bookable_id;

  -- Si el club no configuro ningun horario para este recurso, no restringimos
  -- nada (retro-compatible con todos los clubes/canchas existentes hoy).
  if v_rule_count = 0 then
    return new;
  end if;

  for r in
    select rule.start_time, rule.end_time, rule.timezone, rule.day_of_week, rule.valid_from, rule.valid_until
    from public.booking_availability_rules rule
    where rule.bookable_id = new.bookable_id
      and rule.is_available = true
  loop
    v_tz := coalesce(r.timezone, 'America/Bogota');
    v_local_start := new.starts_at at time zone v_tz;
    v_local_end := new.ends_at at time zone v_tz;
    v_local_date := v_local_start::date;

    if r.day_of_week is not null and r.day_of_week <> extract(dow from v_local_start) then
      continue;
    end if;
    if r.valid_from is not null and v_local_date < r.valid_from then
      continue;
    end if;
    if r.valid_until is not null and v_local_date > r.valid_until then
      continue;
    end if;

    if r.start_time is null and r.end_time is null then
      v_matched := true;
      exit;
    end if;

    v_window_start := v_local_date + coalesce(r.start_time, time '00:00');

    -- La tabla exige end_time > start_time cuando ambos existen, asi que hoy
    -- no hay horarios "que cruzan medianoche" configurables -- pero una
    -- RESERVA si puede cruzar medianoche (ej: 23:00 a 00:00). Por eso
    -- comparamos con marcas de tiempo completas (fecha+hora), no solo horas,
    -- para no fallar ese caso por error.
    if r.end_time is not null and r.start_time is not null and r.end_time <= r.start_time then
      v_window_end := (v_local_date + 1) + r.end_time;
    elsif r.end_time is not null then
      v_window_end := v_local_date + r.end_time;
    else
      v_window_end := v_local_date + 1;
    end if;

    if v_local_start >= v_window_start and v_local_end <= v_window_end then
      v_matched := true;
      exit;
    end if;
  end loop;

  if not v_matched then
    raise exception 'OUTSIDE_AVAILABILITY_HOURS';
  end if;

  return new;
end;
$function$;

create or replace function public.check_booking_blackout()
returns trigger
language plpgsql
-- SECURITY DEFINER: booking_blackouts solo es legible por el dueño del club (RLS). Sin esto,
-- una reserva hecha con permisos del jugador veria 0 bloqueos y se saltaria la validacion.
-- La funcion solo LEE esas tablas; search_path fijo.
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_blackout_count integer;
begin
  if new.status not in ('pending','confirmed') then
    return new;
  end if;

  -- Mismo criterio que check_booking_availability_hours (pending -> confirmed no revalida).
  if tg_op = 'UPDATE'
     and old.status in ('pending','confirmed')
     and new.bookable_id = old.bookable_id
     and new.starts_at = old.starts_at
     and new.ends_at = old.ends_at then
    return new;
  end if;

  select count(*) into v_blackout_count
  from public.booking_blackouts b
  where b.bookable_id = new.bookable_id
    and tstzrange(b.starts_at, b.ends_at, '[)') && tstzrange(new.starts_at, new.ends_at, '[)');

  if v_blackout_count > 0 then
    raise exception 'BOOKABLE_BLACKED_OUT';
  end if;

  return new;
end;
$function$;

drop trigger if exists booking_availability_hours_guard on public.bookings;
create trigger booking_availability_hours_guard
  before insert or update of bookable_id, starts_at, ends_at, status on public.bookings
  for each row execute function public.check_booking_availability_hours();

drop trigger if exists booking_blackout_guard on public.bookings;
create trigger booking_blackout_guard
  before insert or update of bookable_id, starts_at, ends_at, status on public.bookings
  for each row execute function public.check_booking_blackout();

revoke all on function public.check_booking_availability_hours() from public, anon, authenticated;
revoke all on function public.check_booking_blackout() from public, anon, authenticated;
