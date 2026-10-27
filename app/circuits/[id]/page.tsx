export const dynamic = 'force-dynamic'

import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'
import CircuitAddTournamentForm from '@/components/CircuitAddTournamentForm'
import { notFound } from 'next/navigation'

type Circuit = {
  id: string
  name: string
  category_label: string | null
  status: string
  season_starts_at: string | null
  season_ends_at: string | null
  organizer_profile_id: string | null
  points_table: { champion?: number; finalist?: number; semifinalist?: number; quarterfinalist?: number; participant?: number }
}

type Standing = {
  profile_id: string
  display_name: string | null
  avatar_url: string | null
  points: number
  tournaments_played: number
  best_placement: number | null
  rank: number
}

type CircuitTournamentRow = {
  id: string
  applied_at: string | null
  tournaments: { title: string } | { title: string }[] | null
  tournament_categories: { name: string } | { name: string }[] | null
}

const placementKey = (p: number | null) => (p && p >= 1 && p <= 5 ? (`placement${p}` as 'placement1') : null)

export default async function CircuitDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const t = await getTranslations('Circuits')
  const { data: { user } } = await supabase.auth.getUser()

  const { data: circuit } = await supabase
    .from('tournament_circuits')
    .select('id,name,category_label,status,season_starts_at,season_ends_at,organizer_profile_id,points_table')
    .eq('id', id)
    .maybeSingle<Circuit>()

  if (!circuit) notFound()

  const [{ data: standingsData }, { data: circuitTournamentsData }] = await Promise.all([
    supabase.rpc('get_circuit_standings', { p_circuit_id: id }),
    supabase
      .from('circuit_tournaments')
      .select('id,applied_at,tournaments(title),tournament_categories(name)')
      .eq('circuit_id', id)
      .order('applied_at', { ascending: false })
      .returns<CircuitTournamentRow[]>(),
  ])
  const standings = (standingsData as Standing[] | null) ?? []
  const circuitTournaments = circuitTournamentsData ?? []
  const isOrganizer = Boolean(user && circuit.organizer_profile_id === user.id)

  let eligibleCategories: { categoryId: string; tournamentId: string; label: string }[] = []
  if (isOrganizer && user) {
    const { data: myTournaments } = await supabase
      .from('tournaments')
      .select('id,title')
      .eq('organizer_profile_id', user.id)
      .returns<{ id: string; title: string }[]>()
    const tournamentIds = (myTournaments ?? []).map((tt) => tt.id)
    if (tournamentIds.length > 0) {
      const [{ data: completedCats }, { data: alreadyInCircuits }] = await Promise.all([
        supabase
          .from('tournament_categories')
          .select('id,tournament_id,name')
          .in('tournament_id', tournamentIds)
          .eq('status', 'completed')
          .returns<{ id: string; tournament_id: string; name: string }[]>(),
        supabase.from('circuit_tournaments').select('category_id').returns<{ category_id: string }[]>(),
      ])
      const usedCategoryIds = new Set((alreadyInCircuits ?? []).map((r) => r.category_id))
      const tournamentTitleById = new Map((myTournaments ?? []).map((tt) => [tt.id, tt.title]))
      eligibleCategories = (completedCats ?? [])
        .filter((c) => !usedCategoryIds.has(c.id))
        .map((c) => ({
          categoryId: c.id,
          tournamentId: c.tournament_id,
          label: `${tournamentTitleById.get(c.tournament_id) ?? ''} — ${c.name}`,
        }))
    }
  }

  const points = circuit.points_table ?? {}

  return (
    <div className="min-h-screen arena-bg text-white ">
      <Sidebar />
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="max-w-6xl mx-auto px-4 md:px-6 py-8">
          <PageHero>
            <div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">{circuit.status}</div>
            <h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{circuit.name}</h1>
            {circuit.category_label && <p className="text-white/50 mt-2">{circuit.category_label}</p>}
            <p className="text-white/40 text-sm mt-2">
              {t('seasonLabel')}: {circuit.season_starts_at || t('noSeasonDates')}
              {circuit.season_ends_at ? ` → ${circuit.season_ends_at}` : ''}
            </p>
          </PageHero>

          <div className="mt-7 rounded-3xl border border-white/10 bg-[#141416] p-6">
            <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black mb-4">{t('standingsTitle')}</div>
            {standings.length === 0 ? (
              <div className="text-white/45 text-center py-6">{t('standingsEmpty')}</div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="text-left text-white/40 text-xs uppercase tracking-wider">
                      <th className="py-2 pr-4">#</th>
                      <th className="py-2 pr-4">{t('colPlayer')}</th>
                      <th className="py-2 pr-4">{t('colPoints')}</th>
                      <th className="py-2 pr-4">{t('colTournaments')}</th>
                      <th className="py-2 pr-4">{t('colBest')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {standings.map((s) => {
                      const key = placementKey(s.best_placement)
                      return (
                        <tr key={s.profile_id} className="border-t border-white/5">
                          <td className="py-2.5 pr-4 text-[#D4AF37] font-black">{s.rank}</td>
                          <td className="py-2.5 pr-4 font-bold">{s.display_name ?? '—'}</td>
                          <td className="py-2.5 pr-4">{s.points}</td>
                          <td className="py-2.5 pr-4 text-white/60">{s.tournaments_played}</td>
                          <td className="py-2.5 pr-4 text-white/60">{key ? t(key) : '—'}</td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          <div className="mt-7 rounded-3xl border border-white/10 bg-[#141416] p-6">
            <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black mb-4">{t('pointsTableTitle')}</div>
            <div className="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm">
              <div><div className="text-white/40">{t('placement1')}</div><div className="font-black text-lg">{points.champion ?? 0}</div></div>
              <div><div className="text-white/40">{t('placement2')}</div><div className="font-black text-lg">{points.finalist ?? 0}</div></div>
              <div><div className="text-white/40">{t('placement3')}</div><div className="font-black text-lg">{points.semifinalist ?? 0}</div></div>
              <div><div className="text-white/40">{t('placement4')}</div><div className="font-black text-lg">{points.quarterfinalist ?? 0}</div></div>
              <div><div className="text-white/40">{t('placement5')}</div><div className="font-black text-lg">{points.participant ?? 0}</div></div>
            </div>
          </div>

          <div className="mt-7 rounded-3xl border border-white/10 bg-[#141416] p-6">
            <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black mb-4">{t('tournamentsAddedTitle')}</div>
            {circuitTournaments.length === 0 ? (
              <div className="text-white/45 text-center py-6">{t('tournamentsAddedEmpty')}</div>
            ) : (
              <ul className="space-y-2">
                {circuitTournaments.map((ct) => {
                  const tournament = Array.isArray(ct.tournaments) ? ct.tournaments[0] : ct.tournaments
                  const category = Array.isArray(ct.tournament_categories) ? ct.tournament_categories[0] : ct.tournament_categories
                  return (
                    <li key={ct.id} className="text-white/70 text-sm">
                      {tournament?.title ?? '—'} — {category?.name ?? '—'}
                    </li>
                  )
                })}
              </ul>
            )}
          </div>

          {isOrganizer && (
            <CircuitAddTournamentForm circuitId={circuit.id} eligibleCategories={eligibleCategories} />
          )}
        </div>
      </main>
      <BottomNav />
    </div>
  )
}
