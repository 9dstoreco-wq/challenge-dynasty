export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'

export default async function SeasonPage(){
  const supabase = createClient()
  const { data: tournaments = [] } = await supabase.from('tournaments').select('id,title,status,starts_at,ends_at').order('starts_at',{ascending:true}).limit(20)
  return <div className="min-h-screen bg-[#0B0F19] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-5xl mx-auto px-4 md:px-6 py-8"><div className="text-xs tracking-[.3em] text-[#00F0FF] font-black">CHALLENGE SEASON</div><h1 className="text-4xl md:text-6xl font-black mt-2">TEMPORADAS</h1><p className="text-white/50 mt-2">La capa de temporada empieza a consumir la actividad competitiva real del backend.</p><div className="mt-7 rounded-3xl border border-white/10 bg-[#141B2D] p-8">{tournaments.length===0?<div className="text-center text-white/45">Todavía no hay actividad competitiva suficiente para mostrar temporadas.</div>:<div className="space-y-3">{tournaments.map((t:any)=><div key={t.id} className="rounded-2xl border border-white/10 p-4 flex items-center justify-between"><div><div className="font-black">{t.title}</div><div className="text-xs text-white/40 mt-1">{t.starts_at || 'Sin fecha'}{t.ends_at?` → ${t.ends_at}`:''}</div></div><span className="text-xs font-black text-[#00F0FF]">{t.status}</span></div>)}</div>}</div></div></main><BottomNav/></div>
}
