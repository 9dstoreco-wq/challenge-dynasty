import { relatedRow } from '@/app/arena/related-row'
import Link from 'next/link'
export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'
import MarqueeTicker from '@/components/MarqueeTicker'
import { getTranslations, getLocale } from 'next-intl/server'

const CHALLENGE_STATUSES = ['open', 'scheduled', 'active', 'completed', 'cancelled', 'creator', 'pending', 'accepted', 'declined', 'withdrawn', 'invited', 'none', 'expired']

export default async function ArenaIndex(){
  const supabase=await createClient()
  const t=await getTranslations('Arena'); const tChallenge=await getTranslations('Challenge'); const locale=await getLocale(); const dateLocale=locale==='en'?'en-US':'es-CO'
  const statusLabel=(s:string)=>(CHALLENGE_STATUSES.includes(s)?tChallenge(`status.${s}`):s)
  const {data: challenges}=await supabase.from('challenges').select('id,title,status,scheduled_at,location_name,sport:sports(name)').eq('status','open').order('scheduled_at',{ascending:true}).limit(24)
  const ids=(challenges??[]).map((c)=>c.id)
  const {data: participants}=ids.length?await supabase.from('challenge_participants').select('challenge_id,profile_id,role,status,profile:profiles!challenge_participants_profile_id_fkey(username,display_name)').in('challenge_id',ids).in('status',['accepted','invited']):{data:[]}
  const grouped=new Map<string, Array<NonNullable<typeof participants>[number]>>()
  for(const p of participants??[]){const arr=grouped.get(p.challenge_id)??[];arr.push(p);grouped.set(p.challenge_id,arr)}
  const list=challenges??[]
  return (
    <div className="min-h-screen arena-bg overflow-x-clip text-white">
      <Sidebar/>
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="mx-auto max-w-6xl px-4 py-8 md:px-6">
          <section className="relative isolate mb-6">
            <div className="reveal text-xs font-black tracking-[.3em] text-[#D4AF37]">{t('kicker')}</div>
            <h1 className="mt-3 font-display font-normal leading-[.84] tracking-tight text-[clamp(88px,15vw,210px)]">
              <span className="reveal block" style={{['--i' as string]:1}}>{t('heroLine1')}</span>
              <span className="reveal lando-outline block pl-[10%]" style={{['--i' as string]:2}}>{t('heroLine2')}</span>
            </h1>
            <div className="reveal mt-5 flex flex-wrap items-center justify-between gap-5" style={{['--i' as string]:3}}>
              <p className="max-w-md text-base leading-relaxed text-white/70">{t('subtitle')}</p>
              <div className="flex flex-wrap gap-3">
                <Link href="/challenge/new" className="btn-gold shine">{t('ctaNew')}</Link>
                <Link href="/challenges" className="btn-ghost">{t('ctaMine')}</Link>
              </div>
            </div>
            <div className="reveal mt-6 inline-flex items-center gap-3 rounded-full border border-white/15 px-4 py-2 text-sm" style={{['--i' as string]:4}}>
              <span className={list.length?"live-dot":"h-2 w-2 rounded-full bg-white/30"} aria-hidden="true"/>
              <span className="font-bold tabular-nums">{t('openCount',{count:list.length})}</span>
            </div>
          </section>

          <MarqueeTicker items={[t('ticker1'),t('ticker2'),t('ticker3'),t('ticker4')]}/>

          {list.length===0 ? (
            <div className="mt-10 grid items-center gap-6 rounded-[28px] border border-dashed border-white/15 bg-white/[.02] p-8 text-center md:p-14">
              <div className="font-display text-5xl leading-none md:text-7xl">{t('emptyTitle')}</div>
              <p className="mx-auto max-w-md text-white/60">{t('empty')}</p>
              <div><Link href="/challenge/new" className="btn-gold shine">{t('ctaNew')}</Link></div>
            </div>
          ) : (
            <div className="mt-10 grid gap-5 md:grid-cols-2">
              {list.map((c,i)=>{
                const ps=grouped.get(c.id)??[]
                const creatorRow=ps.find(p=>p.role==='creator')
                const creator=relatedRow(creatorRow?.profile)
                const rival=relatedRow(ps.find(p=>p.profile_id!==creatorRow?.profile_id && p.status!=='declined')?.profile)
                return (
                  <Link href={`/challenge/${c.id}`} key={c.id} className="vs-card reveal group relative overflow-hidden rounded-[24px] border border-white/10 bg-[#121214] p-6 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#D4AF37]" style={{['--i' as string]:Math.min(i,10)}}>
                    <span aria-hidden="true" className="vs-glow"/>
                    <div className="relative flex items-center justify-between gap-3 text-xs">
                      <span className="inline-flex items-center gap-2 font-black uppercase tracking-[.18em] text-[#D4AF37]"><span className="live-dot" aria-hidden="true"/>{statusLabel(c.status)}</span>
                      <span className="font-bold uppercase tracking-widest text-white/60">{relatedRow(c.sport)?.name??t('defaultSport')}</span>
                    </div>
                    <div className="relative mt-6 grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center gap-3">
                      <div className="min-w-0">
                        <div className="truncate font-display text-2xl leading-none tracking-wide sm:text-3xl md:text-4xl">{creator?.display_name??t('defaultPlayer')}</div>
                        <div className="mt-1 text-[11px] font-bold uppercase tracking-widest text-white/50">{t('challenger')}</div>
                      </div>
                      <div className="vs-bolt font-display text-3xl sm:text-4xl md:text-5xl">VS</div>
                      <div className="min-w-0 text-right">
                        <div className={`truncate font-display text-2xl leading-none tracking-wide sm:text-3xl md:text-4xl ${rival?'':'text-white/40'}`}>{rival?.display_name??t('defaultRival')}</div>
                        <div className="mt-1 text-[11px] font-bold uppercase tracking-widest text-white/50">{t('challenged')}</div>
                      </div>
                    </div>
                    <div className="relative mt-6 flex items-center justify-between gap-3 border-t border-white/10 pt-4 text-sm">
                      <span className="truncate text-white/65">{c.scheduled_at?new Date(c.scheduled_at).toLocaleString(dateLocale,{dateStyle:'medium',timeStyle:'short'}):t('tbd')} · {c.location_name??t('locationTbd')}</span>
                      <span className="vs-arrow shrink-0 font-black uppercase tracking-widest text-[#D4AF37]">{t('seeChallenge')}</span>
                    </div>
                  </Link>
                )
              })}
            </div>
          )}
        </div>
      </main>
      <BottomNav/>
    </div>
  )
}
