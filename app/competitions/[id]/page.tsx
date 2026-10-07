export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'
import TournamentCategoryForm from '@/components/TournamentCategoryForm'
import TournamentRegisterForm from '@/components/TournamentRegisterForm'

type Fixture = { id: string; round_number: number | null; scheduled_at: string | null; status: string; side_a_entry_id: string | null; side_b_entry_id: string | null; winner_entry_id: string | null; metadata: { score_a?: number; score_b?: number } | null }
type Category = { id: string; name: string; participant_mode: string; capacity: number | null; entry_fee: number | null; status: string }

export default async function CompetitionDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const t = await getTranslations('Competitions')
  const { data: { user } } = await supabase.auth.getUser()

  const [{ data: tournament }, { data: catsData }, { data: fixturesData }] = await Promise.all([
    supabase.from('tournaments').select('id,title,status,starts_at,ends_at,organization_id,organizer_profile_id').eq('id', id).maybeSingle(),
    supabase.from('tournament_categories').select('id,name,participant_mode,capacity,entry_fee,status').eq('tournament_id', id).order('name').returns<Category[]>(),
    supabase.from('tournament_fixtures').select('id,round_number,scheduled_at,status,side_a_entry_id,side_b_entry_id,winner_entry_id,metadata').eq('tournament_id', id).order('scheduled_at', { ascending: true, nullsFirst: false }).limit(200).returns<Fixture[]>(),
  ])
  const cats = catsData ?? []
  const fixtures = fixturesData ?? []
  const isOrganizer = Boolean(user && tournament?.organizer_profile_id === user.id)

  const entryIds = Array.from(new Set(fixtures.flatMap(f => [f.side_a_entry_id, f.side_b_entry_id]).filter((v): v is string => Boolean(v))))
  const { data: entriesData } = entryIds.length
    ? await supabase.from('tournament_entries').select('id,captain_profile_id,entry_type').in('id', entryIds)
    : { data: [] as { id: string; captain_profile_id: string | null; entry_type: string }[] }
  const entries = entriesData ?? []
  const captainIds = Array.from(new Set(entries.map(e => e.captain_profile_id).filter((v): v is string => Boolean(v))))
  const { data: captainsData } = captainIds.length
    ? await supabase.from('profiles').select('id,display_name,username').in('id', captainIds)
    : { data: [] as { id: string; display_name: string | null; username: string | null }[] }
  const captainById = new Map((captainsData ?? []).map(p => [p.id, p.display_name || p.username]))
  const entryLabel = (entryId: string | null) => {
    if (!entryId) return t('tbd')
    const entry = entries.find(e => e.id === entryId)
    if (!entry) return t('tbd')
    const name = entry.captain_profile_id ? captainById.get(entry.captain_profile_id) : null
    if (!name) return t('tbd')
    return entry.entry_type === 'individual' ? name : `${name} ${t('andTeam')}`
  }

  // Jugadores "descubribles" para elegir pareja al inscribirse (misma regla que Retos).
  const { data: playersData } = user
    ? await supabase.from('profiles').select('id,username,display_name').neq('id', user.id).order('display_name').limit(200)
    : { data: [] as { id: string; username: string | null; display_name: string | null }[] }
  const players = playersData ?? []

  if (!tournament) {
    return <main className="min-h-screen arena-bg text-white "><Sidebar /><div className="lg:pl-64 p-10">{t('notFound')}</div></main>
  }

  return (
    <div className="min-h-screen arena-bg text-white ">
      <Sidebar />
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="max-w-6xl mx-auto px-4 md:px-6 py-8">
          <PageHero wide>
            <div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">{t('tag')}</div>
            <div className="flex flex-col lg:flex-row lg:items-end justify-between gap-4">
              <div>
                <h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{tournament.title}</h1>
                <p className="text-white/50 mt-2">{tournament.starts_at || t('dateTBD')}{tournament.ends_at ? ` → ${tournament.ends_at}` : ''}</p>
              </div>
              <div className="text-xs font-black uppercase tracking-widest text-[#D4AF37]">{tournament.status}</div>
            </div>
          </PageHero>

          <div className="grid lg:grid-cols-3 gap-4 mt-7">
            {cats.map((c) => (
              <div key={c.id} className="rounded-2xl border border-white/10 bg-[#161616] p-5">
                <div className="text-xs text-white/40 uppercase tracking-widest">{t(`mode.${c.participant_mode}` as 'mode.individual') }</div>
                <div className="font-black mt-2">{c.name}</div>
                <div className="text-xs text-white/40 mt-2">{t('maxEntries', { count: c.capacity ?? '—' })}</div>
                {Boolean(c.entry_fee) && <div className="text-xs text-white/40 mt-1">{t('entryFee', { amount: c.entry_fee ?? 0 })}</div>}
                {user && <TournamentRegisterForm category={c} players={players} currentUserId={user.id} />}
                {!user && <div className="mt-4 text-xs text-white/35">{t('loginToRegister')}</div>}
              </div>
            ))}
            {cats.length === 0 && (
              <div className="lg:col-span-3 rounded-2xl border border-dashed border-white/15 bg-white/[.02] p-6 text-center text-white/45">
                {t('noCategories')}
              </div>
            )}
          </div>

          {isOrganizer && <TournamentCategoryForm tournamentId={tournament.id} />}

          <section className="mt-7 card-fut-plain border border-white/10 bg-[#141416] p-6">
            <div className="flex justify-between items-center">
              <h2 className="text-xl font-black">{t('fixturesTitle')}</h2>
              <span className="text-xs text-white/40">{t('fixturesRegistered', { count: fixtures.length })}</span>
            </div>
            {fixtures.length === 0 ? (
              <div className="text-white/40 py-10 text-center">{t('noFixtures')}</div>
            ) : (
              <div className="mt-4 space-y-2">
                {fixtures.map((f) => {
                  const scoreA = f.metadata?.score_a
                  const scoreB = f.metadata?.score_b
                  const hasScore = scoreA != null && scoreB != null
                  return (
                    <div key={f.id} className="rounded-2xl bg-white/[.03] border border-white/10 p-4 grid md:grid-cols-[150px_1fr_1fr_120px] gap-3 items-center">
                      <div className="text-xs text-white/40">{t('round', { round: f.round_number ?? '—' })}<br />{f.scheduled_at ? new Date(f.scheduled_at).toLocaleString('es-CO') : t('timeTBD')}</div>
                      <div className="text-sm">{entryLabel(f.side_a_entry_id)}</div>
                      <div className="text-sm">{entryLabel(f.side_b_entry_id)}</div>
                      <div className="text-right font-black">{hasScore ? `${scoreA} - ${scoreB}` : f.status}</div>
                    </div>
                  )
                })}
              </div>
            )}
          </section>
        </div>
      </main>
      <BottomNav />
    </div>
  )
}
