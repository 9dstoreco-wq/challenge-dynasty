-- Challenge Dynasty -- limite de intentos (rate limiting) basico para las acciones mas sensibles
-- a abuso: crear retos, publicaciones, reportes, e imagen de carta.
-- ESTADO: ESCRITA, NO APLICADA. El sistema de permisos bloqueo aplicarla desde Claude porque es
-- un deploy a produccion sin revision humana; la corre Luis en el editor SQL de Supabase.
--
-- QUE PASABA: no habia ningun limite de cuantas veces se podia crear un reto, publicar, reportar
-- contenido o pedir la imagen de una carta -- solo el endpoint de la IA tenia un limite (20 por
-- minuto). Alguien podia automatizar miles de solicitudes por minuto a cualquiera de esas acciones.
--
-- Nota sobre login y registro: esos dos pasan directo del navegador al sistema de autenticacion de
-- Supabase (no por una accion del servidor de esta app), y Supabase ya aplica sus propios limites
-- por defecto ahi (configurables en Supabase, Authentication > Rate Limits). Por eso esta migracion
-- se enfoca en las acciones que SI viven en el codigo de esta app y que no tenian ningun limite.
--
-- QUE HACE ESTE ARCHIVO:
-- 1) Crea una tabla generica de "golpes" (hits) por bucket (ej. "create_challenge:<uuid-usuario>"
--    o "card_image:<ip>"), con RLS activado y SIN ninguna policy -- asi ni siquiera el dueño de una
--    fila (si la tuviera) podria leerla o escribirla directo por la API; solo la funcion de abajo.
-- 2) Crea la funcion check_rate_limit(bucket, max_hits, window_seconds): cuenta los golpes
--    recientes de ese bucket, y si ya se llego al maximo en la ventana de tiempo devuelve false
--    (sin registrar un golpe nuevo); si no, registra el golpe y devuelve true. Es la misma funcion
--    para cualquier accion -- cada accion solo le pasa un bucket, un maximo y una ventana distintos.
-- 3) De paso limpia los golpes mas viejos que la ventana usada, para que la tabla no crezca sin
--    control (no hace falta un cron aparte).

create table if not exists public.rate_limit_hits (
  id bigint generated always as identity primary key,
  bucket text not null,
  created_at timestamptz not null default now()
);

create index if not exists rate_limit_hits_bucket_created_idx
  on public.rate_limit_hits (bucket, created_at desc);

alter table public.rate_limit_hits enable row level security;
-- A proposito no se crea ninguna policy: con RLS activado y cero policies, nadie puede leer ni
-- escribir esta tabla directo por la API (ni con sesion, ni sin ella). Solo la entra la funcion de
-- abajo, que es SECURITY DEFINER y por eso se salta RLS.

create or replace function public.check_rate_limit(p_bucket text, p_max_hits int, p_window_seconds int)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
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
$function$;

-- "anon" tambien la necesita: la imagen de carta (/api/cards/...) se puede pedir sin sesion.
grant execute on function public.check_rate_limit(text, int, int) to authenticated, anon;
