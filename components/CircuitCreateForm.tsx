'use client'
import { useState, type FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'

export default function CircuitCreateForm() {
  const t = useTranslations('Circuits')
  const router = useRouter()
  const supabase = createClient()

  const [name, setName] = useState('')
  const [categoryLabel, setCategoryLabel] = useState('')
  const [seasonStartsAt, setSeasonStartsAt] = useState('')
  const [seasonEndsAt, setSeasonEndsAt] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!name.trim()) { setError(t('nameRequired')); return }
    setBusy(true)
    const { data, error: rpcError } = await supabase.rpc('create_tournament_circuit', {
      p_name: name.trim(),
      p_category_label: categoryLabel.trim() || null,
      p_season_starts_at: seasonStartsAt || null,
      p_season_ends_at: seasonEndsAt || null,
    })
    setBusy(false)
    if (rpcError) { setError(toSafeMessage(rpcError, 'circuit.create', t('createFailed'))); return }
    if (data) { router.push(`/circuits/${data}`); return }
    router.refresh()
  }

  return (
    <form onSubmit={handleSubmit} className="mt-7 rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-6 space-y-4">
      <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black">{t('createTitle')}</div>
      <div className="grid md:grid-cols-4 gap-4">
        <div className="md:col-span-2">
          <label className="text-xs font-bold text-white/40">{t('nameLabel')}</label>
          <input value={name} onChange={(e) => setName(e.target.value)} placeholder={t('namePlaceholder')} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white placeholder:text-white/25 outline-none focus:border-[#D4AF37]/50" />
        </div>
        <div className="md:col-span-2">
          <label className="text-xs font-bold text-white/40">{t('categoryLabelLabel')}</label>
          <input value={categoryLabel} onChange={(e) => setCategoryLabel(e.target.value)} placeholder={t('categoryLabelPlaceholder')} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white placeholder:text-white/25 outline-none focus:border-[#D4AF37]/50" />
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('seasonStartLabel')}</label>
          <input type="date" value={seasonStartsAt} onChange={(e) => setSeasonStartsAt(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50" />
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('seasonEndLabel')}</label>
          <input type="date" value={seasonEndsAt} onChange={(e) => setSeasonEndsAt(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50" />
        </div>
      </div>
      {error && <div className="text-sm text-red-400">{error}</div>}
      <button type="submit" disabled={busy} className="rounded-xl bg-[#D4AF37] text-black font-black py-3 px-6 disabled:opacity-50">
        {busy ? t('submitting') : t('createCta')}
      </button>
    </form>
  )
}
