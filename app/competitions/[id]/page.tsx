export const dynamic='force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'

export default async function CompetitionDetail({params}:{params:Promise<{id:string}>}){
 const { id } = await params
 const supabase=await createClient()
 const [{data:tournament},{data:catsData},{data:fixturesData}]=await Promise.all([
  supabase.from('tournaments').select('id,title,status,starts_at,ends_at,organization_id').eq('id',id).maybeSingle(),
  supabase.from('tournament_categories').select('id,name,format,max_entries').eq('tournament_id',id).order('name'),
  supabase.from('tournament_fixtures').select('id,stage_id,round,match_number,scheduled_start,scheduled_end,status,entry_a_id,entry_b_id,winner_entry_id,score_a,score_b').eq('tournament_id',id).order('scheduled_start',{ascending:true,nullsFirst:false}).limit(200)
 ])
 const cats = catsData ?? []
 const fixtures = fixturesData ?? []
 if(!tournament) return <main className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><div className="lg:pl-64 p-10">Torneo no encontrado.</div></main>
 return <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-6xl mx-auto px-4 md:px-6 py-8"><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">TOURNAMENT OS</div><div className="flex flex-col lg:flex-row lg:items-end justify-between gap-4"><div><h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{tournament.title}</h1><p className="text-white/50 mt-2">{tournament.starts_at||'Fecha por definir'}{tournament.ends_at?` → ${tournament.ends_at}`:''}</p></div><div className="text-xs font-black uppercase tracking-widest text-[#D4AF37]">{tournament.status}</div></div><div className="grid lg:grid-cols-3 gap-4 mt-7">{cats.map((c:{id:string;name:string;format:string|null;max_entries:number|null})=><div key={c.id} className="rounded-2xl border border-white/10 bg-[#161616] p-5"><div className="text-xs text-white/40 uppercase tracking-widest">{c.format||'categoría'}</div><div className="font-black mt-2">{c.name}</div><div className="text-xs text-white/40 mt-2">Máx. {c.max_entries ?? '—'} parejas/entradas</div></div>)}</div><section className="mt-7 rounded-3xl border border-white/10 bg-[#161616] p-6"><div className="flex justify-between items-center"><h2 className="text-xl font-black">Fixtures</h2><span className="text-xs text-white/40">{fixtures.length} registrados</span></div>{fixtures.length===0?<div className="text-white/40 py-10 text-center">Todavía no hay fixtures generados.</div>:<div className="mt-4 space-y-2">{fixtures.map((f:{id:string;round:number|null;match_number:number|null;entry_a_id:string|null;entry_b_id:string|null;score_a:number|null;score_b:number|null;status:string})=><div key={f.id} className="rounded-2xl bg-white/[.03] border border-white/10 p-4 grid md:grid-cols-[90px_1fr_1fr_120px] gap-3 items-center"><div className="text-xs text-white/40">R{f.round ?? '—'} · #{f.match_number ?? '—'}</div><div className="text-sm">{f.entry_a_id||'TBD'}</div><div className="text-sm">{f.entry_b_id||'TBD'}</div><div className="text-right font-black">{f.score_a!=null&&f.score_b!=null?`${f.score_a} - ${f.score_b}`:f.status}</div></div>)}</div>}</section></div></main><BottomNav/></div>
}
