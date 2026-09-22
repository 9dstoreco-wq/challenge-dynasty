import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import CreateSkillChallengeForm from '@/components/CreateSkillChallengeForm'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'

export default async function NewTrickPage(){
  const supabase=await createClient()
  const {data:sports}=await supabase.from('sports').select('id,name,icon').order('name')
  return <div className="min-h-screen bg-[#0A0A0C] grid-bg text-white"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-8"><div className="max-w-4xl mx-auto px-4 md:px-8 py-8"><PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">SKILL ENGINE</div><h1 className="text-4xl md:text-5xl font-display font-black tracking-wide mt-2">Crear Skill Challenge</h1><p className="text-white/55 mt-3">Crea un reto de habilidad oficial y recibe votaciones de la comunidad.</p></PageHero><CreateSkillChallengeForm sports={(sports??[]) as {id:string;name:string;icon:string|null}[]}/></div></main><BottomNav/></div>
}
