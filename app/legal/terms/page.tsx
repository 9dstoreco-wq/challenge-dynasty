import { getTranslations } from 'next-intl/server'
import LegalDocument from '@/components/LegalDocument'

export async function generateMetadata() {
  const t = await getTranslations('LegalTerms')
  return { title: t('title') }
}

export default async function TermsPage() {
  const t = await getTranslations('LegalTerms')
  const sections = Array.from({ length: 14 }, (_, i) => ({
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
      crossLinkHref="/legal/privacy"
      crossLinkLabel={t('viewPrivacy')}
    />
  )
}
