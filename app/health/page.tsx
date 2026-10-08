import { createClient } from '@/lib/supabase/server'
import { getTranslations } from 'next-intl/server'
import { toSafeMessage } from '@/lib/safe-error'

export const dynamic = 'force-dynamic'

// Pagina de salud, publica: para que Luis (no tecnico) pueda abrir una sola direccion y ver de un
// vistazo si la base de datos responde, en vez de tener que revisar logs de Vercel o Supabase. No
// muestra el contenido de error_logs (eso se revisa en el editor SQL de Supabase) -- solo si la
// conexion funciona, cuanto tarda, y que version del codigo esta corriendo. Al ser publica (sin
// sesion), el detalle de un fallo pasa por toSafeMessage igual que cualquier otra pantalla -- nunca
// el texto crudo de Postgres.
async function checkDatabase(): Promise<{ ok: boolean; latencyMs: number; detail?: string }> {
  const start = Date.now()
  try {
    const supabase = await createClient()
    const { error } = await supabase.from('sports').select('id').limit(1)
    const latencyMs = Date.now() - start
    if (error) return { ok: false, latencyMs, detail: toSafeMessage(error, 'health.database') }
    return { ok: true, latencyMs }
  } catch (e) {
    return { ok: false, latencyMs: Date.now() - start, detail: toSafeMessage(e, 'health.database') }
  }
}

export default async function HealthPage() {
  const t = await getTranslations('Health')
  const db = await checkDatabase()
  const commit = process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7)
  const env = process.env.VERCEL_ENV ?? 'development'
  const checkedAt = new Date().toLocaleString('es-CO')

  const allOk = db.ok
  const dbDetail = db.ok ? t('latency', { ms: db.latencyMs }) : db.detail

  return (
    <main className="min-h-screen arena-bg text-white p-6">
      <section className="w-full max-w-xl mx-auto card-fut-plain border border-white/10 bg-[#141416] p-8">
        <div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">CHALLENGE DYNASTY</div>
        <h1 className="text-3xl font-black mt-2">{t('title')}</h1>
        <div className={`mt-4 rounded-xl px-4 py-3 font-black text-center ${allOk ? 'bg-[#00E676]/15 text-[#00E676]' : 'bg-red-500/15 text-red-300'}`}>
          {allOk ? t('allOk') : t('someFail')}
        </div>
        <div className="mt-5 grid gap-3">
          <div className="flex items-center justify-between gap-4 rounded-xl border border-white/10 bg-white/5 px-4 py-3">
            <div>
              <div className="font-bold">{t('database')}</div>
              {dbDetail && <div className="text-xs text-white/40 mt-1">{dbDetail}</div>}
            </div>
            <div className={`rounded-full px-3 py-1 text-xs font-black ${db.ok ? 'bg-[#00E676]/15 text-[#00E676]' : 'bg-red-500/15 text-red-300'}`}>
              {db.ok ? t('ok') : t('fail')}
            </div>
          </div>
        </div>
        <div className="mt-6 text-xs text-white/35 space-y-1">
          <div>{t('checkedAt', { date: checkedAt })}</div>
          <div>{t('environment', { env })}</div>
          {commit && <div>{t('version', { commit })}</div>}
        </div>
      </section>
    </main>
  )
}
