'use server'

import { createClient } from '@/lib/supabase/server'
import { revalidatePath } from 'next/cache'
import { toSafeMessage } from '@/lib/safe-error'
import { safeRun, type ActionResult } from '@/lib/action-result'
import { getTranslations } from 'next-intl/server'

export async function updateProfile(input: {
  fullName: string
  username: string
  city?: string
  country?: string
}): Promise<ActionResult<boolean>> {
  return safeRun('profile.updateProfile', async () => {
    const t = await getTranslations('Errors')
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    const cleanName = input.fullName.trim()
    const cleanUsername = input.username.trim().toLowerCase()
    if (!cleanName || !cleanUsername) throw new Error(t('nameUsernameRequired'))
    const { error } = await supabase.from('profiles').update({
      display_name: cleanName,
      username: cleanUsername,
      city: input.city?.trim() || null,
      country_code: input.country?.trim().toUpperCase().slice(0,2) || null,
      updated_at: new Date().toISOString(),
    }).eq('id', user.id)
    if (error) throw new Error(toSafeMessage(error, 'profile.updateProfile'))
    revalidatePath(`/u/${cleanUsername}`)
    revalidatePath('/settings')
    return true
  })
}

export async function updateProfileSport(input: { sportId: string; skillLevel: string; isPrimary?: boolean }): Promise<ActionResult<boolean>> {
  return safeRun('profile.updateProfileSport', async () => {
    const t = await getTranslations('Errors')
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    if (input.isPrimary) {
      await supabase.from('player_sports').update({ is_primary: false, updated_at: new Date().toISOString() }).eq('profile_id', user.id)
    }
    const { error } = await supabase.from('player_sports').upsert({
      profile_id: user.id,
      sport_id: input.sportId,
      skill_level: input.skillLevel || null,
      is_primary: Boolean(input.isPrimary),
      is_discoverable: true,
      relationship: input.isPrimary ? 'primary' : 'active',
      updated_at: new Date().toISOString(),
    }, { onConflict: 'profile_id,sport_id' })
    if (error) throw new Error(toSafeMessage(error, 'profile.updateProfileSport'))
    revalidatePath('/onboarding')
    revalidatePath('/settings')
    return true
  })
}

export async function blockProfile(profileId: string): Promise<ActionResult<boolean>> {
  return safeRun('profile.blockProfile', async () => {
    const t = await getTranslations('Errors')
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user || user.id === profileId) throw new Error(t('invalidUser'))
    const { error } = await supabase.from('user_blocks').upsert({ blocker_profile_id: user.id, blocked_profile_id: profileId }, { onConflict: 'blocker_profile_id,blocked_profile_id' })
    if (error) throw new Error(toSafeMessage(error, 'profile.blockProfile'))
    revalidatePath('/players')
    return true
  })
}

export async function unblockProfile(profileId: string): Promise<ActionResult<boolean>> {
  return safeRun('profile.unblockProfile', async () => {
    const t = await getTranslations('Errors')
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    const { error } = await supabase.from('user_blocks').delete().eq('blocker_profile_id', user.id).eq('blocked_profile_id', profileId)
    if (error) throw new Error(toSafeMessage(error, 'profile.unblockProfile'))
    revalidatePath('/players')
    return true
  })
}

export async function reportContent(input: {
  targetUserId?: string
  postId?: string
  matchId?: string
  reason: string
  details?: string
}): Promise<ActionResult<boolean>> {
  return safeRun('profile.reportContent', async () => {
    const t = await getTranslations('Errors')
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    const targetType = input.matchId ? 'match' : input.postId ? 'post' : input.targetUserId ? 'profile' : 'unknown'
    const targetId = input.matchId ?? input.postId ?? input.targetUserId
    if (!targetId) throw new Error(t('reportTargetRequired'))
    const { error } = await supabase.from('content_reports').insert({
      reporter_profile_id: user.id,
      target_type: targetType,
      target_id: targetId,
      reason: input.reason.trim(),
      details: input.details?.trim() || null,
    })
    if (error) throw new Error(toSafeMessage(error, 'profile.reportContent'))
    return true
  })
}
