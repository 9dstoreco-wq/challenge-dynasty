'use server'

import { createClient } from '@/lib/supabase/server'
import { toSafeMessage } from '@/lib/safe-error'
import { actionError, actionOk, safeRun, type ActionResult } from '@/lib/action-result'
import { getTranslations } from 'next-intl/server'
import { isAllowedVideoUrl } from '@/lib/validators'
import { checkRateLimit } from '@/lib/rate-limit'

export async function createSkillChallenge(input: {
  sportId: string
  title: string
  description?: string
  category: string
  difficulty: 'BEGINNER'|'INTERMEDIATE'|'ADVANCED'|'PRO'|'ELITE'
  points?: number
  targetVotes?: number
  expiresAt?: string | null
}): Promise<ActionResult<string>> {
  try {
    const t = await getTranslations('Errors')
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    // Hasta 15 retos de trucos creados por hora por usuario.
    if (!(await checkRateLimit(supabase, `create_skill_challenge:${user.id}`, 15, 3600))) throw new Error(t('rateLimited'))
    const { data, error } = await supabase.rpc('create_skill_challenge', {
      p_sport_id: input.sportId,
      p_title: input.title,
      p_description: input.description ?? null,
      p_category: input.category,
      p_difficulty: input.difficulty,
      p_points: input.points ?? 100,
      p_target_votes: input.targetVotes ?? 100,
      p_expires_at: input.expiresAt ?? null,
    })
    if (error) throw error
    return actionOk(data as string)
  } catch (e) {
    return actionError(toSafeMessage(e, 'skills.createSkillChallenge'))
  }
}

export async function submitSkillChallenge(input: { challengeId: string; videoUrl: string; caption?: string }): Promise<ActionResult<string>> {
  return safeRun('skills.submitSkillChallenge', async () => {
    const t = await getTranslations('Errors')
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    // Hasta 20 envios de trucos por hora por usuario.
    if (!(await checkRateLimit(supabase, `submit_skill_challenge:${user.id}`, 20, 3600))) throw new Error(t('rateLimited'))
    if (!isAllowedVideoUrl(input.videoUrl)) throw new Error(t('invalidVideoUrl'))
    const { data, error } = await supabase.rpc('submit_skill_challenge', {
      p_challenge_id: input.challengeId,
      p_video_url: input.videoUrl,
      p_caption: input.caption ?? null,
    })
    if (error) throw new Error(toSafeMessage(error, 'skills.submitSkillChallenge'))
    return data as string
  })
}

export async function voteSkillSubmission(submissionId: string, score: number): Promise<ActionResult<boolean>> {
  return safeRun('skills.voteSkillSubmission', async () => {
    const t = await getTranslations('Errors')
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    // Hasta 200 votos por hora por usuario.
    if (!(await checkRateLimit(supabase, `vote_skill:${user.id}`, 200, 3600))) throw new Error(t('rateLimited'))
    const { error } = await supabase.rpc('vote_skill_submission', {
      p_submission_id: submissionId,
      p_value: score,
    })
    if (error) throw new Error(toSafeMessage(error, 'skills.voteSkillSubmission'))
    return true
  })
}
