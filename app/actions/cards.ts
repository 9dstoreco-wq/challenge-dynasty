'use server'

import { createClient } from '@/lib/supabase/server'
import { toSafeMessage } from '@/lib/safe-error'
import { getTranslations } from 'next-intl/server'

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

// Pone una carta propia en juego en un reto. Todas las reglas (dueño, deporte, carta base
// protegida, bloqueo mutuo) las valida la funcion SQL stake_card_on_challenge.
export async function stakeCard(challengeId: string, cardId: string) {
  const t = await getTranslations('Errors')
  if (!UUID.test(challengeId) || !UUID.test(cardId)) throw new Error(t('invalidField', { field: 'id' }))
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error(t('authRequired'))
  const { error } = await supabase.rpc('stake_card_on_challenge', { p_challenge_id: challengeId, p_card_id: cardId })
  if (error) throw new Error(toSafeMessage(error, 'cards.stakeCard'))
  return true
}

export async function withdrawCardStake(challengeId: string) {
  const t = await getTranslations('Errors')
  if (!UUID.test(challengeId)) throw new Error(t('invalidField', { field: 'id' }))
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error(t('authRequired'))
  const { error } = await supabase.rpc('withdraw_card_stake', { p_challenge_id: challengeId })
  if (error) throw new Error(toSafeMessage(error, 'cards.withdrawCardStake'))
  return true
}
