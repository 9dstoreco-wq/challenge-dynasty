'use server'

import { createClient } from '@/lib/supabase/server'
import { toSafeMessage } from '@/lib/safe-error'
import { getTranslations } from 'next-intl/server'

function assertUuidLike(value: string, field: string, invalidFieldMessage: (field: string) => string) {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) throw new Error(invalidFieldMessage(field))
}

export async function createChallenge(input: {
  challengedId: string
  sportId: string
  matchDate: string
  clubId?: string
  matchType?: 'DIRECT' | 'INSTANT'
  points?: number
}) {
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

  const { data, error } = await supabase.rpc('create_challenge', {
    p_challenged_id: input.challengedId,
    p_sport_id: input.sportId,
    p_match_date: input.matchDate,
    p_club_id: input.clubId ?? null,
    p_match_type: input.matchType ?? 'DIRECT',
    p_points: input.points ?? 100,
  })
  if (error) throw new Error(toSafeMessage(error, 'challenges.createChallenge'))
  return data as string
}

export async function respondToChallenge(invitationId: string, accept: boolean) {
  const t = await getTranslations('Errors')
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error(t('authRequired'))
  const { error } = await supabase.rpc('respond_to_challenge_invitation', {
    p_invitation_id: invitationId,
    p_accept: accept,
  })
  if (error) throw new Error(toSafeMessage(error, 'challenges.respondToChallenge'))
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
  const t = await getTranslations('Errors')
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error(t('authRequired'))
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
  if (error) throw new Error(toSafeMessage(error, 'challenges.submitMatchResult'))
  return data as string
}

export async function confirmMatch(resultId: string, confirm: boolean) {
  const t = await getTranslations('Errors')
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error(t('authRequired'))
  const { error } = await supabase.rpc('review_challenge_result', { p_result_id: resultId, p_confirm: confirm })
  if (error) throw new Error(toSafeMessage(error, 'challenges.confirmMatch'))
  return true
}
