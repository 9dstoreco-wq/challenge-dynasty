'use client'
import { useRef } from 'react'
import { useTranslations } from 'next-intl'
import { ShieldCheck, Trophy } from 'lucide-react'
import type { DynastyCardView } from '@/lib/dynasty/cards'

// Carta coleccionable estilo Ultimate Team: rareza, brillo holografico que sigue al mouse,
// rating grande, nivel en hexagono y numero de serie.
export default function DynastyCard({ card, selected = false, onClick }: { card: DynastyCardView; selected?: boolean; onClick?: () => void }) {
  const t = useTranslations('Cards')
  const ref = useRef<HTMLDivElement>(null)

  function move(e: React.PointerEvent) {
    const el = ref.current
    if (!el) return
    const b = el.getBoundingClientRect()
    const x = (e.clientX - b.left) / b.width
    const y = (e.clientY - b.top) / b.height
    el.style.setProperty('--mx', `${x * 100}%`)
    el.style.setProperty('--my', `${y * 100}%`)
    el.style.setProperty('--ty', `${(x - 0.5) * 14}deg`)
    el.style.setProperty('--tx', `${(0.5 - y) * 14}deg`)
  }
  function leave() {
    const el = ref.current
    if (!el) return
    el.style.setProperty('--tx', '0deg')
    el.style.setProperty('--ty', '0deg')
  }

  const initial = (card.playerName.trim()[0] ?? '?').toUpperCase()
  const Tag = onClick ? 'button' : 'div'
  return (
    <Tag
      type={onClick ? 'button' : undefined}
      onClick={onClick}
      className={`block w-full max-w-[260px] text-left ${selected ? 'ring-2 ring-[#00E676] ring-offset-2 ring-offset-[#0A0A0C]' : ''}`}
      aria-pressed={onClick ? selected : undefined}
    >
      <div ref={ref} className={`dcard r-${card.rarity}`} onPointerMove={move} onPointerLeave={leave}>
        <div className="dcard-body">
          <div className="dcard-in">
            <div className="absolute left-3 top-3 z-10">
              <div className="font-display text-5xl leading-none" style={{ color: 'var(--r)' }}>{card.rating}</div>
              <div className="mt-1 text-[10px] font-black uppercase tracking-[.2em] text-white/60">{t('ratingShort')}</div>
              <div className="mt-2 text-xl leading-none">{card.sportIcon ?? '🏅'}</div>
            </div>
            <div className="absolute right-3 top-3 z-10">
              <div className="hex grid h-11 w-11 place-items-center font-display text-xl" style={{ background: 'linear-gradient(160deg,#fff9,var(--r))' }}>{card.level}</div>
              <div className="mt-1 text-center text-[9px] font-black uppercase tracking-widest text-white/50">{t('levelShort')}</div>
            </div>
            <div className="absolute inset-x-0 top-[22%] grid place-items-center">
              <div className="grid h-28 w-28 place-items-center rounded-full font-display text-7xl" style={{ color: 'var(--r)', background: 'radial-gradient(circle,rgba(255,255,255,.12),transparent 70%)', textShadow: '0 0 30px var(--r)' }}>{initial}</div>
            </div>
            <div className="absolute inset-x-0 bottom-0 z-10 bg-gradient-to-t from-black/90 via-black/60 to-transparent p-3 pt-10">
              <div className="truncate font-display text-2xl leading-none tracking-wide text-white">{card.playerName}</div>
              <div className="mt-1 flex items-center justify-between text-[10px] font-bold uppercase tracking-[.16em]">
                <span style={{ color: 'var(--r)' }}>{t(`rarity.${card.rarity}`)}</span>
                <span className="inline-flex items-center gap-1 text-white/55">
                  {card.isProtected ? <ShieldCheck size={11} /> : <Trophy size={11} />}
                  {card.isProtected ? t('baseTag') : t('trophyTag')}
                </span>
              </div>
              <div className="mt-1 text-[9px] uppercase tracking-widest text-white/35">{card.sportName ?? ''} · #{String(card.serial).padStart(4, '0')}</div>
            </div>
            <div className="dcard-holo" />
          </div>
        </div>
      </div>
    </Tag>
  )
}
