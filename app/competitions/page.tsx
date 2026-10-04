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
  const tournaments = tournamentsData ?? []

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
                className="card-fut-plain border border-white/10 bg-[#141416] p-6 block hover:border-[#D4AF37]/30"
              >
                <div className="text-xs text-[#D4AF37] font-black uppercase tracking-widest">{t2.status}</div>
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
