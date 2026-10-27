import { ImageResponse } from 'next/og'
import { createClient } from '@/lib/supabase/server'
import { checkRateLimit } from '@/lib/rate-limit'

export const dynamic = 'force-dynamic'

// FEATURE PEDIDA POR LUIS (2026-10-26): "cuando se monte el resultado del partido, que mande
// como una carta de como quedo, para que lo instagrameen" -- y aclaro despues: no su logo
// (DINASTY/Padelito), sino el NOMBRE DEL TORNEO en la carta. Sigue el mismo patron que
// app/api/cards/[profileId]/route.tsx (carta de jugador): todo lo que se muestra se calcula del
// lado del servidor a partir del fixtureId real, nunca de parametros en la URL -- asi no se puede
// fabricar una carta de un resultado que no existe.
const GOLD = '#D4AF37'
const BG = '#0A0A0C'

type EntrySide = { entryId: string | null; label: string }

export async function GET(request: Request, { params }: { params: Promise<{ fixtureId: string }> }) {
  const { fixtureId } = await params
  const supabase = await createClient()

  // Ruta publica en el sentido de que no exige ser organizador (cualquier jugador de este
  // partido, o cualquiera con sesion en un torneo publico, puede pedir su carta) -- limite por IP,
  // igual que la carta de jugador.
  const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown'
  const allowed = await checkRateLimit(supabase, 'tournament_card_image', 60, 60, ip)
  if (!allowed) {
    return new Response('Too many requests', { status: 429 })
  }

  const { data: fixture } = await supabase
    .from('tournament_fixtures')
    .select('id,tournament_id,category_id,round_number,side_a_entry_id,side_b_entry_id,winner_entry_id,status,metadata')
    .eq('id', fixtureId)
    .maybeSingle()

  const scoreA = fixture?.metadata?.score_a
  const scoreB = fixture?.metadata?.score_b
  // Solo se genera la carta de un resultado REAL ya registrado -- nunca de un partido todavia
  // sin jugar (ahi no hay nada que "instagramear" y seria facil fabricar una carta falsa pidiendo
  // cualquier fixtureId al azar).
  if (!fixture || fixture.status !== 'completed' || scoreA == null || scoreB == null) {
    return new Response('Not found', { status: 404 })
  }

  const [{ data: tournament }, { data: category }] = await Promise.all([
    supabase.from('tournaments').select('title').eq('id', fixture.tournament_id).maybeSingle(),
    supabase.from('tournament_categories').select('name').eq('id', fixture.category_id).maybeSingle(),
  ])

  async function buildSide(entryId: string | null): Promise<EntrySide> {
    if (!entryId) return { entryId: null, label: 'Por definir' }
    const { data: members } = await supabase
      .from('tournament_entry_members')
      .select('profile:profiles!tournament_entry_members_profile_id_fkey(display_name)')
      .eq('entry_id', entryId)
      .eq('status', 'confirmed')
    const names = (members ?? [])
      .map((m) => {
        const p = Array.isArray(m.profile) ? m.profile[0] : m.profile
        return p?.display_name
      })
      .filter((n): n is string => Boolean(n))
    return { entryId, label: names.length > 0 ? names.join(' & ') : 'Jugador Dynasty' }
  }

  const [sideA, sideB] = await Promise.all([buildSide(fixture.side_a_entry_id), buildSide(fixture.side_b_entry_id)])
  const aWon = fixture.winner_entry_id === fixture.side_a_entry_id
  const bWon = fixture.winner_entry_id === fixture.side_b_entry_id
  const tournamentTitle = tournament?.title ?? 'Challenge Dynasty'
  const categoryName = category?.name ?? ''

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
            RESULTADO
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{ display: 'flex', fontSize: 52, fontWeight: 900, lineHeight: 1.1 }}>{tournamentTitle}</div>
          {categoryName && (
            <div style={{ display: 'flex', fontSize: 26, color: 'rgba(255,255,255,0.5)', letterSpacing: 1 }}>
              {categoryName}
              {fixture.round_number != null ? ` · Ronda ${fixture.round_number}` : ''}
            </div>
          )}
        </div>

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            background: 'rgba(255,255,255,0.05)',
            border: `2px solid ${GOLD}`,
            borderRadius: 28,
            padding: '32px 40px',
          }}
        >
          <div style={{ display: 'flex', flexDirection: 'column', flex: 1, gap: 6 }}>
            <div style={{ display: 'flex', fontSize: 32, fontWeight: 900, color: aWon ? GOLD : 'white' }}>
              {sideA.label}
            </div>
            {aWon && <div style={{ display: 'flex', fontSize: 18, letterSpacing: 3, color: GOLD, fontWeight: 900 }}>GANADOR</div>}
          </div>
          <div style={{ display: 'flex', fontSize: 64, fontWeight: 900, padding: '0 36px', color: GOLD }}>
            {scoreA} - {scoreB}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', flex: 1, gap: 6, alignItems: 'flex-end', textAlign: 'right' }}>
            <div style={{ display: 'flex', fontSize: 32, fontWeight: 900, color: bWon ? GOLD : 'white' }}>
              {sideB.label}
            </div>
            {bWon && <div style={{ display: 'flex', fontSize: 18, letterSpacing: 3, color: GOLD, fontWeight: 900 }}>GANADOR</div>}
          </div>
        </div>

        <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
          <div style={{ display: 'flex', fontSize: 18, letterSpacing: 3, color: 'rgba(255,255,255,0.35)', fontWeight: 700 }}>
            BY PADELITO
          </div>
        </div>
      </div>
    ),
    { width: 1200, height: 630 },
  )
}
