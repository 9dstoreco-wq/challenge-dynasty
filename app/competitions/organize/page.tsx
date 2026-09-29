export const dynamic = 'force-dynamic'
import Link from 'next/link'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import PageHero from '@/components/PageHero'
import TournamentCreateForm from '@/components/TournamentCreateForm'
import TournamentControlCenter from '@/components/TournamentControlCenter'
import { createClient } from '@/lib/supabase/server'
import { getTranslations } from 'next-intl/server'

export default async function OrganizeTournamentsPage() {
  const t = await getTranslations('TournamentsMine')
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    return (
      <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg">
        <Sidebar />
        <main className="lg:pl-64 pb-20 lg:pb-0">
          <div className="max-w-2xl mx-auto px-4 md:px-6 py-16 text-center">
            <h1 className="text-3xl font-display font-black tracking-wide">{t('authRequiredTitle')}</h1>
            <Link href="/login" className="text-[#D4AF37] mt-4 inline-block">{t('loginLink')}</Link>
          </div>
        </main>
        <BottomNav />
      </div>
    )
  }

  const { data: ownedOrg } = await supabase.from('organizations').select('id,name').eq('owner_id', user.id).order('created_at', { ascending: true }).limit(1).maybeSingle()
  const { data: sports } = await supabase.from('sports').select('id,name').eq('is_active', true).order('name')

  const orFilter = ownedOrg?.id
    ? `organizer_profile_id.eq.${user.id},organization_id.eq.${ownedOrg.id}`
    : `organizer_profile_id.eq.${user.id}`
  const { data: myTournaments } = await supabase
    .from('tournaments')
    .select('id,title,status,starts_at')
    .or(orFilter)
    .order('created_at', { ascending: false })

  return (
    <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg">
      <Sidebar />
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="max-w-5xl mx-auto px-4 md:px-6 py-8">
          <PageHero>
            <div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">{t('tag')}</div>
            <h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{t('title')}</h1>
            <p className="text-white/50 mt-3 max-w-xl">{t('subtitle')}</p>
          </PageHero>

          <div className="mt-7 space-y-6">
            <div>
              <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black mb-3">{t('listTitle')}</div>
              <div className="space-y-3">
                {(myTournaments ?? []).map((tr) => (
                  <Link key={tr.id} href={`/competitions/${tr.id}`} className="flex items-center justify-between rounded-2xl bg-white/5 p-4 hover:bg-white/10">
                    <div>
                      <div className="font-black">{tr.title}</div>
                      <div className="text-xs text-white/40 mt-0.5">{tr.starts_at ? new Date(tr.starts_at).toLocaleString('es-CO') : t('dateTBD')}</div>
                    </div>
                    <span className="text-xs font-black text-[#D4AF37] uppercase">{tr.status}</span>
                  </Link>
                ))}
                {(myTournaments ?? []).length === 0 && <div className="rounded-2xl bg-white/5 p-4 text-white/45">{t('empty')}</div>}
              </div>
            </div>

            <TournamentCreateForm sports={sports ?? []} organizationId={ownedOrg?.id ?? null} />

            {(myTournaments ?? []).length > 0 && (
              <TournamentControlCenter tournaments={(myTournaments ?? []).map((tr) => ({ id: tr.id, title: tr.title, status: tr.status }))} />
            )}
          </div>
        </div>
      </main>
      <BottomNav />
    </div>
  )
}
