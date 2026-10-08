-- Challenge Dynasty -- registro de errores del servidor (no habia ninguno: ni Sentry ni
-- equivalente, solo console.error que se pierde en los logs de Vercel).
-- ESTADO: ESCRITA, NO APLICADA. El sistema de permisos bloqueo aplicarla desde Claude porque es
-- un deploy a produccion sin revision humana; la corre Luis en el editor SQL de Supabase.
--
-- QUE HACE ESTE ARCHIVO:
-- 1. Tabla error_logs: una fila por error de servidor (ruta, metodo, mensaje, stack, contexto).
--    RLS activado y SIN policies -- nadie puede leer ni escribir esta tabla directo desde el
--    cliente (ni con la llave publica ni logueado); solo se escribe a traves de la funcion de
--    abajo, y solo se lee desde el editor SQL de Supabase (Luis) o un dashboard interno futuro.
-- 2. Funcion log_error_event(): SECURITY DEFINER, para que la app pueda anotar un error aunque
--    quien hace la solicitud no tenga sesion (un error puede pasar antes de que alguien inicie
--    sesion). Nunca lanza su propio error -- si algo falla al escribir, se descarta en silencio
--    para no generar un segundo error por intentar registrar el primero. Se le puede llamar desde
--    el cliente (anon) porque instrumentation.ts corre en el servidor de la app, no en el
--    navegador del usuario, pero la llamada en si usa la llave publica igual que cualquier otra
--    consulta de esta app.
--
-- COMO VERLO: en el editor SQL de Supabase, "select * from error_logs order by created_at desc
-- limit 50;". La pagina /health de la app solo revisa que la base de datos responda -- no muestra
-- el contenido de esta tabla (evita exponer detalles tecnicos en una pagina publica).

create table if not exists public.error_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  route text,
  method text,
  message text not null,
  stack text,
  context jsonb not null default '{}'::jsonb
);

alter table public.error_logs enable row level security;
-- Sin policies a proposito: ni lectura ni escritura directa. Solo la funcion SECURITY DEFINER
-- de abajo puede insertar.

create or replace function public.log_error_event(
  p_route text,
  p_method text,
  p_message text,
  p_stack text,
  p_context jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.error_logs(route, method, message, stack, context)
  values (p_route, p_method, left(coalesce(p_message, ''), 4000), left(coalesce(p_stack, ''), 4000), coalesce(p_context, '{}'::jsonb));
exception when others then
  -- Registrar un error nunca debe producir un segundo error.
  null;
end;
$$;

grant execute on function public.log_error_event(text, text, text, text, jsonb) to anon, authenticated;

-- Limpieza automatica: borra registros de mas de 90 dias cada semana, para que la tabla no crezca
-- sin limite (sigue el mismo patron que los demas cron jobs de este proyecto).
select cron.unschedule(jobid) from cron.job where jobname = 'prune_old_error_logs';
select cron.schedule(
  'prune_old_error_logs',
  '0 4 * * 0',
  $cron$delete from public.error_logs where created_at < now() - interval '90 days'$cron$
);
