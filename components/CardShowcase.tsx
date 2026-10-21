import { getTranslations } from 'next-intl/server'
import CardArchive from '@/components/CardArchive'
import type { DynastyCardView } from '@/lib/dynasty/cards'

// Vitrina de colección: envoltorio de servidor sobre el archivo interactivo.
export default async function CardShowcase({ cards, title }: { cards: DynastyCardView[]; title?: string }) {
  const t = await getTranslations('Cards')
  return <CardArchive cards={cards} title={title ?? t('showcaseTitle')} />
}
