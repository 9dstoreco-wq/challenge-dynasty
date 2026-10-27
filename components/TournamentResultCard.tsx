'use client'
// Carta instagrameable del resultado de un partido de torneo (pedida por Luis el 2026-10-26:
// "que mandara como una carta de como quedo el partido, para que lo instagrameen"). Wrapper fino
// analogo a PlayerCard.tsx: calcula los datos de esta carta en particular y delega el
// compartir/descargar en ShareableCardPanel.tsx (el mismo panel que usa la carta de jugador).
import { useTranslations } from 'next-intl'
import ShareableCardPanel from './ShareableCardPanel'

export default function TournamentResultCard({
  fixtureId,
  tournamentId,
  tournamentTitle,
}: {
  fixtureId: string
  tournamentId: string
  tournamentTitle?: string
}) {
  const t = useTranslations('TournamentResultCard')

  const imgSrc = `/api/cards/tournament-fixture/${fixtureId}`

  // Enlace publico que se comparte: la pagina del torneo (se ve sin sesion si el torneo es publico).
  const shareUrl = typeof window !== 'undefined' ? `${window.location.origin}/competitions/${tournamentId}` : ''

  return (
    <ShareableCardPanel
      panelTitle={t('title')}
      imgSrc={imgSrc}
      downloadFilename={`dynasty-resultado-${fixtureId}.png`}
      shareText={t('shareText', { tournament: tournamentTitle ?? 'Challenge Dynasty' })}
      shareUrl={shareUrl}
    />
  )
}
