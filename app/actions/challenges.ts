'use server'

import { createClient } from '@/lib/supabase/server'

function assertUuidLike(value: string, field: string) {
  if (!/^[0-9a-f-]{20,}$/i.test(value)) throw new Error(`Dato inválido: ${field}`)
}

export async function createChallenge(input: {
  challengedId: string
  sportId: string
  matchDate: string
  clubId?: string
  matchType?: 'DIRECT' | 'INSTANT'
  points?: number
}) {
  assertUuidLike(input.challengedId, 'rival')
  assertUuidLike(input.sportId, 'deporte')
  const parsedDate = new Date(input.matchDate)
  if (Number.isNaN(parsedDate.getTime())) throw new Error('Fecha inválida')
  if (parsedDate.getTime() <= Date.now()) throw new Error('La fecha del reto debe ser futura')
  if (input.points !== undefined && (!Number.isInteger(input.points) || input.points < 1 || input.points > 5000)) throw new Error('Los puntos deben estar entre 1 y 5000')
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Debes iniciar sesión')

  const { data, error } = await supabase.rpc('create_challenge', {
    p_challenged_id: input.challengedId,
    p_sport_id: input.sportId,
    p_match_date: input.matchDate,
    p_club_id: input.clubId ?? null,
    p_match_type: input.matchType ?? 'DIRECT',
    p_points: input.points ?? 100,
  })
  if (error) throw new Error(error.message)
  return data as string
}

export async function respondToChallenge(invitationId: string, accept: boolean) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Debes iniciar sesión')
  const { error } = await supabase.rpc('respond_to_challenge_invitation', {
    p_invitation_id: invitationId,
    p_accept: accept,
  })
  if (error) throw new Error(error.message)
  return true
}

export async function submitMatchResult(input: {
  matchId: string
  scoreSet1?: string
  scoreSet2?: string
  scoreSet3?: string | null
  winnerId: string
  resultData?: Record<string, unknown>
}) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Debes iniciar sesión')
  const { data, error } = await supabase.rpc('submit_challenge_result', {
    p_match_id: input.matchId,
    p_winner_profile_id: input.winnerId,
    p_result_data: {
      ...(input.resultData ?? {}),
      score_set1: input.scoreSet1 ?? '',
      score_set2: input.scoreSet2 ?? '',
      score_set3: input.scoreSet3 ?? null,
    },
  })
  if (error) throw new Error(error.message)
  return data as string
}

export async function confirmMatch(resultId: string, confirm: boolean) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Debes iniciar sesión')
  const { error } = await supabase.rpc('review_challenge_result', { p_result_id: resultId, p_confirm: confirm })
  if (error) throw new Error(error.message)
  return true
}

