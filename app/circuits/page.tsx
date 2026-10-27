export const dynamic = 'force-dynamic'

import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'
import CircuitCreateForm from '@/components/CircuitCreateForm'

type Circuit = {
  id: string
  name: string
  category_label: string | null
  status: string
  season_starts_at: string | null
  season_ends_at: string | null
}

export default async function CircuitsPage() {
  const supabase = await createClient()
  const t = await getTranslations('Circuits')
  const { data: { user } } = await supabase.auth.getUser()
  const { data: circuitsData } = await supabase
    .from('tournament_circuits')
    .select('id,name,category_label,status,season_starts_at,season_ends_at')
    .order('created_at', { ascending: false })
    .limit(50)
    .returns<Circuit[]>()
  const circuits = circuitsData ?? []

  return (
    <div className="min-h-screen arena-bg text-white ">
      <Sidebar />
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="max-w-6xl mx-auto px-4 md:px-6 py-8">
          <PageHero>
            <div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">{t('tag')}</div>
            <h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{t('title')}</h1>
            <p className="text-white/50 mt-2">{t('subtitle')}</p>
          </PageHero>

          <div className="grid md:grid-cols-2 gap-4 mt-7">
            {circuits.map((c) => (
              <a
                key={c.id}
                href={`/circuits/${c.id}`}
                className="card-fut-plain border border-white/10 bg-[#141416] p-6 block hover:border-[#D4AF37]/30"
              >
                <div className="text-xs text-[#D4AF37] font-black uppercase tracking-widest">{c.status}</div>
                <h2 className="text-xl font-black mt-2">{c.name}</h2>
                {c.category_label && <p className="text-white/50 text-sm mt-1">{c.category_label}</p>}
                <p className="text-white/40 text-sm mt-2">
                  {c.season_starts_at || t('noSeasonDates')}
                  {c.season_ends_at ? ` → ${c.season_ends_at}` : ''}
                </p>
              </a>
            ))}

            {circuits.length === 0 && (
              <div className="md:col-span-2 rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-8 text-center text-white/45">
                {t('empty')}
              </div>
            )}
          </div>

          {user ? (
            <CircuitCreateForm />
          ) : (
            <div className="mt-7 rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-6 text-center text-white/45">
              {t('loginToCreate')}
            </div>
          )}
        </div>
      </main>
      <BottomNav />
    </div>
  )
}
