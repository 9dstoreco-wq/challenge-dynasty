import { getTranslations } from 'next-intl/server'
import LegalDocument from '@/components/LegalDocument'

export async function generateMetadata() {
  const t = await getTranslations('LegalPrivacy')
  return { title: t('title') }
}

export default async function PrivacyPage() {
  const t = await getTranslations('LegalPrivacy')
  const sections = Array.from({ length: 12 }, (_, i) => ({
    title: t(`s${i + 1}Title`),
    body: t(`s${i + 1}Body`),
  }))

  return (
    <LegalDocument
      eyebrow="CHALLENGE DYNASTY / LEGAL"
      title={t('title')}
      lastUpdated={t('lastUpdated')}
      intro={t('intro')}
      sections={sections}
      disclaimer={t('disclaimer')}
      backHomeLabel={t('backHome')}
      crossLinkHref="/legal/terms"
      crossLinkLabel={t('viewTerms')}
    />
  )
}
