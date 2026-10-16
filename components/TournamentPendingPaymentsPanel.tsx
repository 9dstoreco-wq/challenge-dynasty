'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'

type Row = { entryId: string; categoryName: string; playerLabel: string; amountDue: number; amountPaid: number }

export default function TournamentPendingPaymentsPanel({ rows }: { rows: Row[] }) {
  const t = useTranslations('Competitions')
  const router = useRouter()
  const supabase = createClient()
  const [busyId, setBusyId] = useState<string | null>(null)
  const [errorId, setErrorId] = useState<string | null>(null)

  const pending = rows.filter((r) => r.amountPaid < r.amountDue)
  if (pending.length === 0) return null

  async function markPaid(entryId: string, amountDue: number, amountPaid: number) {
    setBusyId(entryId)
    setErrorId(null)
    // F12: confirm_tournament_registration_payment now takes full payment identity
    // (provider/provider_payment_id/provider_event_id) and SUMS events instead of
    // replacing amount_paid -- see Challenge_Dynasty_SQL_F04_F12_para_pegar.sql.
    // This manual "mark as paid" action has no real provider transaction, so it uses
    // provider: 'manual' with a fresh, unique id per click (the UI already disables
    // the button while busy, so no duplicate-click risk). Pass only the REMAINING
    // balance as the amount for this event, not the full amountDue -- the RPC adds it
    // to whatever was already paid, it no longer overwrites.
    const remaining = amountDue - amountPaid
    const eventId = crypto.randomUUID()
    const { error } = await supabase.rpc('confirm_tournament_registration_payment', {
      p_entry_id: entryId,
      p_provider: 'manual',
      p_provider_payment_id: eventId,
      p_provider_event_id: eventId,
      p_amount: remaining,
    })
    setBusyId(null)
    if (error) { setErrorId(entryId); return }
    router.refresh()
  }

  return (
    <section className="mt-7 rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-6 space-y-3">
      <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black">{t('pendingPaymentsTitle')}</div>
      {pending.map((r) => (
        <div key={r.entryId} className="flex items-center justify-between gap-3 rounded-xl bg-white/[.03] border border-white/10 px-4 py-3">
          <div>
            <div className="font-bold text-sm">{r.playerLabel}</div>
            <div className="text-xs text-white/40">{r.categoryName} · {t('amountDue', { amount: r.amountDue })}</div>
            {errorId === r.entryId && <div className="text-xs text-red-400 mt-1">{t('markPaidFailed')}</div>}
          </div>
          <button
            onClick={() => markPaid(r.entryId, r.amountDue, r.amountPaid)}
            disabled={busyId === r.entryId}
            className="rounded-xl bg-[#D4AF37] text-black font-black py-2 px-4 text-xs disabled:opacity-40 whitespace-nowrap"
          >
            {busyId === r.entryId ? t('generating') : t('markPaidCash')}
          </button>
        </div>
      ))}
    </section>
  )
}
