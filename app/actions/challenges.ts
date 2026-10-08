'use server'

import { createClient } from '@/lib/supabase/server'
import { toSafeMessage } from '@/lib/safe-error'
import { actionError, actionOk, type ActionResult } from '@/lib/action-result'
import { getTranslations } from 'next-intl/server'
import { checkRateLimit } from '@/lib/rate-limit'
import { modeForSlug, computeWinnerSide } from '@/lib/sport-scoring'

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

function assertUuidLike(value: string, field: string, invalidFieldMessage: (field: string) => string) {
  if (!UUID_PATTERN.test(value)) throw new Error(invalidFieldMessage(field))
}

// Todas estas acciones DEVUELVEN { ok, data | error } en vez de lanzar errores: en produccion Next.js
// oculta los mensajes lanzados desde acciones del servidor y el usuario solo veria un error generico.

export async function createChallenge(input: {
  challengedId: string
  sportId: string
  matchDate: string
  clubId?: string
  matchType?: 'DIRECT' | 'INSTANT'
  points?: number
}): Promise<ActionResult<string>> {
  try {
    const t = await getTranslations('Errors')
    const invalidField = (field: string) => t('invalidField', { field })
    assertUuidLike(input.challengedId, t('fieldOpponent'), invalidField)
    assertUuidLike(input.sportId, t('fieldSport'), invalidField)
    const parsedDate = new Date(input.matchDate)
    if (Number.isNaN(parsedDate.getTime())) throw new Error(t('invalidDate'))
    if (parsedDate.getTime() <= Date.now()) throw new Error(t('challengeDateMustBeFuture'))
    if (input.points !== undefined && (!Number.isInteger(input.points) || input.points < 1 || input.points > 5000)) throw new Error(t('pointsRange'))
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    // Hasta 20 retos creados por hora por usuario.
    if (!(await checkRateLimit(supabase, `create_challenge:${user.id}`, 20, 3600))) throw new Error(t('rateLimited'))

    const { data, error } = await supabase.rpc('create_challenge', {
      p_challenged_id: input.challengedId,
      p_sport_id: input.sportId,
      p_match_date: input.matchDate,
      p_club_id: input.clubId ?? null,
      p_match_type: input.matchType ?? 'DIRECT',
      p_points: input.points ?? 100,
    })
    if (error) throw error
    return actionOk(data as string)
  } catch (e) {
    return actionError(toSafeMessage(e, 'challenges.createChallenge'))
  }
}

export async function respondToChallenge(invitationId: string, accept: boolean): Promise<ActionResult> {
  try {
    const t = await getTranslations('Errors')
    assertUuidLike(invitationId, t('fieldInvitation'), (field) => t('invalidField', { field }))
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    const { error } = await supabase.rpc('respond_to_challenge_invitation', {
      p_invitation_id: invitationId,
      p_accept: accept,
    })
    if (error) throw error
    return actionOk(true as const)
  } catch (e) {
    return actionError(toSafeMessage(e, 'challenges.respondToChallenge'))
  }
}

// El creador cancela su reto. La base de datos libera automaticamente las cartas que estuvieran en juego.
export async function cancelChallenge(challengeId: string): Promise<ActionResult> {
  try {
    const t = await getTranslations('Errors')
    assertUuidLike(challengeId, t('fieldChallenge'), (field) => t('invalidField', { field }))
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    const { error } = await supabase.rpc('cancel_challenge', { p_challenge_id: challengeId })
    if (error) throw error
    return actionOk(true as const)
  } catch (e) {
    return actionError(toSafeMessage(e, 'challenges.cancelChallenge'))
  }
}

export async function submitMatchResult(input: {
  matchId: string
  scoreSet1?: string
  scoreSet2?: string
  scoreSet3?: string | null
  winnerId: string
  resultData?: Record<string, unknown>
}): Promise<ActionResult<string>> {
  try {
    const t = await getTranslations('Errors')
    const invalidField = (field: string) => t('invalidField', { field })
    assertUuidLike(input.matchId, t('fieldMatch'), invalidField)
    assertUuidLike(input.winnerId, t('fieldWinner'), invalidField)
    for (const sc of [input.scoreSet1, input.scoreSet2, input.scoreSet3]) {
      if (sc && !/^\d{1,3}[-:]\d{1,3}$/.test(sc.trim())) throw new Error(t('invalidField', { field: t('fieldResult') }))
    }
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))

    // La funcion submit_challenge_result en la base de datos valida que el ganador sea un
    // participante del reto, pero NO compara el ganador declarado contra los marcadores -- un
    // cliente que la llame directo podria mandar un marcador que dice una cosa y un ganador que
    // dice otra. Esta verificacion recalcula el ganador a partir de los marcadores (igual que hace
    // el formulario) y rechaza cualquier desacuerdo antes de llegar a la base de datos.
    const { data: matchRow } = await supabase.from('matches').select('challenge_id').eq('id', input.matchId).maybeSingle()
    if (!matchRow?.challenge_id) throw new Error(invalidField(t('fieldMatch')))
    const { data: challengeRow } = await supabase.from('challenges').select('creator_id,sport_id').eq('id', matchRow.challenge_id).maybeSingle()
    if (!challengeRow) throw new Error(invalidField(t('fieldMatch')))
    const { data: participants } = await supabase
      .from('challenge_participants')
      .select('profile_id,status')
      .eq('challenge_id', matchRow.challenge_id)
    const opponent = (participants ?? []).find((p) => p.profile_id !== challengeRow.creator_id && p.status !== 'declined' && p.status !== 'withdrawn')
    const validWinnerIds = new Set([challengeRow.creator_id, opponent?.profile_id].filter((id): id is string => Boolean(id)))
    if (!validWinnerIds.has(input.winnerId)) throw new Error(invalidField(t('fieldWinner')))
    const { data: sportRow } = await supabase.from('sports').select('slug').eq('id', challengeRow.sport_id).maybeSingle()
    const mode = modeForSlug(sportRow?.slug)
    const declaredSide = input.winnerId === challengeRow.creator_id ? 0 : 1
    const computedSide = computeWinnerSide(mode, input.scoreSet1 ?? '', input.scoreSet2, input.scoreSet3)
    if (computedSide !== null && computedSide !== declaredSide) throw new Error(t('winnerScoreMismatch'))

    const { data, error } = await supabase.rpc('submit_challenge_result', {
      p_match_id: input.matchId,
      p_winner_profile_id: input.winnerId,
      p_result_data: {
        // Solo se aceptan los marcadores: sin llaves libres del cliente.
        score_set1: (input.scoreSet1 ?? '').slice(0, 8),
        score_set2: (input.scoreSet2 ?? '').slice(0, 8),
        score_set3: input.scoreSet3 ? input.scoreSet3.slice(0, 8) : null,
      },
    })
    if (error) throw error
    return actionOk(data as string)
  } catch (e) {
    return actionError(toSafeMessage(e, 'challenges.submitMatchResult'))
  }
}

// confirm = true confirma el resultado; confirm = false lo disputa (el rival puede enviar su version).
export async function confirmMatch(resultId: string, confirm: boolean): Promise<ActionResult> {
  try {
    const t = await getTranslations('Errors')
    assertUuidLike(resultId, t('fieldResult'), (field) => t('invalidField', { field }))
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    const { error } = await supabase.rpc('review_challenge_result', { p_result_id: resultId, p_confirm: confirm })
    if (error) throw error
    return actionOk(true as const)
  } catch (e) {
    return actionError(toSafeMessage(e, 'challenges.confirmMatch'))
  }
}
