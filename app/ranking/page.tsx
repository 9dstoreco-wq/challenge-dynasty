export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'

export default async function RankingPage(){
  const supabase = await createClient()
  const t = await getTranslations('Ranking')
  const { data: rankingsData, error } = await supabase
    .from('sport_rankings')
    .select('profile_id,sport_id,rating,rank,wins,losses,matches_played,profiles(display_name,username,avatar_url)')
    .order('rank',{ascending:true,nullsFirst:false})
    .order('rating',{ascending:false})
    .limit(100)
  const rankings = rankingsData ?? []
  const podium = rankings.slice(0,3)
  const rest = rankings.slice(3)

  return <div className="min-h-screen arena-bg text-white"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-6xl mx-auto px-4 md:px-6 py-8">
    <PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">CHALLENGE DYNASTY · RANKING</div>
    <h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">RANKING</h1>
    <p className="text-white/50 mt-2">{t('subtitle')}</p></PageHero>
    {error ? <div className="mt-7 rounded-3xl border border-red-400/20 bg-red-400/5 p-8 text-center text-red-200">{t('loadError')}</div> : rankings.length === 0 ? <div className="mt-7 rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-10 text-center text-white/45">{t('empty')}</div> : <>
      {podium.length>0 && <div className="mt-7 grid grid-cols-3 gap-3 md:gap-5 items-end">{[podium[1],podium[0],podium[2]].map((r,k)=>{
        if(!r) return <div key={`empty-${k}`}/>
        const pos = k===1?1:k===0?2:3
        const p = Array.isArray(r.profiles) ? r.profiles[0] : r.profiles
        const rarity = pos===1?'rarity-gold':pos===2?'rarity-silver':'rarity-bronze'
        return <div key={`${r.profile_id}-${r.sport_id}`} className={`reveal ${rarity}`} style={{['--i' as string]:pos}}><div className={`card-fut shine ${pos===1?'pt-0':''}`}><div className={`card-fut-in p-4 md:p-6 text-center ${pos===1?'md:pb-10':''}`} style={{background:`radial-gradient(circle at 50% 0%,color-mix(in srgb,var(--r) 28%,transparent),transparent 65%),#101012`}}>
          <div className="font-display text-5xl md:text-7xl leading-none" style={{color:'var(--r)'}}>{pos}</div>
          <div className="mx-auto mt-3 hex grid h-14 w-14 md:h-20 md:w-20 place-items-center font-display text-2xl md:text-4xl" style={{background:'linear-gradient(160deg,#fff8,var(--r))'}}>{(p?.display_name||p?.username||'?').trim()[0]?.toUpperCase()}</div>
          <div className="mt-3 font-black truncate text-sm md:text-lg">{p?.display_name || p?.username || t('defaultPlayer')}</div>
          <div className="font-display text-3xl md:text-5xl leading-none mt-1" style={{color:'var(--r)'}}>{Number(r.rating).toFixed(0)}</div>
          <div className="text-[10px] uppercase tracking-widest text-white/40 mt-1">rating</div>
          <div className="hidden md:block text-xs text-white/40 mt-2">{t('matchesStats',{matches:r.matches_played,wins:r.wins,losses:r.losses})}</div>
        </div></div></div>
      })}</div>}
      <div className="mt-6 space-y-2">{rest.map((r, i:number)=>{
        const p = Array.isArray(r.profiles) ? r.profiles[0] : r.profiles
        return <div key={`${r.profile_id}-${r.sport_id}`} className="reveal card-fut" style={{['--i' as string]:Math.min(i,10)}}><div className="card-fut-in px-5 py-4 flex items-center gap-4">
        <div className="w-12 text-center font-display text-3xl text-[#D4AF37]">{r.rank ?? i+4}</div>
        <div className="min-w-0 flex-1"><div className="font-black truncate">{p?.display_name || p?.username || t('defaultPlayer')}</div><div className="text-xs text-white/40 mt-1">{t('matchesStats',{matches:r.matches_played,wins:r.wins,losses:r.losses})}</div></div>
        <div className="text-right"><div className="font-display text-3xl leading-none">{Number(r.rating).toFixed(0)}</div><div className="text-[10px] uppercase tracking-widest text-white/35">rating</div></div>
      </div></div>
    })}</div></>}
  </div></main><BottomNav/></div>
}
