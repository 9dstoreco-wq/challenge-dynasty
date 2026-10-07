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

  async function markPaid(entryId: string, amountDue: number) {
    setBusyId(entryId)
    setErrorId(null)
    const { error } = await supabase.rpc('confirm_tournament_registration_payment', {
      p_entry_id: entryId,
      p_amount_paid: amountDue,
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
            onClick={() => markPaid(r.entryId, r.amountDue)}
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
