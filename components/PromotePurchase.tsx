'use client'

import { useState } from 'react'
import { useTranslations } from 'next-intl'
import { Loader2 } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { WompiCheckoutButton } from '@/components/WompiCheckoutButton'

export type PromoTournamentOption = { id: string; title: string }
export type PromoPackageOption = { code: string; name: string; description: string; priceCop: number }
export type ActivePromotion = { tournamentId: string; packageCode: string; endsAt: string }

/**
 * Flujo real de compra de "Boost"/"Destacado" para UN torneo del organizador. Mismo patron que
 * MembershipPaywall (components/MembershipPaywall.tsx): llama a una RPC que abre una factura en
 * COP (create_tournament_promotion_invoice, ver supabase/migrations/20261028190000_*.sql) y
 * muestra <WompiCheckoutButton domain="billing" rowId={invoiceId} />. Los precios y la
 * descripcion de cada paquete vienen de billing_plans (plan_family='tournament_promotion'), no
 * estan escritos aqui, para que cambiarlos no necesite tocar codigo.
 */
export default function PromotePurchase({
  tournaments,
  packages,
  activePromotions,
}: {
  tournaments: PromoTournamentOption[]
  packages: PromoPackageOption[]
  activePromotions: ActivePromotion[]
}) {
  const t = useTranslations('Promote')
  const supabase = createClient()
  const [tournamentId, setTournamentId] = useState(tournaments[0]?.id ?? '')
  const [packageCode, setPackageCode] = useState<string>(packages[0]?.code ?? '')
  const [invoiceId, setInvoiceId] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  if (tournaments.length === 0) {
    return <div className="rounded-2xl bg-white/5 p-4 text-white/45 text-sm">{t('noTournaments')}</div>
  }

  const activeForSelected = activePromotions.find((p) => p.tournamentId === tournamentId)

  async function handleBuy() {
    if (!tournamentId || !packageCode) return
    setBusy(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('create_tournament_promotion_invoice', {
      p_tournament_id: tournamentId,
      p_package_code: packageCode,
    })
    setBusy(false)
    if (rpcError || !data) {
      setError(t('errorGeneric'))
      return
    }
    setInvoiceId(data as unknown as string)
  }

  return (
    <div className="space-y-5">
      <div>
        <label className="text-xs text-white/40 font-bold uppercase tracking-widest">{t('pickTournament')}</label>
        <select
          value={tournamentId}
          onChange={(e) => {
            setTournamentId(e.target.value)
            setInvoiceId(null)
            setError(null)
          }}
          className="mt-2 w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3 text-sm text-white"
        >
          {tournaments.map((tr) => (
            <option key={tr.id} value={tr.id} className="bg-[#161616]">
              {tr.title}
            </option>
          ))}
        </select>
      </div>

      {activeForSelected && (
        <div className="rounded-xl border border-[#D4AF37]/30 bg-[#D4AF37]/10 px-4 py-3 text-xs text-[#D4AF37] font-bold">
          {t('alreadyActive', {
            pkg: activeForSelected.packageCode === 'tournament_promo_destacado' ? t('pack1Title') : t('pack2Title'),
            date: new Date(activeForSelected.endsAt).toLocaleDateString('es-CO'),
          })}
        </div>
      )}

      <div className="grid sm:grid-cols-2 gap-3">
        {packages.map((p) => (
          <button
            key={p.code}
            type="button"
            onClick={() => {
              setPackageCode(p.code)
              setInvoiceId(null)
              setError(null)
            }}
            className={`text-left rounded-2xl border p-4 transition ${
              packageCode === p.code ? 'border-[#D4AF37] bg-[#D4AF37]/10' : 'border-white/10 bg-white/5'
            }`}
          >
            <div className="font-black">{p.name}</div>
            <div className="text-2xl font-black mt-2">${p.priceCop.toLocaleString('es-CO')} COP</div>
            <div className="text-white/45 text-xs mt-2">{p.description}</div>
          </button>
        ))}
      </div>

      {error && <div className="text-sm text-red-400">{error}</div>}

      {invoiceId ? (
        <div className="flex justify-center">
          <WompiCheckoutButton domain="billing" rowId={invoiceId} />
        </div>
      ) : (
        <button
          type="button"
          onClick={handleBuy}
          disabled={busy}
          className="w-full rounded-xl bg-[#D4AF37] text-black font-black py-3 disabled:opacity-50 inline-flex items-center justify-center gap-2"
        >
          {busy ? <Loader2 size={16} className="animate-spin" /> : null}
          {busy ? t('preparing') : t('promoteBtn')}
        </button>
      )}
    </div>
  )
}
