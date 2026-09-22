import { relatedRow } from '@/app/arena/related-row'
export const dynamic = 'force-dynamic'
import { createClient } from '@/lib/supabase/server'
import type { Metadata } from 'next'
import ChallengeActions from '@/components/ChallengeActions'
import MatchResultForm from '@/components/MatchResultForm'
import PageHero from '@/components/PageHero'

export async function generateMetadata({ params }: { params: Promise<{ id: string }>; searchParams?: Promise<Record<string, string | string[] | undefined>> }): Promise<Metadata> {
  const { id } = await params
  const supabase = await createClient()
  const { data: challenge } = await supabase
    .from('challenges')
    .select('id,creator_id,title,creator:profiles!challenges_creator_id_fkey(display_name)')
    .eq('id', id)
    .maybeSingle()

  const a = relatedRow(challenge?.creator)?.display_name ?? 'Jugador'
  return { title: `${challenge?.title ?? 'Reto'} · CHALLENGE DYNASTY`, description: `Reto deportivo de ${a} en CHALLENGE DYNASTY.` }
}

export default async function ChallengePage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams?: Promise<Record<string, string | string[] | undefined>> }) {
  const { id } = await params
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data: challenge } = await supabase
    .from('challenges')
    .select('id,title,status,challenge_type,scheduled_at,location_name,sport_id,creator_id,creator:profiles!challenges_creator_id_fkey(username,display_name)')
    .eq('id', id)
    .maybeSingle()

  if (!challenge) {
    return <main className="min-h-screen bg-[#0A0A0C] text-white grid place-items-center p-6"><div className="rounded-3xl border border-white/10 bg-[#161616] p-8 text-center"><h1 className="text-2xl font-black">Reto no encontrado</h1><p className="text-white/50 mt-2">El enlace puede haber expirado o no existe.</p></div></main>
  }

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

  const creator = relatedRow(challenge.creator)
  const rival = relatedRow(opponent?.profile)
  const currentInvitationStatus = challenge.creator_id === user?.id ? 'creator' : invitation?.status ?? opponent?.status ?? 'none'
  const resultData = (result?.result_data ?? {}) as Record<string, unknown>
  const scoreSet1 = typeof resultData.score_set1 === 'string' ? resultData.score_set1 : ''
  const scoreSet2 = typeof resultData.score_set2 === 'string' ? resultData.score_set2 : ''
  const scoreSet3 = typeof resultData.score_set3 === 'string' ? resultData.score_set3 : ''

  return <main className="min-h-screen bg-[#0A0A0C] text-white grid place-items-center p-6"><section className="w-full max-w-3xl rounded-[32px] border border-gold-400/20 bg-gradient-to-br from-[#161616] to-[#0A0A0C] p-8">
    <PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">⚔️ CHALLENGE DYNASTY</div>
    <h1 className="text-5xl font-display font-black tracking-wide mt-4 text-center">{creator?.display_name ?? 'Jugador'} <span className="text-white/20">VS</span> {rival?.display_name ?? 'Rival'}</h1></PageHero>
    <div className="text-center text-white/50 mt-3">{challenge.title} · {challenge.status}</div>

    <ChallengeActions challengeId={challenge.id} status={currentInvitationStatus} currentUserId={user?.id} challengerId={challenge.creator_id} invitationId={invitation?.id ?? undefined} />

    <div className="grid md:grid-cols-3 gap-3 mt-8">
      <div className="bg-white/5 rounded-2xl p-4"><div className="text-xs text-white/40">DEPORTE</div><div className="text-lg font-black mt-1">{challenge.sport_id}</div></div>
      <div className="bg-white/5 rounded-2xl p-4"><div className="text-xs text-white/40">FECHA</div><div className="text-lg font-bold mt-1">{challenge.scheduled_at ? new Date(challenge.scheduled_at).toLocaleString('es-CO') : 'Por definir'}</div></div>
      <div className="bg-white/5 rounded-2xl p-4"><div className="text-xs text-white/40">ESTADO</div><div className="text-lg font-black mt-1 text-[#00E676]">{result?.status === 'confirmed' ? 'COMPLETADO' : currentInvitationStatus}</div></div>
    </div>

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
      />
    )}
  </section></main>
}
