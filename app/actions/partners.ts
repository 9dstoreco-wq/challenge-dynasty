'use server'

/**
 * Partner invitations are intentionally not exposed until the backend contract
 * exists in the live Dynasty schema. Keeping this action explicit prevents a
 * legacy RPC from being called accidentally.
 */
export async function requestPartner(_input: { sportId: string; recipientId: string }) {
  throw new Error('Las invitaciones de partner aún no están conectadas al motor social actual de Dynasty.')
}
