// Registro de errores del servidor en la base de datos -- antes no habia ningun registro (ni
// Sentry ni equivalente), solo console.error en logs que se pierden. Esto escribe en la tabla
// error_logs via la funcion SECURITY DEFINER log_error_event (migracion
// supabase/migrations/20261008000000_error_logging.sql), que cualquiera puede llamar pero nadie
// puede leer ni actualizar directo -- solo sirve para anotar, nunca para exponer datos.
//
// Nunca usa el cliente normal de Supabase (ese depende de cookies de sesion, que no existen en el
// hook de instrumentation.ts ni tienen por que existir para poder registrar un error). Llama
// directo al endpoint REST de la funcion con fetch, con un limite de tiempo corto, y nunca lanza:
// si el registro falla, el error original sigue su curso igual que antes.
import { requirePublicSupabaseEnv } from './supabase/env'

export async function logServerError(input: {
  route?: string
  method?: string
  message: string
  stack?: string
  context?: Record<string, unknown>
}): Promise<void> {
  try {
    const { url, key } = requirePublicSupabaseEnv()
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 2000)
    try {
      await fetch(`${url}/rest/v1/rpc/log_error_event`, {
        method: 'POST',
        headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          p_route: input.route ?? null,
          p_method: input.method ?? null,
          p_message: input.message.slice(0, 4000),
          p_stack: input.stack ? input.stack.slice(0, 4000) : null,
          p_context: input.context ?? {},
        }),
        signal: controller.signal,
      })
    } finally {
      clearTimeout(timeout)
    }
  } catch {
    // Registrar el error nunca debe generar un segundo error -- se descarta en silencio.
  }
}
