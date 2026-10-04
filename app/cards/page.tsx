export const dynamic = 'force-dynamic'
import Link from 'next/link'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import PageHero from '@/components/PageHero'
import CardShowcase from '@/components/CardShowcase'
import { createClient } from '@/lib/supabase/server'
import { getPlayerCards, getRecentTransfers } from '@/lib/dynasty/cards'
import { getTranslations } from 'next-intl/server'

export default async function CardsPage() {
  const supabase = await createClient()
  const t = await getTranslations('Cards')
  const tc = await getTranslations('Challenge')
  const { data: { user } } = await supabase.auth.getUser()

  const cards = user ? await getPlayerCards(supabase, user.id, tc('defaultPlayer')) : []
  const transfers = user ? await getRecentTransfers(supabase, user.id, tc('defaultPlayer')) : []

  return (
    <div className="min-h-screen arena-bg text-white">
      <Sidebar />
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="mx-auto max-w-6xl px-4 py-8 md:px-6">
          <PageHero>
            <div className="text-xs font-black tracking-[.3em] text-[#D4AF37]">{t('pageTag')}</div>
            <h1 className="mt-2 font-display text-5xl font-black tracking-wide md:text-7xl">{t('pageTitle')}</h1>
            <p className="mt-2 text-white/55">{t('pageSubtitle')}</p>
          </PageHero>

          {!user ? (
            <div className="card-fut-plain border border-white/10 bg-[#141416] p-8 text-center">
              <p className="text-white/60">{t('loginRequired')}</p>
              <Link href="/login" className="btn-gold mt-4">{t('loginBtn')}</Link>
            </div>
          ) : (
            <div className="space-y-10">
              <CardShowcase cards={cards} />
              <section>
                <div className="mb-3 font-display text-2xl tracking-wide">{t('historyTitle')}</div>
                {transfers.length === 0 ? (
                  <div className="card-fut-plain border border-dashed border-white/15 bg-white/[.02] p-6 text-white/45">{t('historyEmpty')}</div>
                ) : (
                  <div className="space-y-2">
                    {transfers.map((tr) => {
                      const won = tr.toId === user.id
                      const name = tr.card?.playerName ?? ''
                      return (
                        <div key={tr.id} className="card-fut-plain flex items-center justify-between gap-4 border border-white/10 bg-[#141416] px-5 py-3">
                          <div className="text-sm font-bold">{won ? t('historyWon', { name, rival: tr.fromName }) : t('historyLost', { name, rival: tr.toName })}</div>
                          <div className="shrink-0 text-xs text-white/35">{new Date(tr.createdAt).toLocaleDateString('es-CO')}</div>
                        </div>
                      )
                    })}
                  </div>
                )}
              </section>
            </div>
          )}
        </div>
      </main>
      <BottomNav />
    </div>
  )
}
