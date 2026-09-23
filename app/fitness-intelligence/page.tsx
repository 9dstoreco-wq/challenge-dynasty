import DynastyAIContextPanel from '@/components/DynastyAIContextPanel'
import DynastyAIChat from '@/components/DynastyAIChat'
import Sidebar from '@/components/Sidebar'
import { getTranslations } from 'next-intl/server'

export default async function Page() {
  const t = await getTranslations('Intelligence')
  return (
    <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-10 p-6 md:p-10">
      <div className="mx-auto max-w-5xl">
        <p className="text-xs font-black tracking-[0.35em] uppercase opacity-60">{t('tag')}</p>
        <h1 className="mt-3 text-4xl font-display font-black tracking-wide tracking-tight">{t('fitnessTitle')}</h1>
        <p className="mt-3 max-w-2xl text-lg opacity-70">{t('fitnessSubtitle')}</p>
        <DynastyAIContextPanel area="Fitness Intelligence" />
        <DynastyAIChat mode="fitness" placeholder={t('fitnessPlaceholder')} />
      </div>
    </main></div>
  )
}
