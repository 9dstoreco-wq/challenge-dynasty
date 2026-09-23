export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'

export default async function SeasonPage(){
  const supabase = await createClient()
  const t = await getTranslations('Season')
  const { data: tournamentsData } = await supabase.from('tournaments').select('id,title,status,starts_at,ends_at').order('starts_at',{ascending:true}).limit(20)
  const tournaments = tournamentsData ?? []
  return <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-5xl mx-auto px-4 md:px-6 py-8"><PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">CHALLENGE SEASON</div><h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{t('title')}</h1><p className="text-white/50 mt-2">{t('subtitle')}</p></PageHero><div className="mt-7 rounded-3xl border border-white/10 bg-[#161616] p-8">{tournaments.length===0?<div className="text-center text-white/45">{t('empty')}</div>:<div className="space-y-3">{tournaments.map((t2)=><div key={t2.id} className="rounded-2xl border border-white/10 p-4 flex items-center justify-between"><div><div className="font-black">{t2.title}</div><div className="text-xs text-white/40 mt-1">{t2.starts_at || t('noDate')}{t2.ends_at?` → ${t2.ends_at}`:''}</div></div><span className="text-xs font-black text-[#D4AF37]">{t2.status}</span></div>)}</div>}</div></div></main><BottomNav/></div>
}
