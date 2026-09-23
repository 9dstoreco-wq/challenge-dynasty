export const dynamic = 'force-dynamic'
import { redirect } from 'next/navigation'
import Sidebar from '@/components/Sidebar'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import CoachDashboard from '@/components/CoachDashboard'
import { getTranslations } from 'next-intl/server'

export default async function CoachDashboardPage(){
  const supabase = await createClient()
  const t = await getTranslations('CoachDashboard')
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login?next=/coaches/dashboard')

  const { data: profile } = await supabase
    .from('provider_profiles')
    .select('id, headline, bio, is_independent, accepts_online, accepts_in_person, default_currency, status')
    .eq('profile_id', user.id)
    .eq('provider_type', 'coach')
    .maybeSingle()

  let services: { id: string; title: string; description: string | null; service_mode: string; price: number; currency_code: string; duration_minutes: number | null; status: string; bookable_id: string | null }[] = []
  let bookings: { id: string; starts_at: string; ends_at: string; status: string; payment_status: string; amount: number; currency_code: string; bookable_title: string | null }[] = []

  if (profile) {
    const { data: rawServices } = await supabase
      .from('provider_services')
      .select('id, title, description, service_mode, price, currency_code, duration_minutes, status')
      .eq('provider_id', profile.id)
      .order('created_at', { ascending: false })

    const { data: myEntities } = await supabase
      .from('bookable_entities')
      .select('id, entity_id')
      .eq('owner_id', user.id)
      .eq('entity_type', 'service')

    const entityByService = new Map((myEntities ?? []).map((e) => [e.entity_id as string, e.id as string]))
    services = (rawServices ?? []).map((s) => ({ ...s, bookable_id: entityByService.get(s.id) ?? null }))

    const entityIds = (myEntities ?? []).map((e) => e.id as string)
    if (entityIds.length > 0) {
      const { data: rawBookings } = await supabase
        .from('bookings')
        .select('id, starts_at, ends_at, status, payment_status, amount, currency_code, bookable_entities(title)')
        .in('bookable_id', entityIds)
        .order('starts_at', { ascending: false })
        .limit(100)
      bookings = (rawBookings ?? []).map((b) => {
        const rel = (b as unknown as { bookable_entities: { title: string | null } | { title: string | null }[] | null }).bookable_entities
        const title = Array.isArray(rel) ? rel[0]?.title ?? null : rel?.title ?? null
        return { id: b.id, starts_at: b.starts_at, ends_at: b.ends_at, status: b.status, payment_status: b.payment_status, amount: b.amount, currency_code: b.currency_code, bookable_title: title }
      })
    }
  }

  return <main className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><section className="lg:pl-64 p-6 lg:p-12 max-w-[1400px] mx-auto">
    <PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">{t('tag')}</div><h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{t('title')}</h1></PageHero>
    <div className="mt-8"><CoachDashboard profile={profile ?? null} services={services} bookings={bookings} myProfileId={user.id} /></div>
  </section></main>
}
