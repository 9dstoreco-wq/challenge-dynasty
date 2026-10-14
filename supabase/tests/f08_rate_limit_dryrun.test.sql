-- F08 -- verificacion dry-run contra la base real de Supabase (ggkthvewxmsmtupjzfnk).
-- Todo dentro de BEGIN...ROLLBACK: nada de esto se confirma ni persiste.
-- Reproduce la migracion 20261014000000_fix_rate_limit_identity_binding.sql completa
-- (tabla + funcion + revoke + grant), simula dos usuarios reales via
-- SET LOCAL ROLE / SET LOCAL request.jwt.claims (el mismo mecanismo que usa
-- PostgREST por request), y corre 8 escenarios. Termina con RAISE EXCEPTION para
-- forzar el abort/rollback sin importar el resultado.

begin;

-- ---------------------------------------------------------------------------
-- 1. Reproducir la migracion completa (tabla + funcion + grants)
-- ---------------------------------------------------------------------------

create table public.rate_limit_counters (
  bucket text primary key,
  window_start timestamptz not null default now(),
  hits integer not null default 0
);

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

  v_uid := auth.uid();
  if v_uid is not null then
    v_bucket := p_action || ':' || v_uid::text;
  elsif p_anon_key is not null and length(p_anon_key) between 1 and 64 then
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

revoke execute on function public.check_rate_limit(text, integer, integer) from public, anon, authenticated;
grant execute on function public.check_rate_limit_for_action(text, integer, integer, text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Escenarios de prueba
-- ---------------------------------------------------------------------------

do $$
declare
  v_user_a uuid := gen_random_uuid();
  v_user_b uuid := gen_random_uuid();
  v_r boolean;
  v_fallos int := 0;
  v_msg text := '';
begin
  -- userA autenticado
  execute format('set local role authenticated');
  execute format('set local request.jwt.claims = %L', json_build_object('sub', v_user_a, 'role', 'authenticated')::text);

  -- 01: 1ra y 2da llamada de userA bajo limite 2 -> true, true; 3ra -> false
  perform public.check_rate_limit_for_action('test_action', 2, 60);
  perform public.check_rate_limit_for_action('test_action', 2, 60);
  v_r := public.check_rate_limit_for_action('test_action', 2, 60);
  if v_r = false then v_msg := v_msg || 'OK    01 3ra llamada de userA bajo limite 2 -> false' || E'\n';
  else v_fallos := v_fallos + 1; v_msg := v_msg || 'FALLO 01 3ra llamada de userA bajo limite 2 -> false' || E'\n'; end if;

  -- userB autenticado (bucket independiente, identidad = auth.uid())
  execute format('set local request.jwt.claims = %L', json_build_object('sub', v_user_b, 'role', 'authenticated')::text);
  v_r := public.check_rate_limit_for_action('test_action', 2, 60);
  if v_r = true then v_msg := v_msg || 'OK    02 userB bucket independiente (identidad = auth.uid())' || E'\n';
  else v_fallos := v_fallos + 1; v_msg := v_msg || 'FALLO 02 userB bucket independiente (identidad = auth.uid())' || E'\n'; end if;

  -- de vuelta a userA para el resto
  execute format('set local request.jwt.claims = %L', json_build_object('sub', v_user_a, 'role', 'authenticated')::text);

  -- 03: max_hits fuera de rango -> false, no revienta
  v_r := public.check_rate_limit_for_action('test_action_two', 9999, 60);
  if v_r = false then v_msg := v_msg || 'OK    03 max_hits fuera de rango -> false (no revienta)' || E'\n';
  else v_fallos := v_fallos + 1; v_msg := v_msg || 'FALLO 03 max_hits fuera de rango -> false (no revienta)' || E'\n'; end if;

  -- 04: window_seconds fuera de rango -> false
  v_r := public.check_rate_limit_for_action('test_action_two', 5, 1);
  if v_r = false then v_msg := v_msg || 'OK    04 window_seconds fuera de rango -> false' || E'\n';
  else v_fallos := v_fallos + 1; v_msg := v_msg || 'FALLO 04 window_seconds fuera de rango -> false' || E'\n'; end if;

  -- 05: nombre de accion invalido -> false
  v_r := public.check_rate_limit_for_action('Test-Action!', 5, 60);
  if v_r = false then v_msg := v_msg || 'OK    05 nombre de accion invalido -> false' || E'\n';
  else v_fallos := v_fallos + 1; v_msg := v_msg || 'FALLO 05 nombre de accion invalido -> false' || E'\n'; end if;

  -- anonimo: sin sesion
  execute format('set local role anon');
  execute format('set local request.jwt.claims = %L', json_build_object('role', 'anon')::text);

  -- 06: anonimo sin anon_key -> false (identidad requerida)
  v_r := public.check_rate_limit_for_action('test_action_three', 5, 60);
  if v_r = false then v_msg := v_msg || 'OK    06 anonimo sin anon_key -> false (identidad requerida)' || E'\n';
  else v_fallos := v_fallos + 1; v_msg := v_msg || 'FALLO 06 anonimo sin anon_key -> false (identidad requerida)' || E'\n'; end if;

  -- 07: ruta anonima con anon_key respeta su propio limite
  v_r := public.check_rate_limit_for_action('test_action_three', 1, 60, '203.0.113.5');
  if v_r = true then v_msg := v_msg || 'OK    07a ruta anonima con anon_key, 1ra llamada -> true' || E'\n';
  else v_fallos := v_fallos + 1; v_msg := v_msg || 'FALLO 07a ruta anonima con anon_key, 1ra llamada -> true' || E'\n'; end if;
  v_r := public.check_rate_limit_for_action('test_action_three', 1, 60, '203.0.113.5');
  if v_r = false then v_msg := v_msg || 'OK    07b ruta anonima con anon_key, 2da llamada sobre limite 1 -> false' || E'\n';
  else v_fallos := v_fallos + 1; v_msg := v_msg || 'FALLO 07b ruta anonima con anon_key, 2da llamada sobre limite 1 -> false' || E'\n'; end if;

  -- 08: authenticated ya NO puede ejecutar check_rate_limit() directamente
  execute format('set local role authenticated');
  execute format('set local request.jwt.claims = %L', json_build_object('sub', v_user_a, 'role', 'authenticated')::text);
  begin
    perform public.check_rate_limit('cualquier:bucket', 5, 60);
    v_fallos := v_fallos + 1;
    v_msg := v_msg || 'FALLO 08 authenticated ya NO puede ejecutar check_rate_limit() directamente' || E'\n';
  exception when insufficient_privilege then
    v_msg := v_msg || 'OK    08 authenticated ya NO puede ejecutar check_rate_limit() directamente' || E'\n';
  end;

  raise exception E'RESULTADOS F08 (% fallos)\n%', v_fallos, v_msg;
end $$;

rollback;
