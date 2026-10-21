import Link from 'next/link'
export const dynamic = 'force-dynamic'
import { createClient } from '@/lib/supabase/server'
import FollowButton from '@/components/FollowButton'
import PlayerCard from '@/components/PlayerCard'
import CardShowcase from '@/components/CardShowcase'
import { getPlayerCards } from '@/lib/dynasty/cards'
import { getTranslations, getLocale } from 'next-intl/server'
import { headers } from 'next/headers'
import type { Metadata } from 'next'

// Al pegar el enlace del perfil en WhatsApp/Facebook/X/Telegram se muestra la carta del jugador.
export async function generateMetadata({ params }: { params: Promise<{ username: string }> }): Promise<Metadata> {
  const { username } = await params
  const supabase = await createClient()
  const { data: p } = await supabase.from('profiles').select('id,display_name,username').eq('username', username).maybeSingle()
  if (!p) return {}
  const h = await headers()
  const host = h.get('x-forwarded-host') ?? h.get('host')
  const proto = h.get('x-forwarded-proto') ?? 'https'
  const origin = host ? `${proto}://${host}` : ''
  const image = `${origin}/api/cards/${p.id}`
  const title = `${p.display_name} (@${p.username}) · Challenge Dynasty`
  return {
    title,
    openGraph: { title, siteName: 'Challenge Dynasty', type: 'profile', images: [{ url: image, width: 1200, height: 630 }] },
    twitter: { card: 'summary_large_image', title, images: [image] },
  }
}

export default async function ProfilePage({ params }: { params: Promise<{ username: string }> }) {
  const { username } = await params
  const t = await getTranslations('Profile')
  const locale = await getLocale()
  const dateLocale = locale === 'en' ? 'en-US' : 'es-CO'
  const tCards = await getTranslations('Cards')
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  const { data: p } = await supabase.from('profiles').select('*').eq('username', username).maybeSingle()

  if (!p) {
    return (
      <main className="min-h-screen arena-bg text-white grid place-items-center">
        <div className="text-center">
          <h1 className="text-3xl font-display font-black tracking-wide">{t('notFoundTitle')}</h1>
          <Link href="/players" className="text-[#D4AF37] mt-4 inline-block">{t('explorePlayers')}</Link>
        </div>
      </main>
    )
  }

  const isOwnProfile = user?.id === p.id

  const { data: follow } = user && !isOwnProfile
    ? await supabase.from('social_follows').select('id').eq('follower_profile_id', user.id).eq('followed_profile_id', p.id).maybeSingle()
    : { data: null }

  const { data: rankings } = await supabase
    .from('sport_rankings')
    .select('rating,wins,losses,rank,sport_id,matches_played')
    .eq('profile_id', p.id)
    .order('matches_played', { ascending: false })

  const totalWins = (rankings ?? []).reduce((s, r) => s + (r.wins ?? 0), 0)
  const totalLosses = (rankings ?? []).reduce((s, r) => s + (r.losses ?? 0), 0)
  const bestRating = (rankings ?? [])[0]?.rating ?? null
  const bestRank = (rankings ?? [])[0]?.rank ?? null
  const winrate = totalWins + totalLosses ? ((totalWins / (totalWins + totalLosses)) * 100).toFixed(1) : '0.0'

  // Owner-only reads under RLS — resolve to null for anyone viewing someone else's profile.
  const { data: progression } = await supabase.from('player_progression').select('total_xp,level').eq('profile_id', p.id).maybeSingle()
  const { data: streakRows } = await supabase.from('player_sport_streaks').select('current_win_streak').eq('profile_id', p.id).order('current_win_streak', { ascending: false }).limit(1)
  const streak = streakRows?.[0]?.current_win_streak ?? null

  const { data: rivalsOne } = user
    ? await supabase.from('player_rivalries').select('sport_id,player_one_id,player_two_id,matches_count,player_one_wins,player_two_wins,last_match_at').or(`player_one_id.eq.${p.id},player_two_id.eq.${p.id}`).order('last_match_at', { ascending: false }).limit(8)
    : { data: [] }
  const rivalIds = [...new Set((rivalsOne ?? []).map((r) => (r.player_one_id === p.id ? r.player_two_id : r.player_one_id)))]
  const { data: rivalProfiles } = rivalIds.length ? await supabase.from('profiles').select('id,username,display_name').in('id', rivalIds) : { data: [] }
  const rivalMap = new Map((rivalProfiles ?? []).map((x) => [x.id, x]))
  const rivals = (rivalsOne ?? []).map((r) => {
    const opponentId = r.player_one_id === p.id ? r.player_two_id : r.player_one_id
    const opponent = rivalMap.get(opponentId)
    return {
      opponent_id: opponentId,
      opponent_username: opponent?.username,
      opponent_name: opponent?.display_name ?? t('defaultRivalName'),
      played: r.matches_count,
      wins: r.player_one_id === p.id ? r.player_one_wins : r.player_two_wins,
      losses: r.player_one_id === p.id ? r.player_two_wins : r.player_one_wins,
      last_played: r.last_match_at,
    }
  })

  const collection = await getPlayerCards(supabase, p.id, t('defaultRivalName'))

  const statBlocks: [string, string | number][] = [
    [t('wins'), totalWins],
    [t('losses'), totalLosses],
    [t('winRate'), `${winrate}%`],
    [t('streak'), streak !== null ? `🔥 ${streak}` : '—'],
    [t('rating'), bestRating !== null ? Math.round(Number(bestRating)) : '—'],
    [t('rank'), bestRank !== null ? `#${bestRank}` : '—'],
  ]

  const nameWords = (p.display_name || p.username || '').trim().split(/\s+/)
  const firstName = nameWords[0] ?? ''
  const restName = nameWords.slice(1).join(' ')

  return (
    <main className="min-h-screen arena-bg overflow-x-clip px-4 py-6 text-white md:px-10 md:py-10">
      <div className="mx-auto max-w-6xl">
        <Link href="/" className="text-sm text-white/60 hover:text-[#D4AF37]">{t('backLink')}</Link>

        {/* Portada estilo ficha de piloto */}
        <section className="relative isolate mt-6 grid items-center gap-10 md:grid-cols-[minmax(0,1fr)_auto]">
          {bestRating !== null && (
            <div aria-hidden="true" className="pointer-events-none absolute -top-8 right-0 -z-10 select-none font-display leading-none tabular-nums text-[#D4AF37]/[0.06] text-[38vw] md:text-[360px]">
              {Math.round(Number(bestRating))}
            </div>
          )}
          <div className="min-w-0">
            <div className="reveal text-xs font-black tracking-[.3em] text-[#D4AF37]">{t('tag')}</div>
            <h1 className="mt-3 break-words font-display font-normal leading-[.86] tracking-tight text-[clamp(64px,11vw,170px)]">
              <span className="reveal block" style={{ ['--i' as string]: 1 }}>{firstName}</span>
              {restName && <span className="reveal lando-outline block pl-[6%]" style={{ ['--i' as string]: 2 }}>{restName}</span>}
            </h1>
            <div className="reveal mt-4 flex flex-wrap items-center gap-3 text-white/70" style={{ ['--i' as string]: 3 }}>
              <span>@{p.username} · {p.city || t('locationUnknown')}</span>
              {progression?.level != null && (
                <span className="inline-flex items-center gap-2 rounded-full border border-[#D4AF37]/40 bg-[#D4AF37]/15 px-3 py-1">
                  <span className="text-xs font-black text-[#D4AF37]">{t('level')} {progression.level}</span>
                  {progression.total_xp != null && <span className="text-xs text-white/60 tabular-nums">· {progression.total_xp} {t('xp')}</span>}
                </span>
              )}
            </div>
            <div className="reveal mt-6 flex flex-wrap gap-3" style={{ ['--i' as string]: 4 }}>
              <Link href={`/challenge/new?player=${p.id}`} className="btn-gold shine">{t('challengeBtn')}</Link>
              {user && !isOwnProfile && <FollowButton targetId={p.id} initialFollowing={Boolean(follow)} />}
            </div>
          </div>
          <div className="reveal relative mx-auto" style={{ ['--i' as string]: 2 }}>
            <div aria-hidden="true" className="spot-rays" />
            <div className="hex grid h-40 w-40 place-items-center font-display text-8xl md:h-56 md:w-56 md:text-9xl" aria-hidden="true">{(p.display_name || p.username || '?').trim()[0]?.toUpperCase()}</div>
            <div className="mt-4 text-center">
              <div className="text-[10px] font-black uppercase tracking-[.3em] text-white/50">{t('globalRanking')}</div>
              <div className="font-display text-5xl leading-none tabular-nums text-[#D4AF37]">{bestRank !== null ? `#${bestRank}` : '—'}</div>
            </div>
          </div>
        </section>

        {/* Estadisticas en grande */}
        <dl className="mt-12 grid grid-cols-2 border-t border-white/10 md:grid-cols-6">
          {statBlocks.map(([label, value], i) => (
            <div key={label} className="reveal border-b border-white/10 py-5 pr-4 md:border-b-0 md:py-6" style={{ ['--i' as string]: Math.min(i, 8) }}>
              <dt className="text-[11px] font-black uppercase tracking-[.2em] text-white/50">{label}</dt>
              <dd className="mt-1 font-display text-5xl leading-none tabular-nums md:text-6xl">{value}</dd>
            </div>
          ))}
        </dl>

        <section className="mt-14 grid items-start gap-10 md:grid-cols-[auto_minmax(0,1fr)]">
          <div>
            <h2 className="mb-4 font-display text-4xl leading-none tracking-wide">{isOwnProfile ? t('myCardTitle') : t('tag')}</h2>
            <PlayerCard profileId={p.id} playerName={p.display_name} username={p.username} />
          </div>
          <div>
            <h2 className="mb-4 font-display text-4xl leading-none tracking-wide">{t('rivalriesTitle')}</h2>
            <div className="space-y-2">
              {(rivals ?? []).map((r) => {
                const g = (r.wins ?? 0) + (r.losses ?? 0)
                const pct = g ? Math.round(((r.wins ?? 0) / g) * 100) : 0
                return (
                  <Link key={r.opponent_id} href={`/u/${r.opponent_username}`} className="standings-row flex items-center gap-4 border-t border-white/10 px-2 py-4">
                    <div className="hex grid h-11 w-11 shrink-0 place-items-center font-display text-xl" aria-hidden="true">{(r.opponent_name || '?').trim()[0]?.toUpperCase()}</div>
                    <div className="min-w-0 flex-1">
                      <div className="truncate font-display text-2xl tracking-wide">{r.opponent_name}</div>
                      <div className="mt-1 flex items-center gap-3">
                        <div className="h-1.5 w-28 overflow-hidden rounded-full bg-white/10"><div className="h-full rounded-full bg-[#D4AF37]" style={{ width: `${pct}%` }} /></div>
                        <span className="text-xs text-white/60 tabular-nums">{t('matchesPlayed', { count: r.played, wins: r.wins, losses: r.losses })}</span>
                      </div>
                    </div>
                    <div className="shrink-0 text-xs text-white/50">{new Date(r.last_played).toLocaleDateString(dateLocale)}</div>
                  </Link>
                )
              })}
              {(rivals ?? []).length === 0 && <div className="border border-dashed border-white/15 bg-white/[.02] p-5 text-white/55">{t('emptyRivalries')}</div>}
            </div>
          </div>
        </section>

        <div className="mt-14">
          <CardShowcase cards={collection} title={isOwnProfile ? undefined : tCards('collectionOf', { name: p.display_name })} />
        </div>
      </div>
    </main>
  )
}
