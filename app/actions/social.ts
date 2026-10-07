'use server'

import { createClient } from '@/lib/supabase/server'
import { revalidatePath } from 'next/cache'
import { toSafeMessage } from '@/lib/safe-error'
import { safeRun, type ActionResult } from '@/lib/action-result'
import { getTranslations } from 'next-intl/server'
import { checkRateLimit } from '@/lib/rate-limit'

// Canonical partner action lives in partners.ts; re-export to preserve existing imports.
import { respondToPartnerRequest as respondToPartnerRequestCore } from './partners'

export async function respondToPartnerRequest(requestId: string, response: 'ACCEPTED' | 'REJECTED'): Promise<ActionResult<boolean>> {
  return respondToPartnerRequestCore(requestId, response)
}

export async function createPost(content: string, title?: string): Promise<ActionResult<string>> {
  return safeRun('social.createPost', async () => {
    const t = await getTranslations('Errors')
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    // Hasta 20 publicaciones por hora por usuario.
    if (!(await checkRateLimit(supabase, `create_post:${user.id}`, 20, 3600))) throw new Error(t('rateLimited'))
    const clean = content.trim()
    if (!clean || clean.length > 2000) throw new Error(t('postLength'))
    const { data, error } = await supabase.from('social_posts').insert({
      author_profile_id: user.id,
      post_type: 'text',
      body: title ? `${title}\n\n${clean}` : clean,
      visibility: 'public',
    }).select('id').single()
    if (error) throw new Error(toSafeMessage(error, 'social.createPost'))
    return data.id as string
  })
}

export async function addComment(postId: string, content: string): Promise<ActionResult<boolean>> {
  return safeRun('social.addComment', async () => {
    const t = await getTranslations('Errors')
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    const clean = content.trim()
    if (!clean || clean.length > 600) throw new Error(t('commentLength'))
    const { error } = await supabase.from('social_comments').insert({ post_id: postId, author_profile_id: user.id, body: clean, status: 'visible' })
    if (error) throw new Error(toSafeMessage(error, 'social.addComment'))
    return true
  })
}

export async function toggleFollow(followingId: string): Promise<ActionResult<boolean>> {
  return safeRun('social.toggleFollow', async () => {
    const t = await getTranslations('Errors')
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(followingId)) throw new Error(t('invalidUser'))
    if (user.id === followingId) throw new Error(t('cannotFollowSelf'))
    const { data: blocked } = await supabase.from('user_blocks').select('blocker_profile_id').or(`and(blocker_profile_id.eq.${user.id},blocked_profile_id.eq.${followingId}),and(blocker_profile_id.eq.${followingId},blocked_profile_id.eq.${user.id})`).limit(1)
    if (blocked && blocked.length) throw new Error(t('cannotFollowBlocked'))
    const { data: existing } = await supabase.from('social_follows').select('id').eq('follower_profile_id', user.id).eq('followed_profile_id', followingId).maybeSingle()
    if (existing) {
      const { error } = await supabase.from('social_follows').delete().eq('follower_profile_id', user.id).eq('followed_profile_id', followingId)
      if (error) throw new Error(toSafeMessage(error, 'social.toggleFollow.unfollow'))
      revalidatePath(`/u/${followingId}`)
      return false
    }
    const { error } = await supabase.from('social_follows').insert({ follower_profile_id: user.id, followed_profile_id: followingId })
    if (error) throw new Error(toSafeMessage(error, 'social.toggleFollow.follow'))
    return true
  })
}


export async function toggleLike(postId: string): Promise<ActionResult<boolean>> {
  return safeRun('social.toggleLike', async () => {
    const t = await getTranslations('Errors')
    const supabase=await createClient(); const {data:{user}}=await supabase.auth.getUser(); if(!user) throw new Error(t('authRequired'))
    const {data:existing}=await supabase.from('social_reactions').select('id').eq('post_id',postId).eq('profile_id',user.id).eq('reaction_type','like').maybeSingle()
    if(existing){ const {error}=await supabase.from('social_reactions').delete().eq('post_id',postId).eq('profile_id',user.id).eq('reaction_type','like'); if(error) throw new Error(toSafeMessage(error, 'social.toggleLike.unlike')); revalidatePath('/'); return false }
    const {error}=await supabase.from('social_reactions').insert({post_id:postId,profile_id:user.id,reaction_type:'like'}); if(error) throw new Error(toSafeMessage(error, 'social.toggleLike.like')); revalidatePath('/'); return true
  })
}

export async function markNotificationRead(notificationId: string): Promise<ActionResult<boolean>> {
  return safeRun('social.markNotificationRead', async () => {
    const t = await getTranslations('Errors')
    const supabase=await createClient(); const {data:{user}}=await supabase.auth.getUser(); if(!user) throw new Error(t('authRequired'))
    const {error}=await supabase.rpc('mark_notification_read',{p_notification_id:notificationId}); if(error) throw new Error(toSafeMessage(error, 'social.markNotificationRead')); revalidatePath('/notifications')
    return true
  })
}

export async function markAllNotificationsRead(): Promise<ActionResult<boolean>> {
  return safeRun('social.markAllNotificationsRead', async () => {
    const t = await getTranslations('Errors')
    const supabase=await createClient(); const {data:{user}}=await supabase.auth.getUser(); if(!user) throw new Error(t('authRequired'))
    const {error}=await supabase.rpc('mark_all_notifications_read'); if(error) throw new Error(toSafeMessage(error, 'social.markAllNotificationsRead'))
    revalidatePath('/notifications')
    return true
  })
}
