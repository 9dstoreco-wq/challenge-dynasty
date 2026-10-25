import type { SupabaseClient } from '@supabase/supabase-js'

// Envoltorio de la funcion check_rate_limit_for_action (migracion
// 20261014000000_fix_rate_limit_identity_binding.sql, reemplaza a check_rate_limit -- F08
// de Auditoria_Challenge_Dynasty_2026-10-12.md).
//
// La funcion vieja check_rate_limit() recibia el "bucket" (a quien se le aplica el limite)
// como un string de texto armado por el llamador -- y tenia EXECUTE otorgado a
// anon/authenticated, asi que cualquiera podia llamarla directo via la Data API de Supabase
// con el bucket de otra persona (DoS dirigido) o con limites absurdos (agotamiento de
// recursos). La funcion nueva ya no recibe un bucket armado a mano: recibe la accion
// (p.ej. "create_challenge") y deriva la identidad real DENTRO de la base de datos, a
// partir de auth.uid() -- el JWT que PostgREST ya verifico, no un valor que el cliente
// pueda falsificar. El parametro anonKey es solo para rutas sin sesion (ver
// app/api/cards/[profileId]/route.tsx): es best-effort y falsificable, igual que
// cualquier limitador basado en IP -- no es una garantia de identidad.
//
// Si la migracion todavia no se aplico en este entorno (la funcion no existe todavia), la
// llamada a rpc() falla con el error de Postgres 42883 (undefined_function) -- en ese caso
// especifico se deja pasar, para no romper la accion entera por un limite que ni siquiera
// existe aun. Cualquier OTRO error (timeout, base de datos caida, tabla de rate-limit con
// problemas, etc.) ahora bloquea la accion en vez de dejarla pasar -- antes, cualquier error
// de la llamada rpc() dejaba pasar sin distincion, lo cual anulaba el limite de intentos en
// /api/checkout/wompi (endpoint de pagos) justo durante una falla, que es cuando mas importa
// que el limite siga activo.
export async function checkRateLimit(
  supabase: SupabaseClient,
  action: string,
  maxHits: number,
  windowSeconds: number,
  anonKey?: string,
): Promise<boolean> {
  const { data, error } = await supabase.rpc('check_rate_limit_for_action', {
    p_action: action,
    p_max_hits: maxHits,
    p_window_seconds: windowSeconds,
    p_anon_key: anonKey ?? null,
  })
  if (error) {
    if (error.code === '42883') return true // funcion no existe aun (migracion pendiente)
    return false // cualquier otro error: bloquear por seguridad, no dejar pasar
  }
  return data !== false
}
