export const dynamic = 'force-dynamic'
import Link from 'next/link'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import PageHero from '@/components/PageHero'
import CardShowcase from '@/components/CardShowcase'
import DynastyCard from '@/components/DynastyCard'
import { createClient } from '@/lib/supabase/server'
import { getPlayerCards, getRecentTransfers } from '@/lib/dynasty/cards'
import { getTranslations, getLocale } from 'next-intl/server'

export default async function CardsPage() {
  const supabase = await createClient()
  const t = await getTranslations('Cards')
  const tc = await getTranslations('Challenge')
  const locale = await getLocale()
  const dateLocale = locale === 'en' ? 'en-US' : 'es-CO'
  const { data: { user } } = await supabase.auth.getUser()

  const cards = user ? await getPlayerCards(supabase, user.id, tc('defaultPlayer')) : []
  const topCard = cards.length ? cards.reduce((best, c) => (c.rating > best.rating ? c : best), cards[0]) : null
  const titleWords = t('pageTitle').split(' ')
  const titleLine1 = titleWords[0]
  const titleLine2 = titleWords.slice(1).join(' ')
  const transfers = user ? await getRecentTransfers(supabase, user.id, tc('defaultPlayer')) : []

  return (
    <div className="min-h-screen arena-bg text-white">
      <Sidebar />
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="mx-auto max-w-6xl px-4 py-8 md:px-6">
          <PageHero wide>
            <div className="flex flex-wrap items-center gap-8">
              <div className="relative min-w-[260px] flex-1">
                {topCard && (
                  <div aria-hidden="true" className="pointer-events-none absolute -right-4 -top-12 select-none font-display text-[180px] leading-none text-[#D4AF37]/[0.07] md:text-[260px]">
                    {topCard.rating}
                  </div>
                )}
                <div className="relative text-xs font-black tracking-[.3em] text-[#D4AF37]">{t('pageTag')}</div>
                <h1 className="relative mt-2 font-display text-6xl font-black leading-[0.92] tracking-wide md:text-8xl">
                  {titleLine1}
                  {titleLine2 && <><br />{titleLine2}</>}
                </h1>
                <p className="relative mt-3 max-w-md text-white/55 lowercase">{t('pageSubtitle')}</p>
              </div>
              {topCard && (
                <div className="relative w-[200px] shrink-0 md:w-[260px]">
                  <div className="mb-2 text-center text-[10px] font-black uppercase tracking-widest text-[#D4AF37]/70">{t('featuredLabel')}</div>
                  <DynastyCard card={topCard} />
                </div>
              )}
            </div>
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
                          <div className="shrink-0 text-xs text-white/35">{new Date(tr.createdAt).toLocaleDateString(dateLocale)}</div>
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
