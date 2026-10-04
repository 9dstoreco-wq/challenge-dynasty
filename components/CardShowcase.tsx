import { getTranslations } from 'next-intl/server'
import DynastyCard from '@/components/DynastyCard'
import type { DynastyCardView } from '@/lib/dynasty/cards'

// Vitrina de colección: rejilla de cartas con título y estado vacío.
export default async function CardShowcase({ cards, title }: { cards: DynastyCardView[]; title?: string }) {
  const t = await getTranslations('Cards')
  return (
    <div>
      <div className="mb-3 flex items-center justify-between">
        <div className="font-display text-2xl tracking-wide">{title ?? t('showcaseTitle')}</div>
        <div className="text-xs font-bold uppercase tracking-widest text-white/40">{t('count', { count: cards.length })}</div>
      </div>
      {cards.length === 0 ? (
        <div className="card-fut-plain border border-dashed border-white/15 bg-white/[.02] p-6 text-white/45">{t('empty')}</div>
      ) : (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
          {cards.map((c, i) => (
            <div key={c.id} className="reveal" style={{ ['--i' as string]: Math.min(i, 8) }}>
              <DynastyCard card={c} />
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
