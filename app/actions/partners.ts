'use server'

import { createClient } from '@/lib/supabase/server'

export async function requestPartner({ sportId, recipientId }: { sportId: string; recipientId: string }) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Debes iniciar sesión')
  if (user.id === recipientId) throw new Error('No puedes invitarte a ti mismo')
  const { data, error } = await supabase.rpc('request_partner', {
    p_sport_id: sportId,
    p_recipient_id: recipientId,
  })
  if (error) throw new Error(error.message)
  return data as string
}

export async function respondToPartnerRequest(requestId: string, response: 'ACCEPTED' | 'REJECTED') {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Debes iniciar sesión')
  const { error } = await supabase.rpc('respond_to_partner_request', {
    p_request_id: requestId,
    p_response: response,
  })
  if (error) throw new Error(error.message)
  return true
}
