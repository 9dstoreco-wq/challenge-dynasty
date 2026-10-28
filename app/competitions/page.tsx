export const dynamic = 'force-dynamic'

import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'
import Link from 'next/link'

export default async function CompetitionsPage() {
  const supabase = await createClient()
  const t = await getTranslations('Competitions')
  const { data: tournamentsData } = await supabase
    .from('tournaments')
    .select('id,title,status,starts_at,ends_at,organization_id')
    .order('starts_at', { ascending: true })
    .limit(50)
  const rawTournaments = tournamentsData ?? []

  // "Destacado"/"Boost" (app/promote): torneos con una ventana activa en tournament_promotions
  // van primero -- destacado antes que boost -- y el resto mantiene el orden por fecha de
  // siempre. Ver supabase/migrations/20261028190000_add_tournament_promotions.sql.
  const tournamentIds = rawTournaments.map((tr) => tr.id)
  const { data: activePromoRows } = tournamentIds.length
    ? await supabase
        .from('tournament_promotions')
        .select('tournament_id,package_code')
        .in('tournament_id', tournamentIds)
        .eq('status', 'active')
        .gt('ends_at', new Date().toISOString())
    : { data: [] }
  const promoWeight = new Map<string, number>()
  for (const row of activePromoRows ?? []) {
    const weight = row.package_code === 'tournament_promo_destacado' ? 2 : 1
    const prev = promoWeight.get(row.tournament_id as string) ?? 0
    if (weight > prev) promoWeight.set(row.tournament_id as string, weight)
  }
  const tournaments = [...rawTournaments].sort((a, b) => {
    const wa = promoWeight.get(a.id) ?? 0
    const wb = promoWeight.get(b.id) ?? 0
    if (wa !== wb) return wb - wa
    return 0 // conserva el orden relativo por starts_at que ya trajo la query
  })

  return (
    <div className="min-h-screen arena-bg text-white ">
      <Sidebar />
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="max-w-6xl mx-auto px-4 md:px-6 py-8">
          <PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">{t('tag')}</div>
          <h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{t('title')}</h1>
          <p className="text-white/50 mt-2">
            {t('subtitle')}
          </p>
          <Link href="/competitions/organize" className="inline-flex mt-5 rounded-xl bg-[#D4AF37] text-black px-5 py-3 font-black">{t('organizeCta')}</Link>
          </PageHero>

          <div className="grid md:grid-cols-2 gap-4 mt-7">
            {tournaments.map((t2: {id:string;title:string;status:string;starts_at:string|null;ends_at:string|null}) => (
              <a
                key={t2.id}
                href={`/competitions/${t2.id}`}
                className={`card-fut-plain border p-6 block hover:border-[#D4AF37]/30 ${
                  (promoWeight.get(t2.id) ?? 0) > 0 ? 'border-[#D4AF37]/50 bg-[#1a1710]' : 'border-white/10 bg-[#141416]'
                }`}
              >
                <div className="flex items-center justify-between gap-2">
                  <div className="text-xs text-[#D4AF37] font-black uppercase tracking-widest">{t2.status}</div>
                  {(promoWeight.get(t2.id) ?? 0) === 2 && (
                    <span className="text-[10px] font-black uppercase tracking-widest text-black bg-[#D4AF37] rounded-full px-2 py-0.5">{t('featuredBadge')}</span>
                  )}
                  {(promoWeight.get(t2.id) ?? 0) === 1 && (
                    <span className="text-[10px] font-black uppercase tracking-widest text-[#D4AF37] border border-[#D4AF37]/50 rounded-full px-2 py-0.5">{t('boostBadge')}</span>
                  )}
                </div>
                <h2 className="text-xl font-black mt-2">{t2.title}</h2>
                <p className="text-white/40 text-sm mt-2">
                  {t2.starts_at || t('dateTBD')}
                  {t2.ends_at ? ` → ${t2.ends_at}` : ''}
                </p>
              </a>
            ))}

            {tournaments.length === 0 && (
              <div className="md:col-span-2 rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-8 text-center text-white/45">
                {t('empty')}
              </div>
            )}
          </div>
        </div>
      </main>
      <BottomNav />
    </div>
  )
}
