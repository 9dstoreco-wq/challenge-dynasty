export const dynamic = 'force-dynamic'
import Link from 'next/link'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import PageHero from '@/components/PageHero'
import ClubDashboard from '@/components/ClubDashboard'
import { createClient } from '@/lib/supabase/server'
import { getTranslations } from 'next-intl/server'

export default async function ClubManagePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const t = await getTranslations('ClubDashboard')
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data: organization } = await supabase
    .from('organizations')
    .select('id,name,description,city,country_code,owner_id')
    .eq('id', id)
    .maybeSingle()

  const isOwner = Boolean(user && organization && organization.owner_id === user.id)

  if (!organization || !isOwner) {
    return (
      <div className="min-h-screen arena-bg text-white ">
        <Sidebar />
        <main className="lg:pl-64 pb-20 lg:pb-0">
          <div className="max-w-2xl mx-auto px-4 md:px-6 py-16 text-center">
            <h1 className="text-3xl font-display font-black tracking-wide">{t('notOwnerTitle')}</h1>
            <p className="text-white/50 mt-2">{t('notOwnerBody')}</p>
            <Link href="/clubs" className="text-[#D4AF37] mt-6 inline-block">{t('backToClubs')}</Link>
          </div>
        </main>
        <BottomNav />
      </div>
    )
  }

  const { data: sports } = await supabase.from('sports').select('id,name').eq('is_active', true).order('name')

  const { data: resources } = await supabase
    .from('organization_resources')
    .select('id,name,resource_type,sport_id,capacity,status')
    .eq('organization_id', organization.id)
    .order('created_at', { ascending: false })

  const resourceIds = (resources ?? []).map((r) => r.id)
  const { data: bookables } = resourceIds.length
    ? await supabase.from('bookable_entities').select('id,organization_resource_id,price,currency_code').in('organization_resource_id', resourceIds)
    : { data: [] }
  const bookableMap = new Map((bookables ?? []).map((b) => [b.organization_resource_id, b]))

  const resourceRows = (resources ?? []).map((r) => {
    const bookable = bookableMap.get(r.id)
    return {
      id: r.id,
      name: r.name,
      resource_type: r.resource_type,
      sport_id: r.sport_id,
      capacity: r.capacity,
      status: r.status,
      bookable_id: bookable?.id ?? null,
      price: bookable?.price ?? null,
      currency_code: bookable?.currency_code ?? null,
    }
  })

  return (
    <div className="min-h-screen arena-bg text-white ">
      <Sidebar />
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="max-w-5xl mx-auto px-4 md:px-6 py-8">
          <PageHero>
            <div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">{t('tag')}</div>
            <h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{organization.name}</h1>
            <p className="text-white/50 mt-2">{organization.city ?? ''} {organization.country_code ? `· ${organization.country_code}` : ''}</p>
          </PageHero>
          <div className="mt-7">
            <ClubDashboard organizationId={organization.id} sports={sports ?? []} resources={resourceRows} />
          </div>
        </div>
      </main>
      <BottomNav />
    </div>
  )
}
