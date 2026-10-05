import { relatedRow } from '@/app/arena/related-row'
export const dynamic = 'force-dynamic'
import { createClient } from '@/lib/supabase/server'
import type { Metadata } from 'next'
import ChallengeActions from '@/components/ChallengeActions'
import MatchResultForm from '@/components/MatchResultForm'
import PlayerCard from '@/components/PlayerCard'
import PageHero from '@/components/PageHero'
import CardStakePanel from '@/components/CardStakePanel'
import { getCardsWonInChallenge, getChallengeStakes, getPlayerCards } from '@/lib/dynasty/cards'
import DynastyCard from '@/components/DynastyCard'
import Link from 'next/link'
import { getTranslations } from 'next-intl/server'

export async function generateMetadata({ params }: { params: Promise<{ id: string }>; searchParams?: Promise<Record<string, string | string[] | undefined>> }): Promise<Metadata> {
  const { id } = await params
  const supabase = await createClient()
  const t = await getTranslations('Challenge')
  const { data: challenge } = await supabase
    .from('challenges')
    .select('id,creator_id,title,creator:profiles!challenges_creator_id_fkey(display_name)')
    .eq('id', id)
    .maybeSingle()

  const a = relatedRow(challenge?.creator)?.display_name ?? t('defaultPlayer')
  return { title: `${challenge?.title ?? t('notFoundTitle')} · CHALLENGE DYNASTY`, description: t('metaDescription', { name: a }) }
}

export default async function ChallengePage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams?: Promise<Record<string, string | string[] | undefined>> }) {
  const { id } = await params
  const supabase = await createClient()
  const t = await getTranslations('Challenge')
  const { data: { user } } = await supabase.auth.getUser()

  const { data: challenge } = await supabase
    .from('challenges')
    .select('id,title,status,challenge_type,scheduled_at,location_name,sport_id,creator_id,creator:profiles!challenges_creator_id_fkey(username,display_name)')
    .eq('id', id)
    .maybeSingle()

  if (!challenge) {
    return <main className="min-h-screen arena-bg text-white grid place-items-center p-6"><div className="card-fut-plain border border-white/10 bg-[#141416] p-8 text-center"><h1 className="text-2xl font-black">{t('notFoundTitle')}</h1><p className="text-white/50 mt-2">{t('notFoundBody')}</p></div></main>
  }

  const { data: sportRow } = await supabase.from('sports').select('name,icon,slug').eq('id', challenge.sport_id).maybeSingle()

  const { data: participants } = await supabase
    .from('challenge_participants')
    .select('profile_id,role,status,profile:profiles!challenge_participants_profile_id_fkey(username,display_name)')
    .eq('challenge_id', challenge.id)

  const opponents = (participants ?? []).filter((p) => p.profile_id !== challenge.creator_id && p.status !== 'declined' && p.status !== 'withdrawn')
  const opponent = opponents[0]

  const { data: invitation } = user
    ? await supabase
        .from('challenge_invitations')
        .select('id,status,invitee_id,inviter_id,expires_at')
        .eq('challenge_id', challenge.id)
        .eq('invitee_id', user.id)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()
    : { data: null }

  const { data: match } = await supabase
    .from('matches')
    .select('id,status,scheduled_at,completed_at,location_name')
    .eq('challenge_id', challenge.id)
    .maybeSingle()

  const { data: result } = match
    ? await supabase
        .from('match_results')
        .select('id,winner_profile_id,result_data,submitted_by,status,created_at,updated_at')
        .eq('match_id', match.id)
        .maybeSingle()
    : { data: null }

  const myParticipant = user ? (participants ?? []).find((p) => p.profile_id === user.id && p.status === 'accepted') : null
  const stakes = await getChallengeStakes(supabase, challenge.id, t('defaultPlayer'))
  const myStake = stakes?.find((s) => s.profileId === user?.id)?.card ?? null
  const theirStake = stakes?.find((s) => s.profileId !== user?.id)?.card ?? null
  const stakesSettled = Boolean(stakes?.length) && stakes!.every((s) => s.status === 'settled')
  const canStake = Boolean(myParticipant) && !result && ['open', 'accepted', 'active'].includes(challenge.status)
  const eligibleCards = canStake && user
    ? (await getPlayerCards(supabase, user.id, t('defaultPlayer'))).filter((c) => !c.isProtected && c.sportId === challenge.sport_id && c.id !== myStake?.id)
    : []
  const creator = relatedRow(challenge.creator)
  const rival = relatedRow(opponent?.profile)
  const baseStatus = challenge.creator_id === user?.id ? 'creator' : invitation?.status ?? opponent?.status ?? 'none'
  // Un reto cancelado, terminado o con resultado ya no se puede cancelar ni responder.
  const currentInvitationStatus = challenge.status === 'cancelled' ? 'cancelled' : challenge.status === 'completed' || result ? 'locked' : baseStatus
  const wonCards = result?.status === 'confirmed' && user && match && myParticipant
    ? await getCardsWonInChallenge(supabase, challenge.id, match.id, user.id, t('defaultPlayer'))
    : []
  const resultData = (result?.result_data ?? {}) as Record<string, unknown>
  const scoreSet1 = typeof resultData.score_set1 === 'string' ? resultData.score_set1 : ''
  const scoreSet2 = typeof resultData.score_set2 === 'string' ? resultData.score_set2 : ''
  const scoreSet3 = typeof resultData.score_set3 === 'string' ? resultData.score_set3 : ''

  return <main className="min-h-screen arena-bg text-white grid place-items-center p-6"><section className="w-full max-w-3xl card-fut-plain border border-gold-400/25 bg-gradient-to-br from-[#161616] to-[#0A0A0C] p-8">
    <PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">⚔️ CHALLENGE DYNASTY</div>
    <h1 className="text-5xl font-display font-black tracking-wide mt-4 text-center">{creator?.display_name ?? t('defaultPlayer')} <span className="text-white/20">VS</span> {rival?.display_name ?? t('defaultRival')}</h1></PageHero>
    <div className="text-center text-white/50 mt-3">{challenge.title} · {challenge.status === 'cancelled' ? t('cancelled') : challenge.status}</div>

    <ChallengeActions challengeId={challenge.id} status={currentInvitationStatus} currentUserId={user?.id} challengerId={challenge.creator_id} invitationId={invitation?.id ?? undefined} />

    <div className="grid md:grid-cols-3 gap-3 mt-8">
      <div className="bg-white/5 rounded-2xl p-4"><div className="text-xs text-white/40">{t('sportLabel')}</div><div className="text-lg font-black mt-1">{sportRow ? `${sportRow.icon ?? ''} ${sportRow.name}`.trim() : challenge.sport_id}</div></div>
      <div className="bg-white/5 rounded-2xl p-4"><div className="text-xs text-white/40">{t('dateLabel')}</div><div className="text-lg font-bold mt-1">{challenge.scheduled_at ? new Date(challenge.scheduled_at).toLocaleString('es-CO') : t('dateTBD')}</div></div>
      <div className="bg-white/5 rounded-2xl p-4"><div className="text-xs text-white/40">{t('statusLabel')}</div><div className="text-lg font-black mt-1 text-[#00E676]">{result?.status === 'confirmed' ? t('completed') : challenge.status === 'cancelled' ? t('cancelled') : currentInvitationStatus === 'locked' ? challenge.status : currentInvitationStatus}</div></div>
    </div>

    {stakes !== null && user && (myParticipant || stakes.length > 0) && (
      <CardStakePanel challengeId={challenge.id} mine={myStake} theirs={theirStake} eligible={eligibleCards} canEdit={canStake} settled={stakesSettled} />
    )}

    {match && user && result?.status !== 'confirmed' && (
      <MatchResultForm
        challengeId={challenge.id}
        matchId={match.id}
        resultId={result?.id}
        creatorId={challenge.creator_id}
        opponentId={opponent?.profile_id}
        creatorName={creator?.display_name}
        opponentName={rival?.display_name}
        currentUserId={user.id}
        winnerId={result?.winner_profile_id}
        submittedBy={result?.submitted_by}
        resultStatus={result?.status}
        scoreSet1={scoreSet1}
        scoreSet2={scoreSet2}
        scoreSet3={scoreSet3}
        sportSlug={sportRow?.slug}
      />
    )}

    {result?.status === 'confirmed' && user && myParticipant && (
      <div className="mt-8">
        <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black mb-3">{t('cardSectionTitle')}</div>
        <PlayerCard
          profileId={user.id}
          playerName={user.id === challenge.creator_id ? creator?.display_name : rival?.display_name}
          username={user.id === challenge.creator_id ? creator?.username : rival?.username}
          result={result.winner_profile_id === user.id ? 'win' : 'loss'}
          opponent={user.id === challenge.creator_id ? rival?.display_name : creator?.display_name}
        />
        {wonCards.length > 0 && (
          <div className="mt-8 text-center">
            <div className="text-xs tracking-[.2em] text-[#00E676] font-black mb-3">{t('newCardTitle')}</div>
            <div className="flex flex-wrap justify-center gap-4">{wonCards.map((c) => <DynastyCard key={c.id} card={c} />)}</div>
            <Link href="/cards" className="inline-block mt-4 rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-xs font-black">{t('viewCards')}</Link>
          </div>
        )}
      </div>
    )}
  </section></main>
}
