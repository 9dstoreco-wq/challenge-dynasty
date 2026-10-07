export const dynamic = 'force-dynamic'
import { createClient } from '@/lib/supabase/server'; import Sidebar from '@/components/Sidebar'; import BottomNav from '@/components/BottomNav'; import NotificationActions from '@/components/NotificationActions'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'
export default async function Notifications(){ const supabase=await createClient(); const t=await getTranslations('Notifications'); const {data:{user}}=await supabase.auth.getUser(); const {data:items}=user?await supabase.from('notifications').select('id,type,title,body,created_at,read_at,action_type,action_payload,source_type,source_id').eq('profile_id',user.id).order('created_at',{ascending:false}).limit(50):{data:[]}; const rows=(items??[]) as unknown as Array<{id:string;type:string;title:string|null;body:string|null;created_at:string;read_at:string|null;action_type:string|null;action_payload:Record<string,unknown>|null;source_type:string|null;source_id:string|null}>
 // Notificaciones que apuntan a un partido: se resuelve a que reto pertenece para poder abrirlo.
 const matchIds=rows.filter((n)=>n.action_type==='open_match').map((n)=>String((n.action_payload??{}).match_id??n.source_id??'')).filter(Boolean)
 const {data:matchRows}=matchIds.length?await supabase.from('matches').select('id,challenge_id').in('id',matchIds):{data:[]}
 const challengeByMatch=new Map((matchRows??[]).map((m)=>[m.id as string,m.challenge_id as string|null]))
 function hrefFor(n:(typeof rows)[number]):string|null{ const p=n.action_payload??{}
  if(n.action_type==='open_cards') return '/cards'
  if(n.action_type==='open_challenge'&&typeof p.challenge_id==='string') return `/challenge/${p.challenge_id}`
  if(n.action_type==='open_match'){const mid=String(p.match_id??n.source_id??''); const cid=challengeByMatch.get(mid); return cid?`/challenge/${cid}`:null}
  if(n.action_type==='open_tournament'){const tid=p.tournament_id; if(typeof tid==='string') return `/competitions/${tid}`; if(n.source_type==='tournament'&&n.source_id) return `/competitions/${n.source_id}`; return null}
  return null }
 const withHref=rows.map((n)=>({id:n.id,type:n.type,title:n.title,body:n.body,created_at:n.created_at,read_at:n.read_at,href:hrefFor(n),sourceType:n.source_type,sourceId:n.source_id}))
 return <div className="min-h-screen arena-bg text-white"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0 p-6 md:p-10"><div className="max-w-3xl"><PageHero wide badge={false} className="p-6 md:p-8 mb-5"><div className="flex items-center justify-between"><div><h1 className="text-3xl font-display font-black tracking-wide">{t('title')}</h1><p className="text-white/45 mt-2">{t('subtitle')}</p></div>{user&&withHref.some((n)=>!n.read_at)&&<NotificationActions all/>}</div></PageHero><div className="mt-6 space-y-3">{withHref.map((n)=><NotificationActions key={n.id} item={n}/>) }{!user&&<div className="rounded-2xl border border-white/10 bg-[#161616] p-6 text-white/45">{t('loginRequired')}</div>}{user&&withHref.length===0&&<div className="rounded-2xl border border-white/10 bg-[#161616] p-6 text-white/45">{t('empty')}</div>}</div></div></main><BottomNav/></div>}
