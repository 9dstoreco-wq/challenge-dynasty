'use client'
import { useState, type FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'

export default function TournamentCategoryForm({ tournamentId }: { tournamentId: string }) {
  const t = useTranslations('Competitions')
  const router = useRouter()
  const supabase = createClient()

  const [name, setName] = useState('')
  const [participantMode, setParticipantMode] = useState('pair')
  const [capacity, setCapacity] = useState('16')
  const [entryFee, setEntryFee] = useState('0')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!name.trim()) { setError(t('errCategoryNameRequired')); return }
    setBusy(true)
    const { error: insertError } = await supabase.from('tournament_categories').insert({
      tournament_id: tournamentId,
      name: name.trim(),
      participant_mode: participantMode,
      capacity: capacity ? Number(capacity) : null,
      entry_fee: Number(entryFee) || 0,
    })
    setBusy(false)
    if (insertError) { setError(toSafeMessage(insertError, 'tournament.create_category', t('categoryCreateFailed'))); return }
    setName('')
    router.refresh()
  }

  return (
    <form onSubmit={handleSubmit} className="mt-7 rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-6 space-y-4">
      <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black">{t('addCategoryTitle')}</div>
      <div className="grid md:grid-cols-4 gap-4">
        <div className="md:col-span-2">
          <label className="text-xs font-bold text-white/40">{t('categoryNameLabel')}</label>
          <input value={name} onChange={(e) => setName(e.target.value)} placeholder={t('categoryNamePlaceholder')} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white placeholder:text-white/25 outline-none focus:border-[#D4AF37]/50" />
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('participantModeLabel')}</label>
          <select value={participantMode} onChange={(e) => setParticipantMode(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50">
            <option value="individual">{t('mode.individual')}</option>
            <option value="pair">{t('mode.pair')}</option>
            <option value="team">{t('mode.team')}</option>
          </select>
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('capacityLabel')}</label>
          <input type="number" min={2} value={capacity} onChange={(e) => setCapacity(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50" />
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('entryFeeLabel')}</label>
          <input type="number" min={0} value={entryFee} onChange={(e) => setEntryFee(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50" />
        </div>
      </div>
      {error && <div className="text-sm text-red-400">{error}</div>}
      <button type="submit" disabled={busy} className="rounded-xl bg-[#D4AF37] text-black font-black py-3 px-6 disabled:opacity-50">
        {busy ? t('submitting') : t('addCategoryCta')}
      </button>
    </form>
  )
}
