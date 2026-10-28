export const dynamic = 'force-dynamic'
import Link from 'next/link'
import BusinessShell from '@/components/business/BusinessShell'
import BusinessHeader from '@/components/business/BusinessHeader'
import ClubDashboard from '@/components/ClubDashboard'
import ClubIncomePanel from '@/components/ClubIncomePanel'
import ClubAcademyPanel, { type CoachRow, type ClassRow } from '@/components/ClubAcademyPanel'
import MembershipPaywall, { type PaywallPlanOption } from '@/components/MembershipPaywall'
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
          <Link href="/clubs" className="text-[#D4AF37] mt-6 inline-block">{t('backToClubs')}</Link>
        </div>
      </BusinessShell>
    )
  }

  // Membresía de Club (reservas + academia + finanzas): sin plan activo no se muestran las
  // herramientas del club, solo la pantalla para suscribirse. Ver supabase/migrations/
  // 20261028160000_add_subscription_billing_enforcement.sql.
  const { data: hasMembership } = await supabase.rpc('organization_has_active_club_membership', {
    p_organization_id: organization.id,
  })

  if (!hasMembership) {
    const tGate = await getTranslations('ClubMembershipGate')
    const { data: planRows } = await supabase
      .from('billing_plans')
      .select('code,billing_interval,price,currency_code')
      .eq('plan_family', 'club_membership')
      .eq('is_active', true)
    const plans: PaywallPlanOption[] = (planRows ?? []).map((p) => ({
      code: p.code,
      billingInterval: p.billing_interval as 'monthly' | 'yearly',
      price: Number(p.price),
      currencyCode: p.currency_code,
    }))

    return (
      <BusinessShell>
        <BusinessHeader
          eyebrow={t('tag')}
          title={organization.name}
          subtitle={[organization.city, organization.country_code].filter(Boolean).join(' · ') || undefined}
        />
        <MembershipPaywall
          title={tGate('title')}
          description={tGate('description')}
          features={[tGate('feature1'), tGate('feature2'), tGate('feature3')]}
          organizationId={organization.id}
          plans={plans}
        />
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

  const { data: relationshipRows } = await supabase
    .from('provider_organization_relationships')
    .select('id,provider_id,relationship_type')
    .eq('organization_id', organization.id)
    .eq('status', 'active')
    .order('created_at', { ascending: false })

  const coachProviderIds = (relationshipRows ?? []).map((r) => r.provider_id)
  const { data: coachProviderRows } = coachProviderIds.length
    ? await supabase.from('provider_profiles').select('id,profile_id,headline').in('id', coachProviderIds)
    : { data: [] }
  const coachProfileIds = (coachProviderRows ?? []).map((p) => p.profile_id)
  const { data: coachProfileRows } = coachProfileIds.length
    ? await supabase.from('profiles').select('id,display_name,username').in('id', coachProfileIds)
    : { data: [] }
  const coachProviderById = new Map((coachProviderRows ?? []).map((p) => [p.id, p]))
  const coachProfileById = new Map((coachProfileRows ?? []).map((p) => [p.id, p]))

  const coaches: CoachRow[] = (relationshipRows ?? []).map((r) => {
    const provider = coachProviderById.get(r.provider_id)
    const profile = provider ? coachProfileById.get(provider.profile_id) : undefined
    return {
      relationshipId: r.id,
      providerId: r.provider_id,
      profileId: provider?.profile_id ?? '',
      displayName: profile?.display_name ?? null,
      username: profile?.username ?? null,
      headline: provider?.headline ?? null,
      relationshipType: r.relationship_type,
    }
  })

  const { data: serviceRows } = await supabase
    .from('provider_services')
    .select('id,provider_id,title,description,service_mode,duration_minutes,capacity,price,currency_code,status')
    .eq('organization_id', organization.id)
    .order('created_at', { ascending: false })

  const classes: ClassRow[] = (serviceRows ?? []).map((s) => {
    const provider = coachProviderById.get(s.provider_id)
    const profile = provider ? coachProfileById.get(provider.profile_id) : undefined
    return {
      id: s.id,
      providerId: s.provider_id,
      coachDisplayName: profile?.display_name ?? provider?.headline ?? null,
      title: s.title,
      description: s.description,
      serviceMode: s.service_mode,
      durationMinutes: s.duration_minutes,
      capacity: s.capacity,
      price: s.price,
      currencyCode: s.currency_code,
      status: s.status,
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
        <ClubAcademyPanel organizationId={organization.id} coaches={coaches} classes={classes} />
      </div>
    </BusinessShell>
  )
}
