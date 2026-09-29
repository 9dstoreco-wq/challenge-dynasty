import Link from 'next/link'
export const dynamic = 'force-dynamic'
import { createClient } from '@/lib/supabase/server'
import FollowButton from '@/components/FollowButton'
import PlayerCard from '@/components/PlayerCard'
import { getTranslations } from 'next-intl/server'

export default async function ProfilePage({ params }: { params: Promise<{ username: string }> }) {
  const { username } = await params
  const t = await getTranslations('Profile')
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  const { data: p } = await supabase.from('profiles').select('*').eq('username', username).maybeSingle()

  if (!p) {
    return (
      <main className="min-h-screen bg-[#0A0A0C] text-white grid place-items-center">
        <div className="text-center">
          <h1 className="text-3xl font-display font-black tracking-wide">{t('notFoundTitle')}</h1>
          <Link href="/players" className="text-[#D4AF37] mt-4 inline-block">{t('explorePlayers')}</Link>
        </div>
      </main>
    )
  }

  const isOwnProfile = user?.id === p.id

  const { data: follow } = user && !isOwnProfile
    ? await supabase.from('social_follows').select('id').eq('follower_profile_id', user.id).eq('followed_profile_id', p.id).maybeSingle()
    : { data: null }

  const { data: rankings } = await supabase
    .from('sport_rankings')
    .select('rating,wins,losses,rank,sport_id,matches_played')
    .eq('profile_id', p.id)
    .order('matches_played', { ascending: false })

  const totalWins = (rankings ?? []).reduce((s, r) => s + (r.wins ?? 0), 0)
  const totalLosses = (rankings ?? []).reduce((s, r) => s + (r.losses ?? 0), 0)
  const bestRating = (rankings ?? [])[0]?.rating ?? null
  const bestRank = (rankings ?? [])[0]?.rank ?? null
  const winrate = totalWins + totalLosses ? ((totalWins / (totalWins + totalLosses)) * 100).toFixed(1) : '0.0'

  // Owner-only reads under RLS — resolve to null for anyone viewing someone else's profile.
  const { data: progression } = await supabase.from('player_progression').select('total_xp,level').eq('profile_id', p.id).maybeSingle()
  const { data: streakRows } = await supabase.from('player_sport_streaks').select('current_win_streak').eq('profile_id', p.id).order('current_win_streak', { ascending: false }).limit(1)
  const streak = streakRows?.[0]?.current_win_streak ?? null

  const { data: rivalsOne } = user
    ? await supabase.from('player_rivalries').select('sport_id,player_one_id,player_two_id,matches_count,player_one_wins,player_two_wins,last_match_at').or(`player_one_id.eq.${p.id},player_two_id.eq.${p.id}`).order('last_match_at', { ascending: false }).limit(8)
    : { data: [] }
  const rivalIds = [...new Set((rivalsOne ?? []).map((r) => (r.player_one_id === p.id ? r.player_two_id : r.player_one_id)))]
  const { data: rivalProfiles } = rivalIds.length ? await supabase.from('profiles').select('id,username,display_name').in('id', rivalIds) : { data: [] }
  const rivalMap = new Map((rivalProfiles ?? []).map((x) => [x.id, x]))
  const rivals = (rivalsOne ?? []).map((r) => {
    const opponentId = r.player_one_id === p.id ? r.player_two_id : r.player_one_id
    const opponent = rivalMap.get(opponentId)
    return {
      opponent_id: opponentId,
      opponent_username: opponent?.username,
      opponent_name: opponent?.display_name ?? t('defaultRivalName'),
      played: r.matches_count,
      wins: r.player_one_id === p.id ? r.player_one_wins : r.player_two_wins,
      losses: r.player_one_id === p.id ? r.player_two_wins : r.player_one_wins,
      last_played: r.last_match_at,
    }
  })

  const statBlocks: [string, string | number][] = [
    [t('wins'), totalWins],
    [t('losses'), totalLosses],
    [t('winRate'), `${winrate}%`],
    [t('streak'), streak !== null ? `🔥 ${streak}` : '—'],
    [t('rating'), bestRating !== null ? Math.round(Number(bestRating)) : '—'],
    [t('rank'), bestRank !== null ? `#${bestRank}` : '—'],
  ]

  return (
    <main className="min-h-screen bg-[#0A0A0C] p-4 md:p-10 text-white">
      <div className="max-w-5xl mx-auto">
        <Link href="/" className="text-sm text-white/50">{t('backLink')}</Link>
        <section className="mt-6 rounded-[32px] border border-[#D4AF37]/20 bg-gradient-to-br from-[#1B1A12] via-[#161616] to-[#0A0A0C] p-6 md:p-8 relative overflow-hidden">
          <div className="flex flex-col md:flex-row gap-6 items-start">
            <div className="h-24 w-24 rounded-3xl bg-gradient-to-br from-gold-300 to-gold-600" />
            <div className="flex-1">
              <div className="text-xs tracking-[.25em] text-[#D4AF37] font-bold">{t('tag')}</div>
              <h1 className="text-4xl font-display font-black tracking-wide mt-2">{p.display_name}</h1>
              <div className="text-white/50 mt-1">@{p.username} · {p.city || t('locationUnknown')}</div>
              {progression?.level != null && (
                <div className="inline-flex items-center gap-2 mt-3 rounded-full bg-[#D4AF37]/15 border border-[#D4AF37]/30 px-3 py-1">
                  <span className="text-xs font-black text-[#D4AF37]">{t('level')} {progression.level}</span>
                  {progression.total_xp != null && <span className="text-xs text-white/50">· {progression.total_xp} {t('xp')}</span>}
                </div>
              )}
              <div className="flex gap-2 mt-4">
                <Link href={`/challenge/new?player=${p.id}`} className="rounded-xl bg-[#D4AF37] text-black px-4 py-2 font-black">{t('challengeBtn')}</Link>
                {user && !isOwnProfile && <FollowButton targetId={p.id} initialFollowing={Boolean(follow)} />}
              </div>
            </div>
            <div className="text-right">
              <div className="text-xs text-white/40">{t('globalRanking')}</div>
              <div className="text-sm font-black text-[#D4AF37]">{bestRank !== null ? `#${bestRank}` : t('rankingLabel')}</div>
              <div className="text-xs text-white/40">{t('rankingHint')}</div>
            </div>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-6 gap-3 mt-8">
            {statBlocks.map(([label, value]) => (
              <div key={label} className="rounded-2xl bg-white/5 p-4">
                <div className="text-xs text-white/40">{label}</div>
                <div className="text-2xl font-black mt-1">{value}</div>
              </div>
            ))}
          </div>

          <div className="mt-8">
            <div className="font-black mb-3">{isOwnProfile ? t('myCardTitle') : t('tag')}</div>
            <PlayerCard profileId={p.id} playerName={p.display_name} />
          </div>

          <div className="mt-8">
            <div className="font-black">{t('rivalriesTitle')}</div>
            <div className="mt-4 space-y-3">
              {(rivals ?? []).map((r) => (
                <Link key={r.opponent_id} href={`/u/${r.opponent_username}`} className="flex items-center gap-4 rounded-2xl bg-white/5 p-4 hover:bg-white/10">
                  <div className="h-11 w-11 rounded-2xl bg-gradient-to-br from-white/20 to-white/5" />
                  <div className="flex-1">
                    <div className="font-black">{r.opponent_name}</div>
                    <div className="text-xs text-white/40">{t('matchesPlayed', { count: r.played, wins: r.wins, losses: r.losses })}</div>
                  </div>
                  <div className="text-xs text-white/40">{new Date(r.last_played).toLocaleDateString('es-CO')}</div>
                </Link>
              ))}
              {(rivals ?? []).length === 0 && <div className="rounded-2xl bg-white/5 p-4 text-white/45">{t('emptyRivalries')}</div>}
            </div>
          </div>
        </section>
      </div>
    </main>
  )
}
