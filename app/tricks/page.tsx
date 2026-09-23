import Link from 'next/link'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import SkillChallengeCard from '@/components/SkillChallengeCard'
import { createClient } from '@/lib/supabase/server'
import { Sparkles } from 'lucide-react'
import { getTranslations } from 'next-intl/server'

export const dynamic = 'force-dynamic'

export default async function TricksPage(){
  const supabase=await createClient()
  const t=await getTranslations('Tricks')
  const {data:challenges}=await supabase.from('skill_challenges').select('id,title,description,category,difficulty,points,target_votes,status,expires_at,created_at,creator_id,sport_id').order('created_at',{ascending:false}).limit(30)
  const creatorIds=[...new Set((challenges??[]).map((x)=>x.creator_id).filter(Boolean))]
  const {data:creators}=creatorIds.length?await supabase.from('profiles').select('id,display_name,username').in('id',creatorIds):{data:[]}
  const byCreator=new Map((creators??[]).map((x)=>[x.id,x]))
  const submissionCounts=new Map<string,number>()
  const ids=(challenges??[]).map((x)=>x.id)
  if(ids.length){
    const {data:subs}=await supabase.from('skill_submissions').select('challenge_id').in('challenge_id',ids)
    for(const s of subs??[]) submissionCounts.set(s.challenge_id,(submissionCounts.get(s.challenge_id)??0)+1)
  }
  return <div className="min-h-screen bg-[#0A0A0C] grid-bg text-white"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-[1500px] mx-auto px-4 md:px-6 py-7 space-y-7"><section className="rounded-3xl border border-[#D4AF37]/20 bg-gradient-to-br from-[#1B1A12] via-[#161616] to-[#0A0A0C] p-6 md:p-10"><div className="flex items-center gap-2 text-xs font-black tracking-[.25em] text-[#D4AF37]"><Sparkles size={15}/> {t('tag')}</div><div className="flex flex-col lg:flex-row lg:items-end lg:justify-between gap-5"><div><h1 className="text-4xl md:text-6xl font-display font-black tracking-wide tracking-tight mt-3">{t('title')}</h1><p className="text-white/60 mt-4 text-lg max-w-2xl">{t('subtitle')}</p></div><Link href="/tricks/new" className="rounded-xl bg-[#D4AF37] text-black px-5 py-3 font-black text-sm text-center">{t('createBtn')}</Link></div></section><section><div className="grid md:grid-cols-2 xl:grid-cols-3 gap-5">{(challenges??[]).map((c)=>{const creator=byCreator.get(c.creator_id);const votesCount=submissionCounts.get(c.id)??0;const accents=['from-gold-500/30 via-gold-500/10 to-transparent','from-fuchsia-500/25 via-purple-500/10 to-transparent','from-emerald-500/25 via-lime-500/10 to-transparent'];return <Link key={c.id} href={`/tricks/${c.id}`}><SkillChallengeCard title={c.title} user={creator?.display_name??creator?.username??t('defaultCreator')} rank={c.difficulty} votes={votesCount} difficulty={c.difficulty} points={c.points} category={c.category} accent={accents[votesCount%accents.length]}/></Link>})}{(challenges??[]).length===0&&<div className="md:col-span-2 xl:col-span-3 rounded-3xl border border-white/10 bg-[#161616] p-10 text-center text-white/45">{t('empty')}</div>}</div></section></div></main><BottomNav/></div>
}
