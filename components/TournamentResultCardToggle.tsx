'use client'
// Boton de revelado perezoso para la carta instagrameable de un resultado ya jugado. Se usa en
// app/competitions/[id]/page.tsx (componente de servidor) para no generar la imagen con
// next/og de cada partido completado apenas carga la pagina -- solo cuando el usuario pide verla.
import { useState } from 'react'
import { Image as ImageIcon } from 'lucide-react'
import { useTranslations } from 'next-intl'
import TournamentResultCard from './TournamentResultCard'

export default function TournamentResultCardToggle({
  fixtureId,
  tournamentId,
  tournamentTitle,
}: {
  fixtureId: string
  tournamentId: string
  tournamentTitle?: string
}) {
  const t = useTranslations('TournamentResultCard')
  const [open, setOpen] = useState(false)

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className="rounded-xl border border-[#D4AF37]/30 text-[#D4AF37] px-3 py-2 text-xs font-bold flex items-center gap-2 hover:bg-[#D4AF37]/10"
      >
        <ImageIcon size={14} /> {t('viewResultCard')}
      </button>
    )
  }

  return <TournamentResultCard fixtureId={fixtureId} tournamentId={tournamentId} tournamentTitle={tournamentTitle} />
}
