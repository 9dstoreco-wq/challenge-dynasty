export const dynamic = 'force-dynamic'
import Link from 'next/link'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import PageHero from '@/components/PageHero'
import PromotePurchase from '@/components/PromotePurchase'
import { createClient } from '@/lib/supabase/server'
import { getTranslations } from 'next-intl/server'

// Contacto para DYNASTY PROMOTE (campana a medida con patrocinios/espacios premium): no tiene
// precio fijo self-service a proposito, se cotiza caso por caso. No hay un numero de WhatsApp
// de negocio registrado en el codigo todavia, asi que el CTA usa el correo de la cuenta.
const CONTACT_EMAIL = 'padelitoshop@gmail.com'

export default async function Promote() {
  const t = await getTranslations('Promote')
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) {
    return (
      <div className="min-h-screen arena-bg text-white ">
        <Sidebar />
        <main className="lg:pl-64 pb-20 lg:pb-0">
          <div className="max-w-2xl mx-auto px-4 md:px-6 py-16 text-center">
            <h1 className="text-3xl font-display font-black tracking-wide">{t('authRequiredTitle')}</h1>
            <Link href="/login" className="text-[#D4AF37] mt-4 inline-block">
              {t('loginLink')}
            </Link>
          </div>
        </main>
        <BottomNav />
      </div>
    )
  }

  const { data: ownedOrg } = await supabase
    .from('organizations')
    .select('id')
    .eq('owner_id', user.id)
    .limit(1)
    .maybeSingle()

  const orFilter = ownedOrg?.id
    ? `organizer_profile_id.eq.${user.id},organization_id.eq.${ownedOrg.id}`
    : `organizer_profile_id.eq.${user.id}`

  const { data: tournamentRows } = await supabase
    .from('tournaments')
    .select('id,title,status')
    .or(orFilter)
    .order('created_at', { ascending: false })

  // Promover un torneo ya completado/cancelado no tiene sentido (nadie se va a inscribir). El
  // filtro se hace en memoria, no con .not() en la query, para no introducir una sintaxis de
  // filtro que no se usa en ningun otro lado del proyecto todavia.
  const myTournaments = (tournamentRows ?? []).filter((tr) => tr.status !== 'completed' && tr.status !== 'cancelled')
  const tournamentIds = myTournaments.map((tr) => tr.id)

  const { data: planRows } = await supabase
    .from('billing_plans')
    .select('code,name,description,charge_amount_cop')
    .eq('plan_family', 'tournament_promotion')
    .eq('is_active', true)
    .order('charge_amount_cop', { ascending: true })

  const packages = (planRows ?? []).map((p) => ({
    code: p.code,
    name: p.name,
    description: p.description ?? '',
    priceCop: Number(p.charge_amount_cop ?? 0),
  }))

  const { data: activePromoRows } = tournamentIds.length
    ? await supabase
        .from('tournament_promotions')
        .select('tournament_id,package_code,ends_at')
        .in('tournament_id', tournamentIds)
        .eq('status', 'active')
        .gt('ends_at', new Date().toISOString())
    : { data: [] }

  const activePromotions = (activePromoRows ?? []).map((p) => ({
    tournamentId: p.tournament_id as string,
    packageCode: p.package_code as string,
    endsAt: p.ends_at as string,
  }))

  return (
    <div className="min-h-screen arena-bg text-white ">
      <Sidebar />
      <main className="lg:pl-64 pb-20">
        <div className="max-w-6xl mx-auto px-4 md:px-6 py-8">
          <PageHero>
            <div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">DYNASTY PROMOTE</div>
            <h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">{t('title')}</h1>
            <p className="text-white/50 mt-3">{t('subtitle')}</p>
          </PageHero>

          <div className="mt-8 card-fut-plain border border-white/10 bg-[#141416] p-6">
            <div className="text-[#D4AF37] font-black text-xs tracking-widest">{t('packLabel')}</div>
            <PromotePurchase tournaments={myTournaments} packages={packages} activePromotions={activePromotions} />
          </div>

          <div className="mt-6 card-fut-plain border border-white/10 bg-[#141416] p-6">
            <div className="text-[#D4AF37] font-black text-xs tracking-widest">{t('packLabel')}</div>
            <h2 className="font-black text-2xl mt-2">{t('pack3Title')}</h2>
            <p className="text-white/50 text-sm mt-3">{t('pack3Body')}</p>
            <a
              href={`mailto:${CONTACT_EMAIL}?subject=${encodeURIComponent('Dynasty Promote')}`}
              className="mt-6 inline-flex rounded-xl bg-[#D4AF37] text-black px-4 py-3 font-black"
            >
              {t('dynastyPromoteCta')}
            </a>
          </div>
        </div>
      </main>
      <BottomNav />
    </div>
  )
}
