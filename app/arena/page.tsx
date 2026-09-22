import { relatedRow } from '@/app/arena/related-row'
import Link from 'next/link'
export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'

export default async function ArenaIndex(){
  const supabase=await createClient()
  const {data: challenges}=await supabase.from('challenges').select('id,title,status,scheduled_at,location_name,sport:sports(name)').eq('status','open').order('scheduled_at',{ascending:true}).limit(24)
  const ids=(challenges??[]).map((c)=>c.id)
  const {data: participants}=ids.length?await supabase.from('challenge_participants').select('challenge_id,profile_id,role,status,profile:profiles!challenge_participants_profile_id_fkey(username,display_name)').in('challenge_id',ids).in('status',['accepted','invited']):{data:[]}
  const grouped=new Map<string, Array<NonNullable<typeof participants>[number]>>()
  for(const p of participants??[]){const arr=grouped.get(p.challenge_id)??[];arr.push(p);grouped.set(p.challenge_id,arr)}
  return <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-6xl mx-auto px-4 md:px-6 py-8"><PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">ARENA</div><h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">Competencia en vivo</h1><p className="text-white/50 mt-2">Retos reales de CHALLENGE DYNASTY.</p></PageHero><div className="grid md:grid-cols-2 gap-4 mt-7">{(challenges??[]).map((c)=>{const ps=grouped.get(c.id)??[];const creator=relatedRow(ps.find(p=>p.role==='creator')?.profile);const rival=relatedRow(ps.find(p=>p.profile_id!==ps.find(x=>x.role==='creator')?.profile_id && p.status!=='declined')?.profile);return <Link href={`/challenge/${c.id}`} key={c.id} className="rounded-3xl border border-white/10 bg-[#161616] p-5 hover:border-gold-400/30 transition"><div className="flex justify-between text-xs"><span className="text-gold-300 font-black">{relatedRow(c.sport)?.name??'Deporte'}</span><span className="text-[#00E676]">{c.status}</span></div><div className="text-2xl font-black mt-4">{creator?.display_name??'Jugador'} <span className="text-white/20">VS</span> {rival?.display_name??'Rival'}</div><div className="text-sm text-white/45 mt-2">{c.scheduled_at?new Date(c.scheduled_at).toLocaleString('es-CO'):'Por definir'} · {c.location_name??'Ubicación por definir'}</div></Link>})}{(challenges??[]).length===0&&<div className="md:col-span-2 rounded-3xl border border-white/10 bg-[#161616] p-8 text-center text-white/45">La Arena está esperando nuevos retos.</div>}</div></div></main><BottomNav/></div>
}
