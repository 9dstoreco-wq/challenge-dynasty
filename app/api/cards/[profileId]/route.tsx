import { ImageResponse } from 'next/og'
import { createClient } from '@/lib/supabase/server'
import { checkRateLimit } from '@/lib/rate-limit'

export const dynamic = 'force-dynamic'

const GOLD = '#D4AF37'
const BG = '#0A0A0C'

export async function GET(request: Request, { params }: { params: Promise<{ profileId: string }> }) {
  const { profileId } = await params
  const { searchParams } = new URL(request.url)
  // Antes esto confiaba en result/opponent/xp tal cual venian en la URL: cualquiera podia pedir
  // /api/cards/<cualquier-id>?result=win&opponent=X&xp=99999 y fabricar una imagen "GANO vs X +99999 XP"
  // de un partido que nunca existio. Ahora solo se acepta un matchId, y el resultado/rival/XP que se
  // muestran se calculan del lado del servidor a partir de ese partido real, nunca de la URL.
  const matchId = searchParams.get('match')

  const supabase = await createClient()

  // Esta ruta es publica (sin sesion), asi que el limite es por IP: hasta 60 imagenes por minuto.
  // Si la cabecera no trae IP (algunos entornos locales), se agrupa en un solo bucket generico en
  // vez de fallar -- sigue siendo mejor que ningun limite.
  const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown'
  const allowed = await checkRateLimit(supabase, `card_image:${ip}`, 60, 60)
  if (!allowed) {
    return new Response('Too many requests', { status: 429 })
  }

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
  const totalXp = progression?.total_xp ?? null

  const name = profile?.display_name ?? 'Jugador Dynasty'
  const handle = profile?.username ? `@${profile.username}` : ''

  // Todo el bloque del resultado (banner + XP) se reconstruye aqui desde datos reales de la base,
  // nunca desde lo que mande la URL. Si el partido no existe, no esta confirmado, o este profileId
  // no jugo ese partido, simplemente no se muestra ningun banner.
  let resultBanner: string | null = null
  let resultXp: string | null = null
  if (matchId) {
    const { data: matchRow } = await supabase
      .from('matches')
      .select('id,challenge_id')
      .eq('id', matchId)
      .maybeSingle()
    if (matchRow) {
      const { data: resultRow } = await supabase
        .from('match_results')
        .select('winner_profile_id,status')
        .eq('match_id', matchRow.id)
        .maybeSingle()
      const { data: participants } = await supabase
        .from('challenge_participants')
        .select('profile_id,status,profile:profiles!challenge_participants_profile_id_fkey(display_name,username)')
        .eq('challenge_id', matchRow.challenge_id)
      const list = participants ?? []
      const iPlayed = list.some((p) => p.profile_id === profileId && p.status !== 'declined' && p.status !== 'withdrawn')
      const opponentRow = list.find((p) => p.profile_id !== profileId)
      const opponentProfile = Array.isArray(opponentRow?.profile) ? opponentRow?.profile[0] : opponentRow?.profile
      const opponentName = opponentProfile?.display_name || opponentProfile?.username || 'rival'
      if (iPlayed && resultRow?.status === 'confirmed' && resultRow.winner_profile_id) {
        const won = resultRow.winner_profile_id === profileId
        resultBanner = won ? `GANO vs ${opponentName}` : `PERDIO vs ${opponentName}`
        const { data: xpRow } = await supabase
          .from('xp_events')
          .select('amount')
          .eq('source_type', 'MATCH_RESULT_CONFIRMED')
          .eq('source_id', matchRow.id)
          .eq('profile_id', profileId)
          .maybeSingle()
        const realXp = xpRow?.amount ?? (won ? 100 : 50)
        resultXp = `+${realXp} XP`
      }
    }
  }

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
