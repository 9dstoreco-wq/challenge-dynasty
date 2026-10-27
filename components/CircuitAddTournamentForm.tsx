'use client'
import { useState, type FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'

type EligibleCategory = { categoryId: string; tournamentId: string; label: string }

export default function CircuitAddTournamentForm({
  circuitId,
  eligibleCategories,
}: {
  circuitId: string
  eligibleCategories: EligibleCategory[]
}) {
  const t = useTranslations('Circuits')
  const router = useRouter()
  const supabase = createClient()

  const [selected, setSelected] = useState(eligibleCategories[0]?.categoryId ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState(false)

  if (eligibleCategories.length === 0) {
    return (
      <div className="mt-7 rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-6 text-center text-white/45">
        {t('addTournamentEmpty')}
      </div>
    )
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    setSuccess(false)
    const picked = eligibleCategories.find((c) => c.categoryId === selected)
    if (!picked) return
    setBusy(true)
    const { error: rpcError } = await supabase.rpc('add_tournament_to_circuit', {
      p_circuit_id: circuitId,
      p_tournament_id: picked.tournamentId,
      p_category_id: picked.categoryId,
    })
    setBusy(false)
    if (rpcError) { setError(toSafeMessage(rpcError, 'circuit.add_tournament', t('addTournamentFailed'))); return }
    setSuccess(true)
    router.refresh()
  }

  return (
    <form onSubmit={handleSubmit} className="mt-7 rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-6 space-y-4">
      <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black">{t('addTournamentTitle')}</div>
      <div>
        <label className="text-xs font-bold text-white/40">{t('selectCategoryLabel')}</label>
        <select value={selected} onChange={(e) => setSelected(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50">
          {eligibleCategories.map((c) => (
            <option key={c.categoryId} value={c.categoryId}>{c.label}</option>
          ))}
        </select>
      </div>
      {error && <div className="text-sm text-red-400">{error}</div>}
      {success && <div className="text-sm text-emerald-400">{t('addTournamentSuccess')}</div>}
      <button type="submit" disabled={busy} className="rounded-xl bg-[#D4AF37] text-black font-black py-3 px-6 disabled:opacity-50">
        {busy ? t('submitting') : t('addTournamentCta')}
      </button>
    </form>
  )
}
