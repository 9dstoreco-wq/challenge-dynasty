export const dynamic='force-dynamic'
import Sidebar from '@/components/Sidebar'
import DynastyAIContextPanel from '@/components/DynastyAIContextPanel'
import DynastyAIChat from '@/components/DynastyAIChat'
import TournamentControlCenter from '@/components/TournamentControlCenter'
import { createClient } from '@/lib/supabase/server'
export default async function Page(){const supabase=await createClient();const {data:tournaments=[]}=await supabase.from('tournaments').select('id,title,status').order('starts_at',{ascending:true}).limit(30);return <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-10 p-6 md:p-10"><div className="mx-auto max-w-6xl"><p className="text-xs font-black tracking-[0.35em] uppercase text-[#D4AF37]">DYNASTY AI CORE</p><h1 className="mt-3 text-4xl font-display font-black tracking-wide tracking-tight">DYNASTY TOURNAMENT INTELLIGENCE</h1><p className="mt-3 max-w-2xl text-lg text-white/65">Planificación avanzada con control humano, validación de conflictos, descanso obligatorio y publicación segura.</p><TournamentControlCenter tournaments={tournaments ?? []}/><DynastyAIContextPanel area="Tournament Intelligence"/><DynastyAIChat mode="tournament" placeholder="Pregúntame sobre tu torneo..."/></div></main></div>}
