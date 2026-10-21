import type { ReactNode } from 'react'

// Escenario de la carta destacada: rayos de luz dorados girando, pedestal con brillo
// y la carta flotando. Puro CSS (ver .spot-* en globals.css).
export default function CardSpotlight({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="spot relative mx-auto w-[220px] md:w-[280px]">
      <div aria-hidden="true" className="spot-rays" />
      <div aria-hidden="true" className="spot-pedestal" />
      <div className="relative mb-3 text-center text-[10px] font-black uppercase tracking-[.3em] text-[#D4AF37]">{label}</div>
      <div className="spot-float relative">{children}</div>
    </div>
  )
}
