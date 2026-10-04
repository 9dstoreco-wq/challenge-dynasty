import Sidebar from '@/components/Sidebar'; import BottomNav from '@/components/BottomNav';
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'
export default async function Promote(){
  const t=await getTranslations('Promote')
  const packs=[[t('pack1Title'),t('pack1Body')],[t('pack2Title'),t('pack2Body')],[t('pack3Title'),t('pack3Body')]]
  return <div className="min-h-screen arena-bg text-white "><Sidebar/><main className="lg:pl-64 pb-20"><div className="max-w-6xl mx-auto px-4 md:px-6 py-8"><PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">DYNASTY PROMOTE</div><h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{t('title')}</h1><p className="text-white/50 mt-3">{t('subtitle')}</p></PageHero><div className="grid md:grid-cols-3 gap-4 mt-8">{packs.map(([a,b])=><div key={a} className="card-fut-plain border border-white/10 bg-[#141416] p-6"><div className="text-[#D4AF37] font-black text-xs tracking-widest">{t('packLabel')}</div><h2 className="font-black text-2xl mt-2">{a}</h2><p className="text-white/50 text-sm mt-3">{b}</p><button className="mt-6 rounded-xl bg-[#D4AF37] text-black px-4 py-3 font-black">{t('promoteBtn')}</button></div>)}</div></div></main><BottomNav/></div>
}
