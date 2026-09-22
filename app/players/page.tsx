import Link from 'next/link'
export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'

export default async function PlayersPage(){
 const supabase=await createClient()
 const {data:padel}=await supabase.from('sports').select('id,name').eq('slug','padel').maybeSingle()
 const {data:ps}=padel?await supabase.from('player_sports').select('profile_id,skill_level').eq('sport_id',padel.id).eq('is_discoverable',true).limit(50):{data:[]}
 const ids=(ps??[]).map((x)=>x.profile_id)
 const {data:profiles}=ids.length?await supabase.from('profiles').select('id,username,display_name,city,player_status').in('id',ids).eq('is_discoverable',true):{data:[]}
 const byId=new Map((ps??[]).map((x)=>[x.profile_id,x]))
 return <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-6xl mx-auto px-4 md:px-6 py-8"><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">PLAYERS</div><h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">Tu próximo rival</h1><p className="text-white/50 mt-2">Jugadores de pádel que han elegido ser descubribles.</p><div className="grid md:grid-cols-3 gap-4 mt-7">{(profiles??[]).map((p)=>{const sport=byId.get(p.id);return <div key={p.id} className="rounded-3xl border border-white/10 bg-[#161616] p-5"><div className="text-xs text-[#D4AF37]">{sport?.skill_level??'NIVEL NO INDICADO'}</div><Link href={`/u/${p.username}`} className="block font-black text-xl mt-2 hover:text-[#D4AF37]">{p.display_name??p.username}</Link><p className="text-white/40 text-sm mt-1">{p.city??'Ubicación no indicada'} · @{p.username}</p><div className="flex gap-2 mt-4"><Link href={`/u/${p.username}`} className="flex-1 text-center rounded-xl bg-white/5 py-2 text-xs font-black">VER PERFIL</Link><Link href={`/challenge/new?player=${p.id}&sport=${padel?.id??''}`} className="rounded-xl bg-[#D4AF37] text-black px-4 py-2 text-xs font-black">RETAR</Link></div></div>})}{(profiles??[]).length===0&&<div className="md:col-span-3 rounded-3xl border border-white/10 bg-[#161616] p-8 text-center text-white/45">No hay suficientes jugadores descubribles todavía.</div>}</div></div></main><BottomNav/></div>
}
