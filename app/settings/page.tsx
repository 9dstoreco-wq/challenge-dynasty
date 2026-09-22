export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'
import ProfileSettingsForm from '@/components/ProfileSettingsForm'

export default async function SettingsPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return <main className="min-h-screen bg-[#0B0F19] text-white grid place-items-center"><a href="/login" className="text-[#00F0FF] font-black">Inicia sesión para abrir configuración</a></main>
  const [{ data: profile }, { data: sports }, { data: profileSports }] = await Promise.all([
    supabase.from('profiles').select('display_name,username,city,country_code').eq('id',user.id).single(),
    supabase.from('sports').select('id,name,slug,icon').order('name'),
    supabase.from('player_sports').select('sport_id,skill_level,is_primary').eq('profile_id',user.id),
  ])
  return <div className="min-h-screen bg-[#0B0F19] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-5xl mx-auto px-4 md:px-6 py-8"><div className="text-xs tracking-[.3em] text-[#00F0FF] font-black">ACCOUNT / PASSPORT</div><h1 className="text-4xl md:text-6xl font-black mt-2">Configuración</h1><p className="text-white/45 mt-2">Tu identidad deportiva controla cómo Dynasty te encuentra, te reta y te posiciona.</p><ProfileSettingsForm profile={profile} sports={sports??[]} profileSports={profileSports??[]}/></div></main><BottomNav/></div>
}
