import PageHero from '@/components/PageHero'
import { Target } from 'lucide-react'
import { getTranslations } from 'next-intl/server'
export default async function Missions(){
  const t=await getTranslations('Missions')
  return <main className="min-h-screen bg-[#0A0A0C] text-white px-4 md:px-8 py-8"><div className="max-w-5xl mx-auto"><PageHero><div className="flex items-center gap-2 text-xs tracking-[.3em] text-[#D4AF37] font-black"><Target size={15}/> DAILY + SEASONAL</div><h1 className="text-4xl md:text-5xl font-display font-black tracking-wide mt-2">{t('title')}</h1><p className="text-white/45 mt-2">{t('subtitle')}</p></PageHero><div className="rounded-3xl border border-white/10 bg-[#161616] p-8 text-center mt-7"><p className="text-white/45">{t('notice')}</p></div></div></main>
}
