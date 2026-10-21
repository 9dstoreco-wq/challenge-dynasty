export const dynamic = 'force-dynamic'
import Link from 'next/link'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import MarqueeTicker from '@/components/MarqueeTicker'
import { createClient } from '@/lib/supabase/server'
import { getTranslations } from 'next-intl/server'

type Prof = { display_name: string | null; username: string | null; avatar_url: string | null }

export default async function RankingPage() {
  const supabase = await createClient()
  const t = await getTranslations('Ranking')
  const { data: rankingsData, error } = await supabase
    .from('sport_rankings')
    .select('profile_id,sport_id,rating,rank,wins,losses,matches_played,profiles(display_name,username,avatar_url)')
    .order('rank', { ascending: true, nullsFirst: false })
    .order('rating', { ascending: false })
    .limit(100)
  const rankings = rankingsData ?? []
  const podium = rankings.slice(0, 3)
  const rest = rankings.slice(3)
  const prof = (r: (typeof rankings)[number]): Prof | null => (Array.isArray(r.profiles) ? (r.profiles[0] as Prof) : (r.profiles as Prof | null))
  const nameOf = (p: Prof | null) => p?.display_name || p?.username || t('defaultPlayer')
  const winPct = (w: number | null, l: number | null) => { const g = (w ?? 0) + (l ?? 0); return g ? Math.round(((w ?? 0) / g) * 100) : 0 }

  return (
    <div className="min-h-screen arena-bg overflow-x-clip text-white">
      <Sidebar />
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="mx-auto max-w-6xl px-4 py-8 md:px-6">
          <section className="relative isolate mb-6">
            {podium[0] && (
              <div aria-hidden="true" className="pointer-events-none absolute -top-8 right-0 -z-10 select-none font-display leading-none tabular-nums text-[#D4AF37]/[0.06] text-[40vw] md:text-[380px]">
                {Number(podium[0].rating).toFixed(0)}
              </div>
            )}
            <div className="reveal text-xs font-black tracking-[.3em] text-[#D4AF37]">{t('kicker')}</div>
            <h1 className="mt-3 font-display font-normal leading-[.84] tracking-tight text-[clamp(80px,13vw,190px)]">
              <span className="reveal block" style={{ ['--i' as string]: 1 }}>RANKING</span>
              <span className="reveal lando-outline block pl-[8%]" style={{ ['--i' as string]: 2 }}>DYNASTY</span>
            </h1>
            <div className="reveal mt-5 flex flex-wrap items-center justify-between gap-5" style={{ ['--i' as string]: 3 }}>
              <p className="max-w-md text-base leading-relaxed text-white/70">{t('subtitle')}</p>
              <Link href="/challenge/new" className="btn-gold shine">{t('cta')}</Link>
            </div>
          </section>

          <MarqueeTicker items={[t('ticker1'), t('ticker2'), t('ticker3'), t('ticker4')]} />

          {error ? (
            <div className="mt-8 rounded-3xl border border-red-400/20 bg-red-400/5 p-8 text-center text-red-200" role="alert">{t('loadError')}</div>
          ) : rankings.length === 0 ? (
            <div className="mt-8 rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-10 text-center text-white/55">{t('empty')}</div>
          ) : (
            <>
              {/* Podio */}
              <div className="mt-10 grid grid-cols-3 items-end gap-3 md:gap-5">
                {[podium[1], podium[0], podium[2]].map((r, k) => {
                  if (!r) return <div key={`empty-${k}`} />
                  const pos = k === 1 ? 1 : k === 0 ? 2 : 3
                  const p = prof(r)
                  const rarity = pos === 1 ? 'rarity-gold' : pos === 2 ? 'rarity-silver' : 'rarity-bronze'
                  return (
                    <div key={`${r.profile_id}-${r.sport_id}`} className={`podium-col relative reveal ${rarity} ${pos === 1 ? 'is-first' : ''}`} style={{ ['--i' as string]: pos }}>
                      {pos === 1 && <div aria-hidden="true" className="spot-rays" />}
                      <div className="card-fut shine">
                        <div className={`card-fut-in p-4 text-center md:p-6 ${pos === 1 ? 'md:pb-12 md:pt-8' : ''}`} style={{ background: 'radial-gradient(circle at 50% 0%,color-mix(in srgb,var(--r) 30%,transparent),transparent 65%),#101012' }}>
                          <div className="font-display leading-none tabular-nums text-6xl md:text-8xl" style={{ color: 'var(--r)' }}>P{pos}</div>
                          <div className="hex mx-auto mt-3 grid h-14 w-14 place-items-center font-display text-2xl md:h-20 md:w-20 md:text-4xl" style={{ background: 'linear-gradient(160deg,#fff8,var(--r))' }} aria-hidden="true">{nameOf(p).trim()[0]?.toUpperCase()}</div>
                          <div className="mt-3 truncate font-display text-xl tracking-wide md:text-3xl">{nameOf(p)}</div>
                          <div className="mt-1 font-display text-3xl leading-none tabular-nums md:text-5xl" style={{ color: 'var(--r)' }}>{Number(r.rating).toFixed(0)}</div>
                          <div className="mt-1 text-[10px] uppercase tracking-widest text-white/50">{t('ratingLabel')}</div>
                          <div className="mt-2 hidden text-xs text-white/55 md:block">{t('matchesStats', { matches: r.matches_played, wins: r.wins, losses: r.losses })}</div>
                        </div>
                      </div>
                      <div aria-hidden="true" className="podium-step" />
                    </div>
                  )
                })}
              </div>

              {/* Tabla de posiciones estilo campeonato */}
              {rest.length > 0 && (
                <div className="mt-12 overflow-x-auto">
                  <table className="standings w-full min-w-[560px] border-collapse text-left">
                    <thead>
                      <tr className="text-[11px] font-black uppercase tracking-[.2em] text-white/50">
                        <th scope="col" className="w-20 py-3">{t('colPos')}</th>
                        <th scope="col" className="py-3">{t('colPlayer')}</th>
                        <th scope="col" className="w-40 py-3">{t('colRecord')}</th>
                        <th scope="col" className="w-48 py-3">{t('colWinRate')}</th>
                        <th scope="col" className="w-24 py-3 text-right">{t('ratingLabel')}</th>
                      </tr>
                    </thead>
                    <tbody>
                      {rest.map((r, i) => {
                        const p = prof(r)
                        const pct = winPct(r.wins, r.losses)
                        return (
                          <tr key={`${r.profile_id}-${r.sport_id}`} className="standings-row reveal border-t border-white/10" style={{ ['--i' as string]: Math.min(i, 10) }}>
                            <td className="py-4 font-display text-4xl leading-none tabular-nums text-[#D4AF37]">{r.rank ?? i + 4}</td>
                            <td className="py-4">
                              {p?.username ? <Link href={`/u/${p.username}`} className="font-display text-2xl tracking-wide text-white hover:text-[#D4AF37]">{nameOf(p)}</Link> : <span className="font-display text-2xl tracking-wide">{nameOf(p)}</span>}
                            </td>
                            <td className="py-4 text-sm tabular-nums text-white/70">{t('record', { wins: r.wins ?? 0, losses: r.losses ?? 0 })}</td>
                            <td className="py-4">
                              <div className="flex items-center gap-3">
                                <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-white/10"><div className="h-full rounded-full bg-[#D4AF37]" style={{ width: `${pct}%` }} /></div>
                                <span className="w-10 text-right text-xs font-bold tabular-nums text-white/70">{pct}%</span>
                              </div>
                            </td>
                            <td className="py-4 text-right font-display text-3xl leading-none tabular-nums">{Number(r.rating).toFixed(0)}</td>
                          </tr>
                        )
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </>
          )}
        </div>
      </main>
      <BottomNav />
    </div>
  )
}
