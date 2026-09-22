export const dynamic='force-dynamic'
import DynastyAIContextPanel from '@/components/DynastyAIContextPanel'
import DynastyAIChat from '@/components/DynastyAIChat'
import TournamentControlCenter from '@/components/TournamentControlCenter'
import { createClient } from '@/lib/supabase/server'
export default async function Page(){const supabase=await createClient();const {data:tournaments=[]}=await supabase.from('tournaments').select('id,title,status').order('starts_at',{ascending:true}).limit(30);return <main className="min-h-screen bg-[#0B0F19] text-white grid-bg p-6 md:p-10"><div className="mx-auto max-w-6xl"><p className="text-xs font-black tracking-[0.35em] uppercase text-[#00F0FF]">DYNASTY AI CORE</p><h1 className="mt-3 text-4xl font-black tracking-tight">DYNASTY TOURNAMENT INTELLIGENCE</h1><p className="mt-3 max-w-2xl text-lg text-white/65">Planificación avanzada con control humano, validación de conflictos, descanso obligatorio y publicación segura.</p><TournamentControlCenter tournaments={tournaments ?? []}/><DynastyAIContextPanel area="Tournament Intelligence"/><DynastyAIChat mode="tournament" placeholder="Pregúntame sobre tu torneo..."/></div></main>}
