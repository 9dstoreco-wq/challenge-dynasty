import { getDynastyAIContext } from '@/lib/dynasty/ai-context'

type Context = {
  profile_id?: string | null
  entitlements?: Array<{ feature_key?: string; feature_value?: unknown; ends_at?: string | null }>
  organizations?: Array<{ id?: string; name?: string; organization_type?: string; status?: string }>
  seller_profiles?: Array<{ id?: string; display_name?: string; seller_type?: string; premium_status?: string; status?: string }>
}

export default async function DynastyAIContextPanel({ area }: { area: string }) {
  let context: Context | null = null
  let authenticated = true
  try {
    context = (await getDynastyAIContext()) as Context
  } catch {
    authenticated = false
  }

  if (!authenticated) {
    return (
      <div className="mt-8 rounded-3xl border border-white/10 bg-white/5 p-6">
        <div className="font-black">{area}</div>
        <p className="mt-2 text-sm opacity-60">Inicia sesión para cargar tu contexto Dynasty.</p>
      </div>
    )
  }

  const entitlements = context?.entitlements ?? []
  const organizations = context?.organizations ?? []
  const sellers = context?.seller_profiles ?? []

  return (
    <div className="mt-8 grid gap-4 md:grid-cols-3">
      <div className="rounded-3xl border border-white/10 bg-white/5 p-6">
        <div className="text-xs font-black tracking-widest opacity-50">{area}</div>
        <div className="mt-3 text-3xl font-black">{entitlements.length}</div>
        <div className="mt-1 text-sm opacity-60">entitlements activos</div>
      </div>
      <div className="rounded-3xl border border-white/10 bg-white/5 p-6">
        <div className="text-xs font-black tracking-widest opacity-50">ORGANIZACIONES</div>
        <div className="mt-3 text-3xl font-black">{organizations.length}</div>
        <div className="mt-1 text-sm opacity-60">organizaciones accesibles</div>
      </div>
      <div className="rounded-3xl border border-white/10 bg-white/5 p-6">
        <div className="text-xs font-black tracking-widest opacity-50">SELLER PROFILES</div>
        <div className="mt-3 text-3xl font-black">{sellers.length}</div>
        <div className="mt-1 text-sm opacity-60">perfiles propios</div>
      </div>
    </div>
  )
}
