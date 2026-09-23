import Link from 'next/link'
export const dynamic = 'force-dynamic'
import { Users, Trophy, ShieldCheck } from 'lucide-react'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import PartnerInviteButton from '@/components/PartnerInviteButton'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'

export default async function Partners(){
 const supabase=await createClient()
 const t=await getTranslations('Partners')
 const {data:sport}=await supabase.from('sports').select('id,name').eq('slug','padel').maybeSingle()
 const {data:{user}}=await supabase.auth.getUser()
 const {data:mySport}=user&&sport?await supabase.from('player_sports').select('skill_level').eq('profile_id',user.id).eq('sport_id',sport.id).maybeSingle():{data:null}
 const {data:ps}=sport?await supabase.from('player_sports').select('profile_id,skill_level').eq('sport_id',sport.id).eq('is_discoverable',true).limit(30):{data:[]}
 const ids=(ps??[]).map((x)=>x.profile_id).filter((id:string)=>id!==user?.id)
 const {data:profiles}=ids.length?await supabase.from('profiles').select('id,username,display_name,city').in('id',ids).eq('is_discoverable',true):{data:[]}
 const byId=new Map((ps??[]).map((x)=>[x.profile_id,x]))
 return <div className="min-h-screen bg-[#0A0A0C] grid-bg text-white"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-8"><div className="max-w-6xl mx-auto px-4 md:px-8 py-8"><div><PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">PADEL · PARTNERS</div><h1 className="text-4xl md:text-5xl font-display font-black tracking-wide mt-2">{t('title')}</h1><p className="text-white/55 mt-3 max-w-2xl">{t('subtitle')}</p></PageHero></div><section className="mt-8"><div className="flex items-center justify-between mb-4"><h2 className="text-xl font-black">{t('compatiblePlayers')}</h2><span className="text-xs text-white/40">{t('available',{count:profiles?.length??0})}</span></div><div className="grid md:grid-cols-3 gap-5">{(profiles??[]).map((p)=>{const sp=byId.get(p.id);return <article key={p.id} className="rounded-3xl border border-white/10 bg-[#161616] p-5 hover:border-[#D4AF37]/40 transition"><div className="text-xs text-[#00E676] font-black">{sp?.skill_level??t('levelUnspecified')}</div><div className="font-black text-xl mt-2">{p.display_name??p.username}</div><div className="text-xs text-white/40 mt-1">@{p.username} · {p.city??t('noCity')}</div><div className="mt-4 flex gap-2"><PartnerInviteButton sportId={sport?.id??''} recipientId={p.id}/><Link href={`/challenge/new?player=${p.id}&sport=${sport?.id??''}`} className="rounded-xl border border-white/10 px-4 py-3 text-xs font-black">{t('challenge')}</Link><Link href={`/u/${p.username}`} className="rounded-xl border border-white/10 px-4 py-3 text-xs font-black">{t('view')}</Link></div></article>})}{(profiles??[]).length===0&&<div className="md:col-span-3 rounded-3xl border border-white/10 bg-[#161616] p-8 text-center text-white/45">{t('empty')}</div>}</div></section><section className="grid md:grid-cols-3 gap-4 mt-8"><div className="rounded-3xl border border-white/10 bg-[#161616] p-5"><Users className="text-[#D4AF37]"/><h3 className="font-black text-lg mt-3">{t('passportTitle')}</h3><p className="text-sm text-white/45 mt-1">{t('passportBody',{level:mySport?.skill_level??t('notConfigured')})}</p></div><div className="rounded-3xl border border-white/10 bg-[#161616] p-5"><Trophy className="text-[#D4AF37]"/><h3 className="font-black text-lg mt-3">{t('directChallengeTitle')}</h3><p className="text-sm text-white/45 mt-1">{t('directChallengeBody')}</p></div><div className="rounded-3xl border border-white/10 bg-[#161616] p-5"><ShieldCheck className="text-[#00E676]"/><h3 className="font-black text-lg mt-3">{t('noFakeDataTitle')}</h3><p className="text-sm text-white/45 mt-1">{t('noFakeDataBody')}</p></div></section></div></main><BottomNav/></div>
}
