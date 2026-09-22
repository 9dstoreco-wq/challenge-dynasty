import { relatedRow } from '@/app/arena/related-row'
import Link from 'next/link'
export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'

export default async function HistoryPage(){
 const supabase=await createClient(); const {data:{user}}=await supabase.auth.getUser()
 if(!user) return <main className="min-h-screen bg-[#0B0F19] text-white grid place-items-center"><Link href="/login" className="text-[#00F0FF] font-black">Inicia sesión para ver tu historial</Link></main>
 const {data:participations}=await supabase.from('challenge_participants').select('challenge_id').eq('profile_id',user.id).eq('status','accepted')
 const challengeIds=[...new Set((participations??[]).map((p)=>p.challenge_id))]
 const {data:matches}=challengeIds.length?await supabase.from('matches').select('id,challenge_id,status,scheduled_at,completed_at,location_name,sport:sports(name,icon),challenge:challenges!matches_challenge_id_fkey(id,title,creator_id)').in('challenge_id',challengeIds).eq('status','completed').order('completed_at',{ascending:false}).limit(60):{data:[]}
 const matchIds=(matches??[]).map((m)=>m.id)
 const {data:results}=matchIds.length?await supabase.from('match_results').select('match_id,winner_profile_id,result_data,status').in('match_id',matchIds).eq('status','confirmed'):{data:[]}
 const resultByMatch=new Map((results??[]).map((r)=>[r.match_id,r]))
 const otherIds=[...new Set((matches??[]).map((m)=>relatedRow(m.challenge)?.creator_id).filter((id:string)=>id&&id!==user.id))]
 const {data:opponents}=otherIds.length?await supabase.from('profiles').select('id,username,display_name').in('id',otherIds):{data:[]}
 const profileById=new Map((opponents??[]).map((p)=>[p.id,p]))
 return <div className="min-h-screen bg-[#0B0F19] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-5xl mx-auto px-4 md:px-6 py-8"><div className="text-xs tracking-[.3em] text-[#00F0FF] font-black">DYNASTY HISTORY</div><h1 className="text-4xl md:text-6xl font-black mt-2">Historial competitivo</h1><p className="text-white/45 mt-2">Cada partido confirmado deja rastro en tu historial.</p><div className="space-y-3 mt-7">{(matches??[]).map((m)=>{const r=resultByMatch.get(m.id);const won=r?.winner_profile_id===user.id;const creator=profileById.get(relatedRow(m.challenge)?.creator_id);const resultData=r?.result_data??{};return <Link key={m.id} href={`/challenge/${relatedRow(m.challenge)?.id}`} className="block rounded-3xl border border-white/10 bg-[#141B2D] p-5 hover:border-cyan-300/20"><div className="flex items-center gap-4"><div className={`h-14 w-14 rounded-2xl flex items-center justify-center font-black ${won?'bg-[#00E676]/10 text-[#00E676]':'bg-red-500/10 text-red-300'}`}>{won?'W':'L'}</div><div className="flex-1"><div className="text-xs text-white/35">{relatedRow(m.sport)?.icon} {relatedRow(m.sport)?.name} · {m.completed_at?new Date(m.completed_at).toLocaleDateString('es-CO'):'—'}</div><div className="font-black text-lg mt-1">{relatedRow(m.challenge)?.title??'Partido'}{creator&&creator.id!==user.id?<span className="text-white/45 font-medium"> · vs {creator.display_name}</span>:''}</div><div className="text-sm text-white/45 mt-1">{m.location_name??'Ubicación no indicada'}</div></div><div className="text-right"><div className="font-black text-xl">{resultData.score_set1||'—'} {resultData.score_set2?` · ${resultData.score_set2}`:''} {resultData.score_set3?` · ${resultData.score_set3}`:''}</div><div className={`text-xs font-black mt-1 ${won?'text-[#00E676]':'text-red-300'}`}>{won?'VICTORIA':'DERROTA'}</div></div></div></Link>})}{(matches??[]).length===0&&<div className="rounded-3xl border border-white/10 bg-[#141B2D] p-8 text-center text-white/45">Todavía no tienes partidos confirmados.</div>}</div></div></main><BottomNav/></div>
}
