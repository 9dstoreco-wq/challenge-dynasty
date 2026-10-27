'use client'
import { useTranslations } from 'next-intl'
import ShareableCardPanel from './ShareableCardPanel'

export default function PlayerCard({
  profileId,
  playerName,
  username,
  matchId,
}: {
  profileId: string
  playerName?: string
  username?: string
  matchId?: string
}) {
  const t = useTranslations('PlayerCard')

  // El banner de "GANO/PERDIO" y el XP los calcula el propio endpoint a partir del partido real
  // (matchId); ya no se le puede pasar un resultado o un rival armado desde el cliente.
  const params = new URLSearchParams()
  if (matchId) params.set('match', matchId)
  const query = params.toString()
  const imgSrc = `/api/cards/${profileId}${query ? `?${query}` : ''}`

  // Enlace publico que se comparte: el perfil del jugador (se ve sin sesion). Sin username, la pagina actual.
  const shareUrl = typeof window !== 'undefined' ? (username ? `${window.location.origin}/u/${username}` : window.location.href) : ''

  return (
    <ShareableCardPanel
      panelTitle={t('title')}
      imgSrc={imgSrc}
      downloadFilename={`dynasty-carta-${playerName ?? profileId}.png`}
      shareText={t('shareText', { name: playerName ?? '' })}
      shareUrl={shareUrl}
    />
  )
}
