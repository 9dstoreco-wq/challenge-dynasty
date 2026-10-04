import type { ReactNode } from 'react'
// Casilla de estadistica con esquinas cortadas, para tableros HUD.
export default function StatTile({ label, value, icon, accent = false }: { label: string; value: ReactNode; icon?: ReactNode; accent?: boolean }) {
  return (
    <div className="card-fut">
      <div className="card-fut-in p-4">
        <div className="flex items-center gap-2 text-[10px] font-bold uppercase tracking-[.2em] text-white/45">{icon}{label}</div>
        <div className={`mt-2 font-display text-3xl leading-none tracking-wide ${accent ? 'text-[#D4AF37]' : 'text-white'}`}>{value}</div>
      </div>
    </div>
  )
}
