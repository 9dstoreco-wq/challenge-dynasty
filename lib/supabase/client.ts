import { createBrowserClient } from '@supabase/ssr'
import { requirePublicSupabaseEnv } from './env'

export function createClient() {
  const { url, key } = requirePublicSupabaseEnv()
  return createBrowserClient(url, key)
}
