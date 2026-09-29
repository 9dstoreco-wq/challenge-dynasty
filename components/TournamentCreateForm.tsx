'use client'
import { useState, type FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'

type Sport = { id: string; name: string }

export default function TournamentCreateForm({ sports, organizationId }: { sports: Sport[]; organizationId: string | null }) {
  const t = useTranslations('TournamentCreate')
  const router = useRouter()
  const supabase = createClient()

  const [title, setTitle] = useState('')
  const [sportId, setSportId] = useState(sports[0]?.id ?? '')
  const [formatType, setFormatType] = useState('single_elimination')
  const [participantMode, setParticipantMode] = useState('pair')
  const [visibility, setVisibility] = useState('public')
  const [startsAt, setStartsAt] = useState('')
  const [capacity, setCapacity] = useState('16')
  const [entryFee, setEntryFee] = useState('0')
  const [currency, setCurrency] = useState('COP')
  const [locationName, setLocationName] = useState('')
  const [attachToClub, setAttachToClub] = useState(Boolean(organizationId))
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!title.trim()) { setError(t('errTitleRequired')); return }

    setBusy(true)
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { setBusy(false); setError(t('errAuthRequired')); return }

    const { error: insertError } = await supabase.from('tournaments').insert({
      organizer_profile_id: user.id,
      organization_id: attachToClub ? organizationId : null,
      sport_id: sportId || null,
      title: title.trim(),
      format_type: formatType,
      participant_mode: participantMode,
      visibility,
      status: 'draft',
      starts_at: startsAt ? new Date(startsAt).toISOString() : null,
      capacity: Number(capacity) || null,
      entry_fee: Number(entryFee) || 0,
      currency_code: currency,
      location_name: locationName.trim() || null,
    })

    setBusy(false)
    if (insertError) { setError(insertError.message || t('errCreateFailed')); return }
    setTitle(''); setLocationName('')
    router.refresh()
  }

  return (
    <form onSubmit={handleSubmit} className="rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-6 space-y-4">
      <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black">{t('title')}</div>
      <div className="grid md:grid-cols-2 gap-4">
        <div className="md:col-span-2">
          <label className="text-xs font-bold text-white/40">{t('nameLabel')}</label>
          <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder={t('namePlaceholder')} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white placeholder:text-white/25 outline-none focus:border-[#D4AF37]/50" />
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('sportLabel')}</label>
          <select value={sportId} onChange={(e) => setSportId(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50">
            <option value="">{t('selectSport')}</option>
            {sports.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('formatLabel')}</label>
          <select value={formatType} onChange={(e) => setFormatType(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50">
            <option value="single_elimination">{t('formatSingleElim')}</option>
            <option value="double_elimination">{t('formatDoubleElim')}</option>
            <option value="round_robin">{t('formatRoundRobin')}</option>
            <option value="groups_then_knockout">{t('formatGroups')}</option>
            <option value="ladder">{t('formatLadder')}</option>
          </select>
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('participantModeLabel')}</label>
          <select value={participantMode} onChange={(e) => setParticipantMode(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50">
            <option value="individual">{t('modeIndividual')}</option>
            <option value="pair">{t('modePair')}</option>
            <option value="team">{t('modeTeam')}</option>
          </select>
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('visibilityLabel')}</label>
          <select value={visibility} onChange={(e) => setVisibility(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50">
            <option value="public">{t('visibilityPublic')}</option>
            <option value="unlisted">{t('visibilityUnlisted')}</option>
            <option value="private">{t('visibilityPrivate')}</option>
          </select>
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('startsLabel')}</label>
          <input type="datetime-local" value={startsAt} onChange={(e) => setStartsAt(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50" />
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('locationLabel')}</label>
          <input value={locationName} onChange={(e) => setLocationName(e.target.value)} placeholder={t('locationPlaceholder')} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white placeholder:text-white/25 outline-none focus:border-[#D4AF37]/50" />
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('capacityLabel')}</label>
          <input type="number" min={2} value={capacity} onChange={(e) => setCapacity(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50" />
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('entryFeeLabel')}</label>
          <input type="number" min={0} value={entryFee} onChange={(e) => setEntryFee(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50" />
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('currencyLabel')}</label>
          <input value={currency} onChange={(e) => setCurrency(e.target.value.toUpperCase())} maxLength={3} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50 uppercase" />
        </div>
      </div>
      {organizationId && (
        <label className="flex items-center gap-2 text-sm text-white/60">
          <input type="checkbox" checked={attachToClub} onChange={(e) => setAttachToClub(e.target.checked)} />
          {t('attachToClub')}
        </label>
      )}
      {error && <div className="text-sm text-red-400">{error}</div>}
      <button type="submit" disabled={busy} className="w-full rounded-xl bg-[#D4AF37] text-black font-black py-3 disabled:opacity-50">
        {busy ? t('submitting') : t('submitBtn')}
      </button>
    </form>
  )
}
