export const dynamic = 'force-dynamic'
import Link from 'next/link'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import SocialPostCard from '@/components/SocialPostCard'
import { createClient } from '@/lib/supabase/server'

type FeedRow = { id: string; author_profile_id: string; post_type: string; body: string; created_at: string; profiles: { username: string | null; display_name: string | null } | null }

export default async function SocialPage(){
  const supabase=await createClient()
  const {data:{user}}=await supabase.auth.getUser()
  const {data:posts}=await supabase.from('social_posts').select('id,author_profile_id,post_type,body,created_at,profiles!social_posts_author_profile_id_fkey(username,display_name)').order('created_at',{ascending:false}).limit(40).returns<FeedRow[]>()
  const ids=(posts??[]).map((p)=>p.id)
  const {data:likes}=user&&ids.length?await supabase.from('social_reactions').select('post_id').eq('profile_id',user.id).eq('reaction_type','like').in('post_id',ids):{data:[]}
  const liked=new Set((likes??[]).map((x)=>x.post_id))
  const normalized=(posts??[]).map((p)=>({
    ...p,user_id:p.author_profile_id,type:p.post_type,content:p.body,
    username:p.profiles?.username||'jugador',full_name:p.profiles?.display_name||'Jugador',liked_by_me:liked.has(p.id)
  }))
  return <div className="min-h-screen bg-[#0B0F19] text-white"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-4xl mx-auto px-4 md:px-6 py-8"><div className="flex flex-wrap items-end justify-between gap-4"><div><div className="text-xs tracking-[.3em] text-[#00F0FF] font-black">DYNASTY SOCIAL</div><h1 className="text-4xl md:text-5xl font-black mt-2">Feed competitivo</h1><p className="text-white/50 mt-2">Resultados, publicaciones y actividad de la comunidad.</p></div><div className="flex gap-2"><Link href="/challenge/new" className="rounded-xl bg-[#00F0FF] text-black px-4 py-3 text-sm font-black">CREAR RETO</Link><Link href="/notifications/preferences" className="rounded-xl border border-white/10 px-4 py-3 text-sm font-black">PREFERENCIAS</Link></div></div><section className="mt-7 space-y-4">{normalized.map((p)=><SocialPostCard key={p.id} post={p} currentUserId={user?.id}/>) }{normalized.length===0&&<div className="rounded-3xl border border-white/10 bg-[#141B2D] p-10 text-center text-white/45">Todavía no hay publicaciones. Los resultados oficiales y tus posts aparecerán aquí.</div>}</section></div></main><BottomNav/></div>
}
