import { useTranslations } from 'next-intl'

type StandingRow = { entryId: string; playerLabel: string; totalPoints: number; matchesPlayed: number }

// Tabla de posiciones de Americano/Mexicano: puntaje acumulado por JUGADOR (no por pareja, la
// pareja cambia cada ronda) — ver tournament_rotation_standings. Componente de solo lectura, sin
// interacción, así que no necesita 'use client'.
export default function TournamentRotationStandings({ categoryName, rows }: { categoryName: string; rows: StandingRow[] }) {
  const t = useTranslations('Competitions')
  if (rows.length === 0) return null
  const sorted = [...rows].sort((a, b) => b.totalPoints - a.totalPoints)

  return (
    <div className="rounded-2xl bg-white/[.03] border border-white/10 p-4">
      <div className="text-xs text-[#D4AF37] font-black uppercase tracking-widest">{categoryName}</div>
      <div className="mt-3 space-y-1.5">
        {sorted.map((row, i) => (
          <div key={row.entryId} className="flex items-center justify-between text-sm">
            <div className="flex items-center gap-2">
              <span className="text-white/30 text-xs w-5 text-right">{i + 1}</span>
              <span>{row.playerLabel}</span>
            </div>
            <div className="flex items-center gap-3 text-xs text-white/50">
              <span>{t('rotationMatchesPlayed', { count: row.matchesPlayed })}</span>
              <span className="font-black text-white">{row.totalPoints}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
