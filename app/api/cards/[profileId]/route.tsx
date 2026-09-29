import { ImageResponse } from 'next/og'
import { createClient } from '@/lib/supabase/server'

export const dynamic = 'force-dynamic'

const GOLD = '#D4AF37'
const BG = '#0A0A0C'

export async function GET(request: Request, { params }: { params: Promise<{ profileId: string }> }) {
  const { profileId } = await params
  const { searchParams } = new URL(request.url)
  const matchResult = searchParams.get('result') // 'win' | 'loss' | null
  const opponentName = searchParams.get('opponent') ?? ''
  const xpParam = searchParams.get('xp')

  const supabase = await createClient()

  const { data: profile } = await supabase
    .from('profiles')
    .select('username,display_name,city,country_code')
    .eq('id', profileId)
    .maybeSingle()

  const { data: rankings } = await supabase
    .from('sport_rankings')
    .select('rating,wins,losses,rank,sport_id')
    .eq('profile_id', profileId)
    .order('matches_played', { ascending: false })

  const totalWins = (rankings ?? []).reduce((s, r) => s + (r.wins ?? 0), 0)
  const totalLosses = (rankings ?? []).reduce((s, r) => s + (r.losses ?? 0), 0)
  const bestRating = (rankings ?? [])[0]?.rating ?? null
  const bestRank = (rankings ?? [])[0]?.rank ?? null

  // Only visible when the requester IS the profile owner (RLS owner-only read) — degrades gracefully otherwise.
  const { data: progression } = await supabase
    .from('player_progression')
    .select('total_xp,level,current_title')
    .eq('profile_id', profileId)
    .maybeSingle()

  const { data: streakRows } = await supabase
    .from('player_sport_streaks')
    .select('current_win_streak,best_win_streak')
    .eq('profile_id', profileId)
    .order('current_win_streak', { ascending: false })
    .limit(1)

  const streak = streakRows?.[0]?.current_win_streak ?? null
  const level = progression?.level ?? null
  const totalXp = xpParam ? Number(xpParam) : progression?.total_xp ?? null

  const name = profile?.display_name ?? 'Jugador Dynasty'
  const handle = profile?.username ? `@${profile.username}` : ''

  const resultBanner =
    matchResult === 'win'
      ? `GANO vs ${opponentName || 'rival'}`
      : matchResult === 'loss'
        ? `PERDIO vs ${opponentName || 'rival'}`
        : null
  const resultXp = matchResult === 'win' ? '+100 XP' : matchResult === 'loss' ? '+50 XP' : null

  return new ImageResponse(
    (
      <div
        style={{
          width: '1200px',
          height: '630px',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
          background: `linear-gradient(135deg, #1B1A12 0%, #161616 45%, ${BG} 100%)`,
          padding: '56px 64px',
          color: 'white',
          fontFamily: 'sans-serif',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            <div style={{ display: 'flex', width: 14, height: 14, borderRadius: 999, background: GOLD }} />
            <div style={{ display: 'flex', fontSize: 22, letterSpacing: 6, fontWeight: 900, color: GOLD }}>
              CHALLENGE DYNASTY
            </div>
          </div>
          <div style={{ display: 'flex', fontSize: 20, letterSpacing: 4, color: 'rgba(255,255,255,0.4)' }}>
            CARTA DE JUGADOR
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 40 }}>
          <div
            style={{
              display: 'flex',
              width: 160,
              height: 160,
              borderRadius: 40,
              background: `linear-gradient(135deg, ${GOLD} 0%, #8a6d1f 100%)`,
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 64,
              fontWeight: 900,
              color: BG,
            }}
          >
            {name.slice(0, 1).toUpperCase()}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ display: 'flex', fontSize: 56, fontWeight: 900 }}>{name}</div>
            <div style={{ display: 'flex', fontSize: 26, color: 'rgba(255,255,255,0.5)' }}>
              {handle}{profile?.city ? ` · ${profile.city}` : ''}
            </div>
            {level !== null && (
              <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 6 }}>
                <div
                  style={{
                    display: 'flex',
                    background: GOLD,
                    color: BG,
                    fontWeight: 900,
                    fontSize: 22,
                    padding: '6px 18px',
                    borderRadius: 999,
                  }}
                >
                  NIVEL {level}
                </div>
                {totalXp !== null && (
                  <div style={{ display: 'flex', fontSize: 22, color: 'rgba(255,255,255,0.6)' }}>{totalXp} XP</div>
                )}
              </div>
            )}
          </div>
        </div>

        {resultBanner && (
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              background: 'rgba(212,175,55,0.12)',
              border: `2px solid ${GOLD}`,
              borderRadius: 24,
              padding: '18px 28px',
            }}
          >
            <div style={{ display: 'flex', fontSize: 28, fontWeight: 900, color: GOLD }}>{resultBanner}</div>
            {resultXp && <div style={{ display: 'flex', fontSize: 28, fontWeight: 900 }}>{resultXp}</div>}
          </div>
        )}

        <div style={{ display: 'flex', gap: 16 }}>
          {[
            ['RATING', bestRating !== null ? Math.round(Number(bestRating)) : '—'],
            ['RANKING', bestRank !== null ? `#${bestRank}` : '—'],
            ['VICTORIAS', totalWins],
            ['DERROTAS', totalLosses],
            ['RACHA', streak !== null ? `${streak}` : '—'],
          ].map(([label, value]) => (
            <div
              key={label as string}
              style={{
                display: 'flex',
                flexDirection: 'column',
                flex: 1,
                background: 'rgba(255,255,255,0.06)',
                borderRadius: 20,
                padding: '18px 20px',
              }}
            >
              <div style={{ display: 'flex', fontSize: 16, letterSpacing: 2, color: 'rgba(255,255,255,0.4)' }}>
                {label}
              </div>
              <div style={{ display: 'flex', fontSize: 34, fontWeight: 900, marginTop: 6, color: GOLD }}>
                {value}
              </div>
            </div>
          ))}
        </div>
      </div>
    ),
    { width: 1200, height: 630 },
  )
}
