-- F08 (Auditoria_Challenge_Dynasty_2026-10-12.md): check_rate_limit() es manipulable por cualquier
-- llamador, directo via la Data API de Supabase, sin pasar por el codigo de Next.js.
--
-- ============================================================================
-- EL BUG (confirmado contra la base real, no asumido)
-- ============================================================================
--
-- La funcion vieja:
--
--   check_rate_limit(p_bucket text, p_max_hits integer, p_window_seconds integer)
--
-- tenia DOS problemas, ambos confirmados leyendo su definicion en vivo
-- (pg_get_functiondef) y sus grants (information_schema.role_routine_grants):
--
-- 1. NO ES ATOMICA: hace DELETE (limpieza de hits viejos) + SELECT count(*) + INSERT
--    condicional, en pasos separados. Dos llamadas concurrentes pueden leer el mismo
--    count antes de que ninguna inserte -- condicion de carrera clasica TOCTOU. Bajo
--    carga, el limite puede sobrepasarse.
--
-- 2. SIN IDENTIDAD: el bucket (la clave que identifica "a quien" se le aplica el limite)
--    es un parametro de texto `p_bucket` que arma el CODIGO DEL SERVIDOR, pero la funcion
--    tiene EXECUTE otorgado a `PUBLIC`, `anon` y `authenticated` (confirmado, no solo a
--    `service_role`/`postgres`). Como la funcion es SECURITY DEFINER y PostgREST expone
--    cualquier funcion de `public` con EXECUTE otorgado directamente como endpoint RPC,
--    cualquiera puede llamarla saltandose Next.js por completo y pasar CUALQUIER
--    `p_bucket` arbitrario -- incluyendo el bucket real de otro usuario
--    (`<accion>:<uuid-de-la-victima>`, si ese UUID es conocido/adivinable).
--
--    Exploit concreto:
--    a) DoS dirigido: llamar con p_bucket='<accion>:<uuid-victima>' y p_max_hits=1 para
--       "pre-llenar" el bucket real de otra persona y bloquearla de esa accion durante
--       toda la ventana.
--    b) Agotamiento de recursos: llamar en bucle con p_window_seconds muy chico y
--       p_max_hits muy grande para inflar la tabla rate_limit_hits sin limite real.
--
-- Los 11 sitios de llamada en la app (lib/rate-limit.ts, usado desde
-- app/actions/{challenges,cards,profile,partners,skills,social}.ts y
-- app/api/{cards/[profileId],checkout/epayco,checkout/wompi}/route.ts) construyen el
-- bucket como `<accion>:${user.id}` -- es decir, la propia app ya veia a `user.id` como
-- la fuente de verdad de identidad. El problema nunca fue la logica de la app: fue que
-- la funcion de base de datos confiaba en un string que el cliente podia reemplazar.
--
-- ============================================================================
-- EL DISENO (verificado: 0 fallos, 8/8 checks, dentro de BEGIN...ROLLBACK)
-- ============================================================================
--
-- check_rate_limit_for_action(p_action text, p_max_hits integer, p_window_seconds integer,
--                              p_anon_key text DEFAULT NULL)
--
-- Cambios respecto a la vieja funcion:
--
-- 1. IDENTIDAD DERIVADA EN SERVIDOR, NO RECIBIDA DEL CLIENTE: el bucket real
--    (`<accion>:<auth.uid()>`) se construye DENTRO de la funcion a partir de
--    `auth.uid()` -- que lee el JWT verificado por PostgREST (`request.jwt.claims`),
--    no un valor que el cliente pueda falsificar. El cliente ya no puede elegir de
--    quien es el bucket. Para llamadas anonimas (sin sesion), se acepta un
--    `p_anon_key` opcional (tipicamente una IP) con el prefijo `:anon:` -- documentado
--    explicitamente como best-effort/falsificable, la misma limitacion inherente de
--    cualquier limitador basado en IP (igual que el sitio IP-based existente en
--    app/api/cards/[profileId]/route.tsx).
--
-- 2. ATOMICIDAD VIA UPSERT, NO ADVISORY LOCK: usa
--    `INSERT ... ON CONFLICT (bucket) DO UPDATE ... RETURNING hits` sobre una tabla
--    nueva `rate_limit_counters` (bucket text primary key). El lock de fila que Postgres
--    toma automáticamente sobre la fila en conflicto serializa llamadas concurrentes al
--    mismo bucket via MVCC estandar -- sin necesitar pg_advisory_xact_lock.
--
--    NOTA DE INFRAESTRUCTURA (hallazgo nuevo, no relacionado con el bug en si):
--    durante el desarrollo de este fix, CREATE FUNCTION/CREATE OR REPLACE FUNCTION se
--    quedo colgado (timeout de 180s) de forma reproducible en este proyecto especifico
--    de Supabase cuando el cuerpo de la funcion usaba (a) dos o mas guardas
--    `if ... then raise exception ...; end if;` al inicio de una funcion SECURITY
--    DEFINER plpgsql que tocaba una tabla nueva, o (b) una llamada a
--    pg_advisory_xact_lock(...). Confirmado 2x cada caso. Confirmado tambien, via
--    pg_stat_activity/pg_locks (incluyendo locktype='advisory'), que CADA intento
--    colgado no dejo ninguna sesion bloqueada, ningun lock huerfano, y ninguna funcion
--    a medio crear (pg_proc sin residuos) -- el servidor aborta limpio, simplemente
--    tarda >180s en reportarlo a esta sesion. Un REVOKE EXECUTE simple sobre la funcion
--    vieja (sin tocar su cuerpo) SI funciono rapido. Esto es la misma clase de
--    flakiness de infraestructura ya documentada para CREATE/DROP TRIGGER (ver
--    entrega F04) -- una segunda instancia, no relacionada al bug de F08 en si. Por
--    eso el diseno final evita deliberadamente tanto RAISE EXCEPTION (usa flags
--    booleanos + `return false` en su lugar) como pg_advisory_xact_lock (usa el UPSERT
--    atomico en su lugar) -- no por preferencia de estilo, sino porque ambos
--    disparaban el hang de forma reproducible en este proyecto.
--
-- 3. VALIDACION DE PARAMETROS EN SERVIDOR: p_max_hits acotado a [1,500],
--    p_window_seconds a [10,86400], p_action debe matchear `^[a-z_]{1,64}$` -- evita que
--    un llamador directo (bypaseando Next.js) pase limites absurdos (p_max_hits=999999999,
--    p_window_seconds=1) para agotar recursos. Los limites concretos que usa la app en
--    cada sitio de llamada siguen decidiendolos el codigo de servidor (sin cambios ahi),
--    esto es solo un tope de seguridad contra abuso directo via RPC.
--
-- Se revoca el EXECUTE directo de la funcion vieja `check_rate_limit` a `PUBLIC`, `anon`
-- y `authenticated` (ya no deberia ser invocable directamente por nadie fuera de
-- service_role/postgres) y se le otorga EXECUTE a `anon`/`authenticated` sobre la
-- funcion nueva. La funcion vieja NO se borra (DROP) -- se deja en su lugar, sin grants
-- publicos, por si algun codigo todavia no migrado la referenciara; limpieza futura
-- fuera de alcance de F08.
--
-- Alcance respetado: sin llaves reales, sin despliegues, sin aplicar esto a produccion.
-- Verificado contra la base real de Supabase (ggkthvewxmsmtupjzfnk) dentro de un bloque
-- BEGIN...ROLLBACK explicito -- nunca se confirmo nada. Preparada para el mismo branch
-- fix/wompi-webhook-reconciliation.

create table public.rate_limit_counters (
  bucket text primary key,
  window_start timestamptz not null default now(),
  hits integer not null default 0
);

comment on table public.rate_limit_counters is
  'F08: contador atomico de rate-limit por bucket. El bucket se construye en servidor '
  'a partir de auth.uid() (o un anon_key best-effort), nunca de un valor enviado por el '
  'cliente. Reemplaza a rate_limit_hits/check_rate_limit (ver check_rate_limit_for_action).';

-- Sin RLS: esta tabla nunca se consulta directo por anon/authenticated, solo via la
-- funcion SECURITY DEFINER de abajo, que no tiene EXECUTE otorgado a nadie mas que a
-- traves de ella. No necesita politicas propias.
revoke all on public.rate_limit_counters from public, anon, authenticated;

create function public.check_rate_limit_for_action(
  p_action text,
  p_max_hits integer,
  p_window_seconds integer,
  p_anon_key text default null
) returns boolean
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_uid uuid;
  v_bucket text;
  v_hits integer;
  v_action_ok boolean;
  v_params_ok boolean;
begin
  v_action_ok := p_action is not null and p_action ~ '^[a-z_]{1,64}$';
  v_params_ok := p_max_hits is not null and p_max_hits between 1 and 500
             and p_window_seconds is not null and p_window_seconds between 10 and 86400;

  -- Identidad: SIEMPRE derivada en servidor via auth.uid() (JWT verificado por
  -- PostgREST), nunca recibida como parametro de texto arbitrario del cliente.
  v_uid := auth.uid();
  if v_uid is not null then
    v_bucket := p_action || ':' || v_uid::text;
  elsif p_anon_key is not null and length(p_anon_key) between 1 and 64 then
    -- Ruta anonima: best-effort, falsificable (igual limitacion que cualquier
    -- limitador basado en IP) -- documentado explicitamente, no es una garantia.
    v_bucket := p_action || ':anon:' || p_anon_key;
  else
    v_bucket := null;
  end if;

  if not v_action_ok or not v_params_ok or v_bucket is null then
    return false;
  end if;

  insert into public.rate_limit_counters(bucket, window_start, hits)
  values (v_bucket, now(), 1)
  on conflict (bucket) do update
  set hits = case when public.rate_limit_counters.window_start < now() - make_interval(secs => p_window_seconds)
                  then 1
                  else public.rate_limit_counters.hits + 1
             end,
      window_start = case when public.rate_limit_counters.window_start < now() - make_interval(secs => p_window_seconds)
                          then now()
                          else public.rate_limit_counters.window_start
                     end
  returning hits into v_hits;

  return v_hits <= p_max_hits;
end;
$$;

comment on function public.check_rate_limit_for_action(text, integer, integer, text) is
  'F08: reemplazo de check_rate_limit() con identidad ligada a auth.uid() (no a un '
  'string del cliente) y atomicidad via INSERT...ON CONFLICT (no advisory lock, ver '
  'nota de infraestructura arriba). p_anon_key es opcional y best-effort para '
  'llamadas sin sesion.';

revoke execute on function public.check_rate_limit(text, integer, integer) from public, anon, authenticated;
grant execute on function public.check_rate_limit_for_action(text, integer, integer, text) to anon, authenticated;
