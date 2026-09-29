export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import PageHero from '@/components/PageHero'
import ClubRegisterForm from '@/components/ClubRegisterForm'
import { getTranslations } from 'next-intl/server'

export default async function ClubRegisterPage() {
  const t = await getTranslations('ClubRegister')
  return (
    <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg">
      <Sidebar />
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="max-w-2xl mx-auto px-4 md:px-6 py-8">
          <PageHero>
            <div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">{t('tag')}</div>
            <h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{t('title')}</h1>
            <p className="text-white/50 mt-3 max-w-xl">{t('subtitle')}</p>
          </PageHero>
          <div className="mt-7">
            <ClubRegisterForm />
          </div>
        </div>
      </main>
      <BottomNav />
    </div>
  )
}
