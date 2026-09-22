export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'

export default async function RankingPage(){
  const supabase = await createClient()
  const { data: rankingsData, error } = await supabase
    .from('sport_rankings')
    .select('profile_id,sport_id,rating,rank,wins,losses,matches_played,profiles(display_name,username,avatar_url)')
    .order('rank',{ascending:true,nullsFirst:false})
    .order('rating',{ascending:false})
    .limit(100)
  const rankings = rankingsData ?? []

  return <div className="min-h-screen bg-[#0B0F19] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-6xl mx-auto px-4 md:px-6 py-8">
    <div className="text-xs tracking-[.3em] text-[#00F0FF] font-black">CHALLENGE DYNASTY · RANKING</div>
    <h1 className="text-4xl md:text-6xl font-black mt-2">RANKING</h1>
    <p className="text-white/50 mt-2">Posiciones calculadas desde el ranking competitivo real de Dynasty.</p>
    {error ? <div className="mt-7 rounded-3xl border border-red-400/20 bg-red-400/5 p-8 text-center text-red-200">No se pudo cargar el ranking en este momento.</div> : rankings.length === 0 ? <div className="mt-7 rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-10 text-center text-white/45">Todavía no hay suficientes posiciones competitivas registradas.</div> : <div className="mt-7 space-y-3">{rankings.map((r, i:number)=>{
      const p = Array.isArray(r.profiles) ? r.profiles[0] : r.profiles
      return <div key={`${r.profile_id}-${r.sport_id}`} className="rounded-2xl border border-white/10 bg-[#141B2D] p-5 flex items-center gap-4">
        <div className="w-12 text-center text-2xl font-black text-[#FFD700]">{r.rank ?? i+1}</div>
        <div className="min-w-0 flex-1"><div className="font-black truncate">{p?.display_name || p?.username || 'Jugador Dynasty'}</div><div className="text-xs text-white/40 mt-1">{r.matches_played} partidos · {r.wins}V / {r.losses}D</div></div>
        <div className="text-right"><div className="text-xl font-black">{Number(r.rating).toFixed(0)}</div><div className="text-[10px] uppercase tracking-widest text-white/35">rating</div></div>
      </div>
    })}</div>}
  </div></main><BottomNav/></div>
}
