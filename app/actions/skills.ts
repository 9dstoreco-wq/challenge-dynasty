'use server'

import { createClient } from '@/lib/supabase/server'

export async function createSkillChallenge(input: {
  sportId: string
  title: string
  description?: string
  category: string
  difficulty: 'BEGINNER'|'INTERMEDIATE'|'ADVANCED'|'PRO'|'ELITE'
  points?: number
  targetVotes?: number
  expiresAt?: string | null
}) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Debes iniciar sesión')
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
  if (error) throw new Error(error.message)
  return data as string
}

export async function submitSkillChallenge(input: { challengeId: string; videoUrl: string; caption?: string }) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Debes iniciar sesión')
  const { data, error } = await supabase.rpc('submit_skill_challenge', {
    p_challenge_id: input.challengeId,
    p_video_url: input.videoUrl,
    p_caption: input.caption ?? null,
  })
  if (error) throw new Error(error.message)
  return data as string
}

export async function voteSkillSubmission(submissionId: string, score: number) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Debes iniciar sesión')
  const { error } = await supabase.rpc('vote_skill_submission', {
    p_submission_id: submissionId,
    p_value: score,
  })
  if (error) throw new Error(error.message)
  return true
}
