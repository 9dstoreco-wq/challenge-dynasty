import Link from "next/link";
import Sidebar from '@/components/Sidebar'
import { getTranslations } from 'next-intl/server'

export default async function IntelligencePage() {
  const t = await getTranslations('Intelligence')
  const cards = [
    [t('card1Title'), t('card1Tagline'), t('card1Detail'), "/coach-ai"],
    [t('card2Title'), t('card2Tagline'), t('card2Detail'), "/fitness-intelligence"],
    [t('card3Title'), t('card3Tagline'), t('card3Detail'), "/club-intelligence"],
    [t('card4Title'), t('card4Tagline'), t('card4Detail'), "/coach-intelligence"],
    [t('card5Title'), t('card5Tagline'), t('card5Detail'), "/tournament-intelligence"],
    [t('card6Title'), t('card6Tagline'), t('card6Detail'), "/commerce-intelligence"],
  ] as const;
  return (
    <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-10 p-6 md:p-10">
      <div className="mx-auto max-w-6xl">
        <div className="mb-10">
          <p className="text-xs font-black tracking-[0.35em] uppercase opacity-60">{t('tag')}</p>
          <h1 className="mt-3 text-4xl md:text-6xl font-display font-black tracking-wide tracking-tight">
            {t('hubTitle')}
          </h1>
          <p className="mt-4 max-w-2xl text-base md:text-lg opacity-70">
            {t('hubSubtitle')}
          </p>
        </div>

        <section className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {cards.map(([title, tagline, detail, href]) => (
            <Link
              key={title}
              href={href}
              className="rounded-3xl border border-white/10 bg-white/5 p-6 block hover:border-[#D4AF37]/40 hover:bg-white/[0.07] transition-colors"
            >
              <h2 className="text-xl font-black">{title}</h2>
              <p className="mt-2 font-semibold">{tagline}</p>
              <p className="mt-2 text-sm opacity-65">{detail}</p>
            </Link>
          ))}
        </section>

        <div className="mt-10 flex flex-wrap gap-3">
          <Link href="/business" className="rounded-full border border-white/15 px-5 py-3 text-sm font-bold">
            {t('viewBusiness')}
          </Link>
          <Link href="/shop" className="rounded-full border border-white/15 px-5 py-3 text-sm font-bold">
            {t('viewShop')}
          </Link>
          <Link href="/marketplace" className="rounded-full border border-white/15 px-5 py-3 text-sm font-bold">
            {t('viewMarketplace')}
          </Link>
        </div>
      </div>
    </main></div>
  );
}
