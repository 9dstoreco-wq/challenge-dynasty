export const dynamic = 'force-dynamic'
import Link from 'next/link'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import CardShowcase from '@/components/CardShowcase'
import CardSpotlight from '@/components/CardSpotlight'
import LockedCardFan from '@/components/LockedCardFan'
import MarqueeTicker from '@/components/MarqueeTicker'
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
    <div className="min-h-screen arena-bg overflow-x-clip text-white">
      <Sidebar />
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="mx-auto max-w-6xl px-4 py-8 md:px-6">
          {/* Portada estilo "piloto de elite" */}
          <section className="relative isolate mb-6 grid items-center gap-10 md:grid-cols-[minmax(0,1fr)_auto]">
            {topCard && (
              <div aria-hidden="true" className="pointer-events-none absolute -top-10 right-0 -z-10 select-none font-display leading-none text-[#D4AF37]/[0.06] tabular-nums text-[44vw] md:text-[420px]">
                {topCard.rating}
              </div>
            )}
            <div className="min-w-0">
              <div className="reveal text-xs font-black tracking-[.3em] text-[#D4AF37]">{t('pageTag')}</div>
              <h1 className="mt-3 font-display font-normal leading-[.84] tracking-tight text-[clamp(88px,14vw,200px)]">
                <span className="reveal block" style={{ ['--i' as string]: 1 }}>{titleLine1}</span>
                {titleLine2 && <span className="reveal lando-outline block pl-[8%]" style={{ ['--i' as string]: 2 }}>{titleLine2}</span>}
              </h1>
              <p className="reveal mt-5 max-w-md text-base leading-relaxed text-white/70" style={{ ['--i' as string]: 3 }}>{t('pageSubtitle')}</p>
              <div className="reveal mt-7 flex flex-wrap gap-3" style={{ ['--i' as string]: 4 }}>
                <Link href="/challenge/new" className="btn-gold shine">{t('ctaChallenge')}</Link>
                <Link href="/ranking" className="btn-ghost">{t('ctaRanking')}</Link>
              </div>
            </div>
            <div className="reveal" style={{ ['--i' as string]: 2 }}>
              {topCard ? (
                <CardSpotlight label={t('featuredLabel')}><DynastyCard card={topCard} /></CardSpotlight>
              ) : (
                <LockedCardFan label={t('lockedLabel')} />
              )}
            </div>
          </section>

          <MarqueeTicker items={[t('ticker1'), t('ticker2'), t('ticker3'), t('ticker4')]} />

          {!user ? (
            <div className="card-fut-plain mt-8 border border-white/10 bg-[#141416] p-8 text-center">
              <p className="text-white/70">{t('loginRequired')}</p>
              <Link href="/login" className="btn-gold mt-4">{t('loginBtn')}</Link>
            </div>
          ) : (
            <div className="mt-8 space-y-14">
              <CardShowcase cards={cards} />
              <section>
                <h2 className="mb-5 font-display text-4xl md:text-6xl leading-none tracking-wide">{t('historyTitle')}</h2>
                {transfers.length === 0 ? (
                  <div className="card-fut-plain border border-dashed border-white/15 bg-white/[.02] p-6 text-white/55">{t('historyEmpty')}</div>
                ) : (
                  <ol className="relative space-y-3 border-l border-white/10 pl-6">
                    {transfers.map((tr, i) => {
                      const won = tr.toId === user.id
                      const name = tr.card?.playerName ?? ''
                      return (
                        <li key={tr.id} className="reveal relative" style={{ ['--i' as string]: Math.min(i, 8) }}>
                          <span aria-hidden="true" className={`absolute -left-[31px] top-1/2 h-3 w-3 -translate-y-1/2 rounded-full ${won ? 'bg-[#00E676] shadow-[0_0_12px_#00E676]' : 'bg-[#FF3D00] shadow-[0_0_12px_#FF3D00]'}`} />
                          <div className="card-fut-plain flex items-center justify-between gap-4 border border-white/10 bg-[#141416] px-5 py-4">
                            <div className="text-sm font-bold">
                              <span className={`mr-2 font-display text-lg tracking-wide ${won ? 'text-[#00E676]' : 'text-[#FF6A3D]'}`}>{won ? t('historyWonTag') : t('historyLostTag')}</span>
                              {won ? t('historyWon', { name, rival: tr.fromName }) : t('historyLost', { name, rival: tr.toName })}
                            </div>
                            <div className="shrink-0 text-xs text-white/45">{new Date(tr.createdAt).toLocaleDateString(dateLocale)}</div>
                          </div>
                        </li>
                      )
                    })}
                  </ol>
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
