export const dynamic = 'force-dynamic'
import Link from 'next/link'
import BusinessShell from '@/components/business/BusinessShell'
import BusinessHeader from '@/components/business/BusinessHeader'
import ClubDashboard from '@/components/ClubDashboard'
import ClubIncomePanel from '@/components/ClubIncomePanel'
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
      <BusinessShell>
        <div className="max-w-2xl mx-auto py-10 text-center">
          <h1 className="text-2xl font-semibold tracking-tight">{t('notOwnerTitle')}</h1>
          <p className="text-white/50 mt-2">{t('notOwnerBody')}</p>
          <Link href="/clubs" className="text-[#6FA3D8] mt-6 inline-block">{t('backToClubs')}</Link>
        </div>
      </BusinessShell>
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
    <BusinessShell>
      <BusinessHeader
        eyebrow={t('tag')}
        title={organization.name}
        subtitle={[organization.city, organization.country_code].filter(Boolean).join(' · ') || undefined}
      />
      <div className="space-y-7">
        <ClubIncomePanel organizationId={organization.id} />
        <ClubDashboard organizationId={organization.id} sports={sports ?? []} resources={resourceRows} />
      </div>
    </BusinessShell>
  )
}
