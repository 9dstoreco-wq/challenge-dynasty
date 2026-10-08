// Gancho oficial de Next.js para registrar errores del servidor (Server Components, Route
// Handlers y Server Actions) sin tener que tocar cada archivo uno por uno. Antes no habia ningun
// registro de errores en la app (ni Sentry ni equivalente) -- solo quedaban en los logs de Vercel,
// que no son faciles de revisar para alguien no tecnico. Esto los anota tambien en la base de
// datos (tabla error_logs, ver supabase/migrations/20261008000000_error_logging.sql) para poder
// verlos desde /health.
//
// register() es obligatorio para que Next.js cargue este archivo; aqui no hay nada que inicializar.
export async function register() {}

export async function onRequestError(
  err: unknown,
  request: { path?: string; method?: string },
  context: { routerKind?: string; routeType?: string }
) {
  // Import perezoso: evita que este modulo (y lo que importa) se incluya en el bundle hasta que
  // realmente ocurra un error.
  const { logServerError } = await import('./lib/log-error')
  const message = err instanceof Error ? err.message : typeof err === 'string' ? err : 'Error desconocido'
  const stack = err instanceof Error ? err.stack : undefined
  await logServerError({
    route: request?.path,
    method: request?.method,
    message,
    stack,
    context: { routerKind: context?.routerKind, routeType: context?.routeType },
  })
}
