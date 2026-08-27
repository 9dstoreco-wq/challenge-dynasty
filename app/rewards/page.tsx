export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { Award } from 'lucide-react'
import { createClient } from '@/lib/supabase/server'

export default async function Rewards(){
  const supabase=createClient()
  const {data:{user}}=await supabase.auth.getUser()
  const {data:achievements}=await supabase.from('achievements').select('id,code,category,xp_reward,is_active').eq('is_active',true).order('category').order('code')
  const {data:unlocked}=user?await supabase.from('player_achievements').select('achievement_id,unlocked_at').eq('profile_id',user.id):{data:[]}
  const unlockedSet=new Set((unlocked??[]).map((x:any)=>x.achievement_id))
  return <div className="min-h-screen bg-[#0B0F19] text-white px-4 md:px-8 py-8"><div className="max-w-5xl mx-auto"><Sidebar/><div className="text-xs tracking-[.3em] text-[#FFD700] font-black">STATUS & BADGES</div><h1 className="text-4xl md:text-5xl font-black mt-2">RECOMPENSAS</h1><p className="text-white/45 mt-2">Insignias conectadas al sistema real de achievements.</p><div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-7">{(achievements??[]).map((a:any)=><div key={a.id} className="rounded-3xl border border-white/10 bg-[#141B2D] p-6"><div className="h-16 w-16 rounded-2xl flex items-center justify-center border border-[#FFD700]/20 bg-[#FFD700]/10"><Award size={29} className="text-[#FFD700]"/></div><h2 className="font-black text-lg mt-5">{a.code}</h2><p className="text-sm text-white/45 mt-2 min-h-10">{a.category||'Achievement'} · +{a.xp_reward??0} XP</p><div className="mt-5 text-xs font-black">{unlockedSet.has(a.id)?'DESBLOQUEADA':'BLOQUEADA'}</div></div>)}{(achievements??[]).length===0&&<div className="sm:col-span-2 lg:col-span-3 rounded-3xl border border-white/10 bg-[#141B2D] p-8 text-center text-white/45">Todavía no hay achievements configurados.</div>}</div></div></div>
}
