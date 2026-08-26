import { createClient } from '@/lib/supabase/server'
import NewChallengeForm from '@/components/NewChallengeForm'

export default async function NewChallengePage({ searchParams }: { searchParams?: { player?: string; sport?: string } }){
  const supabase=createClient()
  const [{data:sports},{data:players}]=await Promise.all([
    supabase.from('sports').select('id,name,slug,icon').order('name'),
    supabase.from('profiles').select('id,username,display_name,city').order('display_name').limit(100),
  ])
  return <main className="min-h-screen bg-[#0B0F19] text-white p-4 md:p-10"><div className="max-w-3xl mx-auto"><a href="/" className="text-sm text-white/50">← Volver</a><div className="mt-6"><div className="text-xs tracking-[.3em] text-[#00F0FF] font-black">⚡ CREAR RETO</div><h1 className="text-4xl md:text-6xl font-black mt-2">Elige rival. Elige deporte.</h1><p className="text-white/50 mt-2">El reto se convierte automáticamente en una Arena compartible.</p></div><NewChallengeForm sports={sports??[]} players={players??[]} initialPlayerId={searchParams?.player} initialSportId={searchParams?.sport}/></div></main>
}
