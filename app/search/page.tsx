import Link from 'next/link'
export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'

export default async function SearchPage({searchParams}:{searchParams?:Promise<{q?:string}>}){
  const resolvedSearchParams = searchParams ? await searchParams : {}
  const t = await getTranslations('Search')
  const q=(resolvedSearchParams?.q??'').trim(); const safeQ=q.replace(/[(),]/g,' '); const supabase=await createClient()
  const {data:players}=q ? await supabase.from('profiles').select('id,username,display_name,city,country_code').or(`display_name.ilike.%${safeQ}%,username.ilike.%${safeQ}%,city.ilike.%${safeQ}%`).order('display_name',{ascending:true}).limit(30) : {data:[]}
  const sport=await supabase.from('sports').select('id').eq('slug','padel').maybeSingle()
  const playerIds=(players??[]).map((p)=>p.id)
  const {data:rankings}=sport.data&&playerIds.length?await supabase.from('sport_rankings').select('profile_id,rating,rank').eq('sport_id',sport.data.id).in('profile_id',playerIds):{data:[]}
  const rankingById=new Map((rankings??[]).map((r)=>[r.profile_id,r]))
  return <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-6xl mx-auto px-4 md:px-6 py-8"><PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">DISCOVERY</div><h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{t('title')}</h1></PageHero><form className="mt-6 flex gap-3"><input name="q" defaultValue={q} placeholder={t('placeholder')} className="flex-1 rounded-2xl bg-white/5 border border-white/10 px-5 py-4 outline-none"/><button className="rounded-2xl bg-[#D4AF37] text-black px-6 font-black">{t('searchBtn')}</button></form>{q&&<div className="mt-7 grid md:grid-cols-3 gap-4">{(players??[]).map((p)=>{const r=rankingById.get(p.id);return <Link href={`/u/${p.username}`} key={p.username} className="rounded-3xl border border-white/10 bg-[#161616] p-5 hover:border-gold-300/30"><div className="text-xs text-[#D4AF37]">{r?.rank?`#${r.rank}`:t('noRanking')} {r?.rating!=null?`· ${Number(r.rating).toFixed(0)} PTS`:''}</div><div className="font-black text-xl mt-2">{p.display_name}</div><div className="text-sm text-white/40 mt-1">@{p.username} · {p.city||t('locationUnknown')}</div></Link>})}{(players??[]).length===0&&<div className="md:col-span-3 rounded-3xl border border-white/10 bg-[#161616] p-8 text-center text-white/45">{t('noResults',{q})}</div>}</div>}{!q&&<div className="mt-12 rounded-3xl border border-white/10 bg-[#161616] p-8 text-center text-white/45">{t('prompt')}</div>}</div></main><BottomNav/></div>
}
