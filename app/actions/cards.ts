'use server'

import { createClient } from '@/lib/supabase/server'
import { toSafeMessage } from '@/lib/safe-error'
import { actionError, actionOk, type ActionResult } from '@/lib/action-result'
import { getTranslations } from 'next-intl/server'
import { checkRateLimit } from '@/lib/rate-limit'

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

// Pone una carta propia en juego en un reto. Todas las reglas (dueño, deporte, carta base
// protegida, bloqueo mutuo) las valida la funcion SQL stake_card_on_challenge.
export async function stakeCard(challengeId: string, cardId: string): Promise<ActionResult> {
  try {
    const t = await getTranslations('Errors')
    if (!UUID.test(challengeId) || !UUID.test(cardId)) throw new Error(t('invalidField', { field: 'id' }))
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    // Hasta 30 cartas puestas en juego por hora por usuario.
    if (!(await checkRateLimit(supabase, `stake_card:${user.id}`, 30, 3600))) throw new Error(t('rateLimited'))
    const { error } = await supabase.rpc('stake_card_on_challenge', { p_challenge_id: challengeId, p_card_id: cardId })
    if (error) throw error
    return actionOk(true as const)
  } catch (e) {
    return actionError(toSafeMessage(e, 'cards.stakeCard'))
  }
}

export async function withdrawCardStake(challengeId: string): Promise<ActionResult> {
  try {
    const t = await getTranslations('Errors')
    if (!UUID.test(challengeId)) throw new Error(t('invalidField', { field: 'id' }))
    const supabase = await createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error(t('authRequired'))
    const { error } = await supabase.rpc('withdraw_card_stake', { p_challenge_id: challengeId })
    if (error) throw error
    return actionOk(true as const)
  } catch (e) {
    return actionError(toSafeMessage(e, 'cards.withdrawCardStake'))
  }
}
