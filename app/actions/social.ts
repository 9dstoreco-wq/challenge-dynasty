'use server'

import { createClient } from '@/lib/supabase/server'
import { revalidatePath } from 'next/cache'

// Canonical partner action lives in partners.ts; re-export to preserve existing imports.
export { respondToPartnerRequest } from './partners'

export async function createPost(content: string, title?: string) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Debes iniciar sesión')
  const clean = content.trim()
  if (!clean || clean.length > 2000) throw new Error('El post debe tener entre 1 y 2000 caracteres')
  const { data, error } = await supabase.from('social_posts').insert({
    author_profile_id: user.id,
    post_type: 'USER_POST',
    body: title ? `${title}\n\n${clean}` : clean,
    visibility: 'public',
  }).select('id').single()
  if (error) throw new Error(error.message)
  return data.id as string
}

export async function addComment(postId: string, content: string) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Debes iniciar sesión')
  const clean = content.trim()
  if (!clean || clean.length > 600) throw new Error('El comentario debe tener entre 1 y 600 caracteres')
  const { error } = await supabase.from('social_comments').insert({ post_id: postId, author_profile_id: user.id, body: clean, status: 'visible' })
  if (error) throw new Error(error.message)
  return true
}

export async function toggleFollow(followingId: string) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Debes iniciar sesión')
  if (user.id === followingId) throw new Error('No puedes seguirte a ti mismo')
  const { data: blocked } = await supabase.from('user_blocks').select('blocker_profile_id').or(`and(blocker_profile_id.eq.${user.id},blocked_profile_id.eq.${followingId}),and(blocker_profile_id.eq.${followingId},blocked_profile_id.eq.${user.id})`).limit(1)
  if (blocked && blocked.length) throw new Error('No puedes seguir a este jugador')
  const { data: existing } = await supabase.from('social_follows').select('id').eq('follower_profile_id', user.id).eq('followed_profile_id', followingId).maybeSingle()
  if (existing) {
    const { error } = await supabase.from('social_follows').delete().eq('follower_profile_id', user.id).eq('followed_profile_id', followingId)
    if (error) throw new Error(error.message)
    revalidatePath(`/u/${followingId}`)
    return false
  }
  const { error } = await supabase.from('social_follows').insert({ follower_profile_id: user.id, followed_profile_id: followingId })
  if (error) throw new Error(error.message)
  return true
}


export async function toggleLike(postId: string) {
  const supabase=createClient(); const {data:{user}}=await supabase.auth.getUser(); if(!user) throw new Error('Debes iniciar sesión')
  const {data:existing}=await supabase.from('social_reactions').select('id').eq('post_id',postId).eq('profile_id',user.id).eq('reaction_type','like').maybeSingle()
  if(existing){ const {error}=await supabase.from('social_reactions').delete().eq('post_id',postId).eq('profile_id',user.id).eq('reaction_type','like'); if(error) throw new Error(error.message); revalidatePath('/'); return false }
  const {error}=await supabase.from('social_reactions').insert({post_id:postId,profile_id:user.id,reaction_type:'like'}); if(error) throw new Error(error.message); revalidatePath('/'); return true
}

export async function markNotificationRead(notificationId: string) {
  const supabase=createClient(); const {data:{user}}=await supabase.auth.getUser(); if(!user) throw new Error('Debes iniciar sesión')
  const {error}=await supabase.rpc('mark_notification_read',{p_notification_id:notificationId}); if(error) throw new Error(error.message); revalidatePath('/notifications')
}

export async function markAllNotificationsRead(){ const supabase=createClient(); const {data:{user}}=await supabase.auth.getUser(); if(!user) throw new Error('Debes iniciar sesión'); const {error}=await supabase.rpc('mark_all_notifications_read'); if(error) throw new Error(error.message); revalidatePath('/notifications'); return true }
