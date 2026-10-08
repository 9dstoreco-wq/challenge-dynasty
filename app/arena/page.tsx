import { relatedRow } from '@/app/arena/related-row'
import Link from 'next/link'
export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import { getTranslations, getLocale } from 'next-intl/server'

const CHALLENGE_STATUSES = ['open', 'scheduled', 'active', 'completed', 'cancelled', 'creator', 'pending', 'accepted', 'declined', 'withdrawn', 'invited', 'none', 'expired']

export default async function ArenaIndex(){
  const supabase=await createClient()
  const t=await getTranslations('Arena'); const tChallenge=await getTranslations('Challenge'); const locale=await getLocale(); const dateLocale=locale==='en'?'en-US':'es-CO'
  const statusLabel=(s:string)=>(CHALLENGE_STATUSES.includes(s)?tChallenge(`status.${s}`):s)
  const {data: challenges}=await supabase.from('challenges').select('id,title,status,scheduled_at,location_name,sport:sports(name)').eq('status','open').order('scheduled_at',{ascending:true}).limit(24)
  const ids=(challenges??[]).map((c)=>c.id)
  const {data: participants}=ids.length?await supabase.from('challenge_participants').select('challenge_id,profile_id,role,status,profile:profiles!challenge_participants_profile_id_fkey(username,display_name)').in('challenge_id',ids).in('status',['accepted','invited']):{data:[]}
  const grouped=new Map<string, Array<NonNullable<typeof participants>[number]>>()
  for(const p of participants??[]){const arr=grouped.get(p.challenge_id)??[];arr.push(p);grouped.set(p.challenge_id,arr)}
  return <div className="min-h-screen arena-bg text-white "><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-6xl mx-auto px-4 md:px-6 py-8"><PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">ARENA</div><h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{t('title')}</h1><p className="text-white/50 mt-2">{t('subtitle')}</p></PageHero><div className="grid md:grid-cols-2 gap-4 mt-7">{(challenges??[]).map((c)=>{const ps=grouped.get(c.id)??[];const creator=relatedRow(ps.find(p=>p.role==='creator')?.profile);const rival=relatedRow(ps.find(p=>p.profile_id!==ps.find(x=>x.role==='creator')?.profile_id && p.status!=='declined')?.profile);return <Link href={`/challenge/${c.id}`} key={c.id} className="card-fut-plain border border-white/10 bg-[#141416] p-5 hover:border-gold-400/30 transition"><div className="flex justify-between text-xs"><span className="text-gold-300 font-black">{relatedRow(c.sport)?.name??t('defaultSport')}</span><span className="text-[#00E676]">{statusLabel(c.status)}</span></div><div className="text-2xl font-black mt-4">{creator?.display_name??t('defaultPlayer')} <span className="text-white/20">VS</span> {rival?.display_name??t('defaultRival')}</div><div className="text-sm text-white/45 mt-2">{c.scheduled_at?new Date(c.scheduled_at).toLocaleString(dateLocale):t('tbd')} · {c.location_name??t('locationTbd')}</div></Link>})}{(challenges??[]).length===0&&<div className="md:col-span-2 card-fut-plain border border-white/10 bg-[#141416] p-8 text-center text-white/45">{t('empty')}</div>}</div></div></main><BottomNav/></div>
}
