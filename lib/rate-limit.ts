import type { SupabaseClient } from '@supabase/supabase-js'

// Envoltorio de la funcion check_rate_limit (migracion 20261007200000_rate_limiting.sql).
// Si esa migracion todavia no se aplico en este entorno (la funcion no existe todavia), la
// llamada a rpc() falla con un error -- en ese caso se deja pasar en vez de romper la accion
// entera por un limite que ni siquiera existe aun.
export async function checkRateLimit(
  supabase: SupabaseClient,
  bucket: string,
  maxHits: number,
  windowSeconds: number,
): Promise<boolean> {
  const { data, error } = await supabase.rpc('check_rate_limit', {
    p_bucket: bucket,
    p_max_hits: maxHits,
    p_window_seconds: windowSeconds,
  })
  if (error) return true
  return data !== false
}
