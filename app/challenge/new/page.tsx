import Link from 'next/link'
export const dynamic = 'force-dynamic'
import { createClient } from '@/lib/supabase/server'
import NewChallengeForm from '@/components/NewChallengeForm'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'

export default async function NewChallengePage({ searchParams }: { searchParams?: Promise<{ player?: string; sport?: string }> }){
  const resolvedSearchParams = searchParams ? await searchParams : {}
  const supabase=await createClient()
  const t=await getTranslations('Challenge')
  const [{data:sports},{data:players}]=await Promise.all([
    supabase.from('sports').select('id,name,slug,icon').order('name'),
    supabase.from('profiles').select('id,username,display_name,city').order('display_name').limit(100),
  ])
  return <main className="min-h-screen bg-[#0A0A0C] text-white p-4 md:p-10"><div className="max-w-3xl mx-auto"><Link href="/" className="text-sm text-white/50">{t('backLink')}</Link><div className="mt-6"><PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">{t('newChallengeTag')}</div><h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{t('newChallengeTitle')}</h1><p className="text-white/50 mt-2">{t('newChallengeSubtitle')}</p></PageHero></div><NewChallengeForm sports={sports??[]} players={players??[]} initialPlayerId={resolvedSearchParams?.player} initialSportId={resolvedSearchParams?.sport}/></div></main>
}
