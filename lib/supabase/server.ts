import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import { requirePublicSupabaseEnv } from './env'

export function createClient() {
  const cookieStore = cookies()
  const { url, key } = requirePublicSupabaseEnv()
  return createServerClient(
    url,
    key,
    {
      cookies: {
        getAll() { return cookieStore.getAll() },
        setAll(cookiesToSet) {
          try { cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options)) } catch {}
        },
      },
    },
  )
}
