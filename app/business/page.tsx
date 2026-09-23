export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'

export default async function Business(){
  const supabase = await createClient()
  const t = await getTranslations('Business')
  const { data: plansData } = await supabase
    .from('billing_plans')
    .select('id,code,name,audience_type,description,billing_interval,price,currency_code,is_active')
    .eq('is_active', true)
    .order('price', { ascending: true })
  const plans = plansData ?? []

  return <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20"><div className="max-w-6xl mx-auto px-4 md:px-6 py-8">
    <PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">{t('tag')}</div>
    <h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{t('title')}</h1>
    <p className="text-white/55 mt-3 max-w-3xl">{t('subtitle')}</p></PageHero>

    <div className="mt-8 rounded-3xl border border-white/10 bg-[#161616] p-6">
      <div className="flex items-center justify-between gap-4"><div><div className="text-xs text-[#D4AF37] font-black tracking-widest">{t('plansTag')}</div><h2 className="text-2xl font-black mt-1">{t('plansTitle')}</h2></div><span className="rounded-full border border-white/10 px-3 py-1 text-xs font-black">{t('activeCount',{count:plans.length})}</span></div>
      {plans.length === 0 ? <div className="mt-5 rounded-2xl border border-dashed border-white/15 p-6 text-white/50">{t('emptyPlans')}</div> : <div className="grid md:grid-cols-2 xl:grid-cols-3 gap-4 mt-5">{plans.map((p)=><div key={p.id} className="rounded-2xl border border-white/10 bg-black/10 p-5"><div className="text-xs text-[#D4AF37] font-black uppercase tracking-widest">{p.audience_type}</div><h3 className="text-xl font-black mt-2">{p.name}</h3><p className="text-white/45 text-sm mt-2 min-h-10">{p.description || t('defaultPlanDesc')}</p><div className="mt-4 text-2xl font-black">{Number(p.price).toLocaleString('es-CO')} {p.currency_code}</div><div className="text-xs text-white/40 mt-1">{p.billing_interval}</div></div>)}</div>}
    </div>

    <section className="mt-8 rounded-3xl border border-[#D4AF37]/20 bg-[#D4AF37]/5 p-6"><h2 className="text-2xl font-black">{t('cycleTitle')}</h2><div className="flex flex-wrap gap-2 mt-4 text-sm font-black">{[t('statusActive'),t('statusExpired'),t('statusGrace'),t('statusRestricted'),t('statusSuspended')].map(x=><span key={x} className="rounded-full border border-white/10 bg-black/20 px-4 py-2">{x}</span>)}</div><p className="text-white/50 text-sm mt-4">{t('cycleBody')}</p></section>
  </div></main><BottomNav/></div>
}
