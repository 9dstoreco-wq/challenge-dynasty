'use client'

import { useState } from 'react'
import { useTranslations } from 'next-intl'
import { Check, Loader2 } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { WompiCheckoutButton } from '@/components/WompiCheckoutButton'

export type PaywallPlanOption = {
  code: string
  billingInterval: 'monthly' | 'yearly'
  price: number
  currencyCode: string
}

/**
 * Pantalla de "necesitas suscribirte", usada en el lugar de las herramientas de club
 * (app/clubs/manage/[id]/page.tsx) y de creación de torneos (app/competitions/organize/page.tsx)
 * cuando organization_has_active_club_membership / profile_or_org_has_active_organizer_plan
 * devuelve false. Llama a create_subscription_invoice (ver
 * supabase/migrations/20261028160000_*.sql) para abrir una factura en COP y luego muestra
 * <WompiCheckoutButton domain="billing" rowId={invoiceId} /> -- el mismo botón reutilizado de
 * reservas/torneos/marketplace, que ya sabe abrir el widget de Wompi y redirigir al terminar.
 *
 * organizationId: null para suscribirse a título personal (plan de organizador de torneos sin
 * club), o el id del club propio cuando el plan es de membresía de club (audience_type
 * 'organization' exige organización).
 */
export default function MembershipPaywall({
  title,
  description,
  features,
  organizationId,
  plans,
}: {
  title: string
  description: string
  features: string[]
  organizationId: string | null
  plans: PaywallPlanOption[]
}) {
  const t = useTranslations('MembershipPaywall')
  const supabase = createClient()

  const monthly = plans.find((p) => p.billingInterval === 'monthly')
  const yearly = plans.find((p) => p.billingInterval === 'yearly')

  const [interval, setInterval] = useState<'monthly' | 'yearly'>('monthly')
  const [invoiceId, setInvoiceId] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const selected = interval === 'yearly' ? yearly : monthly
  const savingsPct =
    monthly && yearly && monthly.price > 0 ? Math.round((1 - yearly.price / (monthly.price * 12)) * 100) : null

  async function handleSubscribe() {
    if (!selected) return
    setBusy(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('create_subscription_invoice', {
      p_plan_code: selected.code,
      p_organization_id: organizationId,
    })
    setBusy(false)
    if (rpcError || !data) {
      setError(t('errorGeneric'))
      return
    }
    setInvoiceId(data as unknown as string)
  }

  if (invoiceId) {
    return (
      <section className="rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-6 text-center space-y-4">
        <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black">{t('tag')}</div>
        <h2 className="text-xl font-black">{t('readyTitle')}</h2>
        <p className="text-white/50 text-sm">{t('readyBody')}</p>
        <div className="flex justify-center">
          <WompiCheckoutButton domain="billing" rowId={invoiceId} />
        </div>
      </section>
    )
  }

  return (
    <section className="rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-6 space-y-5">
      <div>
        <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black">{t('tag')}</div>
        <h2 className="text-2xl font-black mt-1">{title}</h2>
        <p className="text-white/50 text-sm mt-1">{description}</p>
      </div>

      {features.length > 0 && (
        <ul className="space-y-2">
          {features.map((f) => (
            <li key={f} className="flex items-start gap-2 text-sm text-white/70">
              <Check size={16} className="text-[#D4AF37] mt-0.5 shrink-0" />
              {f}
            </li>
          ))}
        </ul>
      )}

      {monthly && yearly && (
        <div className="flex rounded-xl bg-white/5 p-1 gap-1 text-sm font-bold">
          <button
            type="button"
            onClick={() => setInterval('monthly')}
            className={`flex-1 rounded-lg py-2 transition ${interval === 'monthly' ? 'bg-[#D4AF37] text-black' : 'text-white/60'}`}
          >
            {t('monthly')}
          </button>
          <button
            type="button"
            onClick={() => setInterval('yearly')}
            className={`flex-1 rounded-lg py-2 transition ${interval === 'yearly' ? 'bg-[#D4AF37] text-black' : 'text-white/60'}`}
          >
            {t('yearly')}
            {savingsPct ? <span className="ml-1 text-[10px] opacity-80">-{savingsPct}%</span> : null}
          </button>
        </div>
      )}

      {selected && (
        <div className="text-center">
          <div className="text-3xl font-black">
            ${selected.price.toLocaleString('en-US')} {selected.currencyCode}
          </div>
          <div className="text-white/40 text-xs mt-1">{interval === 'yearly' ? t('perYear') : t('perMonth')}</div>
        </div>
      )}

      {error && <div className="text-sm text-red-400 text-center">{error}</div>}

      <button
        type="button"
        onClick={handleSubscribe}
        disabled={busy || !selected}
        className="w-full rounded-xl bg-[#D4AF37] text-black font-black py-3 disabled:opacity-50 inline-flex items-center justify-center gap-2"
      >
        {busy ? <Loader2 size={16} className="animate-spin" /> : null}
        {busy ? t('preparing') : t('subscribeBtn')}
      </button>

      <p className="text-white/30 text-[11px] text-center">{t('chargeNote')}</p>
    </section>
  )
}
