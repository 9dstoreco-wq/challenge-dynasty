'use client'
import { useMemo, useState } from 'react'
import { useTranslations } from 'next-intl'
import DynastyCard from '@/components/DynastyCard'
import type { DynastyCardView } from '@/lib/dynasty/cards'

const RARITIES = ['legendary', 'epic', 'rare', 'common'] as const
type Filter = 'all' | (typeof RARITIES)[number]

// Archivo de cartas (estilo "helmet archive" de landonorris.com):
// filtro por rareza con contador, rejilla que re-entra animada al cambiar de filtro.
export default function CardArchive({ cards, title }: { cards: DynastyCardView[]; title: string }) {
  const t = useTranslations('Cards')
  const [filter, setFilter] = useState<Filter>('all')
  const counts = useMemo(() => {
    const c: Record<string, number> = {}
    for (const card of cards) c[card.rarity] = (c[card.rarity] ?? 0) + 1
    return c
  }, [cards])
  const shown = filter === 'all' ? cards : cards.filter((c) => c.rarity === filter)
  const chips: { id: Filter; label: string; n: number }[] = [
    { id: 'all', label: t('filterAll'), n: cards.length },
    ...RARITIES.filter((r) => counts[r]).map((r) => ({ id: r, label: t(`rarity.${r}`), n: counts[r] })),
  ]

  return (
    <section>
      <div className="mb-5 flex flex-wrap items-end justify-between gap-4">
        <h2 className="font-display text-4xl md:text-6xl leading-none tracking-wide">{title}</h2>
        <div className="text-xs font-bold uppercase tracking-widest text-white/45 tabular-nums">{t('count', { count: cards.length })}</div>
      </div>
      {cards.length === 0 ? (
        <div className="card-fut-plain border border-dashed border-white/15 bg-white/[.02] p-6 text-white/55">{t('empty')}</div>
      ) : (
        <>
          {chips.length > 2 && (
            <div role="group" aria-label={t('filterLabel')} className="mb-6 flex flex-wrap gap-2">
              {chips.map((c) => {
                const on = filter === c.id
                return (
                  <button
                    key={c.id}
                    type="button"
                    aria-pressed={on}
                    onClick={() => setFilter(c.id)}
                    className={`archive-chip ${c.id === 'all' ? '' : `r-${c.id}`} min-h-[44px] rounded-full border px-5 text-xs font-black uppercase tracking-[.18em] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#D4AF37] ${on ? 'is-on' : ''}`}
                  >
                    {c.label} <span className="tabular-nums opacity-60">{c.n}</span>
                  </button>
                )
              })}
            </div>
          )}
          <div key={filter} className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
            {shown.map((c, i) => (
              <div key={c.id} className="archive-item reveal" style={{ ['--i' as string]: Math.min(i, 10) }}>
                <DynastyCard card={c} />
              </div>
            ))}
          </div>
        </>
      )}
    </section>
  )
}
