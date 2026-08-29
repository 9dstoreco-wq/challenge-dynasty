export const dynamic = 'force-dynamic'

import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'

export default async function CompetitionsPage() {
  const supabase = createClient()
  const { data: tournamentsData } = await supabase
    .from('tournaments')
    .select('id,title,status,starts_at,ends_at,organization_id')
    .order('starts_at', { ascending: true })
    .limit(50)
  const tournaments = tournamentsData ?? []

  return (
    <div className="min-h-screen bg-[#0B0F19] text-white grid-bg">
      <Sidebar />
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="max-w-6xl mx-auto px-4 md:px-6 py-8">
          <div className="text-xs tracking-[.3em] text-[#00F0FF] font-black">TOURNAMENT OS</div>
          <h1 className="text-4xl md:text-6xl font-black mt-2">COMPETICIONES</h1>
          <p className="text-white/50 mt-2">
            Torneos reales de Supabase, listos para evolucionar hacia cuadros, grupos, fixtures y programación.
          </p>

          <div className="grid md:grid-cols-2 gap-4 mt-7">
            {tournaments.map((t: any) => (
              <a
                key={t.id}
                href={`/competitions/${t.id}`}
                className="rounded-3xl border border-white/10 bg-[#141B2D] p-6 block hover:border-[#00F0FF]/30"
              >
                <div className="text-xs text-[#FFD700] font-black uppercase tracking-widest">{t.status}</div>
                <h2 className="text-xl font-black mt-2">{t.title}</h2>
                <p className="text-white/40 text-sm mt-2">
                  {t.starts_at || 'Fecha por definir'}
                  {t.ends_at ? ` → ${t.ends_at}` : ''}
                </p>
              </a>
            ))}

            {tournaments.length === 0 && (
              <div className="md:col-span-2 rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-8 text-center text-white/45">
                No hay torneos creados todavía. La infraestructura Tournament OS sí existe en Supabase.
              </div>
            )}
          </div>
        </div>
      </main>
      <BottomNav />
    </div>
  )
}

