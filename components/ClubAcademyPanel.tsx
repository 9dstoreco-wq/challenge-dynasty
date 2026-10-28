'use client'
import { useState, type FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'

export type CoachRow = {
  relationshipId: string
  providerId: string
  profileId: string
  displayName: string | null
  username: string | null
  headline: string | null
  relationshipType: string
}

export type ClassRow = {
  id: string
  providerId: string
  coachDisplayName: string | null
  title: string
  description: string | null
  serviceMode: string
  durationMinutes: number | null
  capacity: number
  price: number
  currencyCode: string
  status: string
}

type SearchResult = {
  provider_id: string
  profile_id: string
  display_name: string | null
  username: string | null
  headline: string | null
}

export default function ClubAcademyPanel({
  organizationId,
  coaches,
  classes,
}: {
  organizationId: string
  coaches: CoachRow[]
  classes: ClassRow[]
}) {
  const t = useTranslations('ClubAcademy')
  const router = useRouter()
  const supabase = createClient()

  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [query, setQuery] = useState('')
  const [results, setResults] = useState<SearchResult[]>([])
  const [searching, setSearching] = useState(false)
  const [relationshipType, setRelationshipType] = useState('employee')

  const [coachForClass, setCoachForClass] = useState(coaches[0]?.providerId ?? '')
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [serviceMode, setServiceMode] = useState('in_person')
  const [duration, setDuration] = useState('60')
  const [capacity, setCapacity] = useState('4')
  const [price, setPrice] = useState('')
  const [currency, setCurrency] = useState('COP')

  const MODE_LABELS: Record<string, string> = { in_person: t('modeInPerson'), online: t('modeOnline'), hybrid: t('modeHybrid') }
  const RELATIONSHIP_LABELS: Record<string, string> = { employee: t('relEmployee'), contractor: t('relContractor'), partner: t('relPartner'), guest: t('relGuest') }

  async function handleSearch(e: FormEvent) {
    e.preventDefault()
    setSearching(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('search_academy_coaches', { p_query: query.trim() || null })
    setSearching(false)
    if (rpcError) { setError(toSafeMessage(rpcError, 'academy.searchCoaches', t('errSearchFailed'))); return }
    setResults((data as SearchResult[] | null) ?? [])
  }

  async function handleAddCoach(providerId: string) {
    setBusy(true); setError(null)
    const { error: rpcError } = await supabase.rpc('add_coach_to_academy', {
      p_organization_id: organizationId,
      p_provider_id: providerId,
      p_relationship_type: relationshipType,
    })
    setBusy(false)
    if (rpcError) { setError(toSafeMessage(rpcError, 'academy.addCoach', t('errAddCoachFailed'))); return }
    setResults([])
    setQuery('')
    router.refresh()
  }

  async function handleAddClass(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!coachForClass) { setError(t('errNoCoaches')); return }
    if (!title.trim() || !price.trim()) return
    setBusy(true)
    const { error: rpcError } = await supabase.rpc('create_academy_class', {
      p_organization_id: organizationId,
      p_provider_id: coachForClass,
      p_title: title.trim(),
      p_description: description.trim() || null,
      p_service_mode: serviceMode,
      p_duration_minutes: duration.trim() ? Number(duration) : null,
      p_capacity: Number(capacity) || 1,
      p_price: Number(price),
      p_currency_code: currency,
    })
    setBusy(false)
    if (rpcError) { setError(toSafeMessage(rpcError, 'academy.createClass', t('errCreateClassFailed'))); return }
    setTitle(''); setDescription(''); setPrice(''); setDuration('60'); setCapacity('4')
    router.refresh()
  }

  async function toggleClass(c: ClassRow) {
    setBusy(true); setError(null)
    const nextStatus = c.status === 'active' ? 'paused' : 'active'
    const { error: rpcError } = await supabase.rpc('set_academy_class_status', { p_service_id: c.id, p_status: nextStatus })
    setBusy(false)
    if (rpcError) { setError(toSafeMessage(rpcError, 'academy.toggleClass', t('errToggleFailed'))); return }
    router.refresh()
  }

  return (
    <div className="space-y-6">
      <div className="text-xs tracking-[.2em] text-[#3B6EA5] font-black">{t('tag')}</div>
      {error && <div className="text-sm text-red-400">{error}</div>}

      <div>
        <div className="text-xs tracking-[.2em] text-[#3B6EA5] font-black mb-3">{t('coachesTitle')}</div>
        <div className="space-y-3">
          {coaches.map((c) => (
            <div key={c.relationshipId} className="rounded-2xl bg-white/5 p-4 flex items-center justify-between gap-3">
              <div>
                <div className="font-black">{c.displayName ?? c.headline ?? t('unnamedCoach')}</div>
                <div className="text-xs text-white/40 mt-0.5">
                  {c.username ? `@${c.username} · ` : ''}{RELATIONSHIP_LABELS[c.relationshipType] || c.relationshipType}
                </div>
              </div>
            </div>
          ))}
          {coaches.length === 0 && <div className="rounded-2xl bg-white/5 p-4 text-white/45">{t('emptyCoaches')}</div>}
        </div>
      </div>

      <form onSubmit={handleSearch} className="rounded-3xl border border-[#3B6EA5]/20 bg-[#161616] p-6 space-y-4">
        <div className="text-xs tracking-[.2em] text-[#3B6EA5] font-black">{t('addCoachTitle')}</div>
        <p className="text-white/45 text-sm">{t('addCoachSubtitle')}</p>
        <div className="flex gap-2">
          <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder={t('searchPlaceholder')} className="flex-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white placeholder:text-white/25 outline-none focus:border-[#3B6EA5]/50" />
          <select value={relationshipType} onChange={(e) => setRelationshipType(e.target.value)} className="rounded-xl bg-white/5 border border-white/10 px-3 py-2.5 text-white text-sm outline-none focus:border-[#3B6EA5]/50">
            <option value="employee">{t('relEmployee')}</option>
            <option value="contractor">{t('relContractor')}</option>
            <option value="partner">{t('relPartner')}</option>
            <option value="guest">{t('relGuest')}</option>
          </select>
          <button type="submit" disabled={searching} className="rounded-xl bg-[#3B6EA5] text-black font-black px-5 disabled:opacity-50">
            {searching ? t('searching') : t('searchBtn')}
          </button>
        </div>
        {results.length > 0 && (
          <div className="space-y-2">
            {results.map((r) => (
              <div key={r.provider_id} className="flex items-center justify-between rounded-xl bg-white/[.03] p-3 text-sm gap-2">
                <div className="truncate">
                  <div className="font-bold truncate">{r.display_name ?? r.headline ?? t('unnamedCoach')}</div>
                  <div className="text-white/40 text-xs">{r.username ? `@${r.username}` : ''}</div>
                </div>
                <button type="button" onClick={() => handleAddCoach(r.provider_id)} disabled={busy} className="text-xs text-[#3B6EA5] hover:text-white shrink-0 font-bold">{t('addBtn')}</button>
              </div>
            ))}
          </div>
        )}
        {query && results.length === 0 && !searching && <div className="text-white/40 text-sm">{t('noSearchResults')}</div>}
      </form>

      <div>
        <div className="text-xs tracking-[.2em] text-[#3B6EA5] font-black mb-3">{t('classesTitle')}</div>
        <div className="space-y-3">
          {classes.map((c) => (
            <div key={c.id} className="rounded-2xl bg-white/5 p-4 flex items-center justify-between gap-3">
              <div className="truncate">
                <div className="font-black truncate">{c.title}</div>
                <div className="text-xs text-white/40 mt-0.5">
                  {c.coachDisplayName ?? t('unnamedCoach')} · {MODE_LABELS[c.serviceMode] || c.serviceMode} · {Number(c.price).toLocaleString('es-CO')} {c.currencyCode}
                </div>
              </div>
              <div className="flex items-center gap-3 shrink-0">
                <span className={`text-xs font-black px-3 py-1 rounded-full ${c.status === 'active' ? 'bg-[#00E676]/15 text-[#00E676]' : 'bg-white/10 text-white/50'}`}>
                  {c.status === 'active' ? t('statusActive') : t('statusPaused')}
                </span>
                <button onClick={() => toggleClass(c)} disabled={busy} className="rounded-xl border border-white/10 px-3 py-1.5 text-xs font-bold hover:bg-white/5 disabled:opacity-50">
                  {c.status === 'active' ? t('pauseBtn') : t('activateBtn')}
                </button>
              </div>
            </div>
          ))}
          {classes.length === 0 && <div className="rounded-2xl bg-white/5 p-4 text-white/45">{t('emptyClasses')}</div>}
        </div>
      </div>

      <form onSubmit={handleAddClass} className="rounded-3xl border border-[#3B6EA5]/20 bg-[#161616] p-6 space-y-4">
        <div className="text-xs tracking-[.2em] text-[#3B6EA5] font-black">{t('addClassTitle')}</div>
        {coaches.length === 0 ? (
          <p className="text-white/45 text-sm">{t('errNoCoaches')}</p>
        ) : (
          <div className="grid md:grid-cols-2 gap-4">
            <div className="md:col-span-2">
              <label className="text-xs font-bold text-white/40">{t('coachLabel')}</label>
              <select value={coachForClass} onChange={(e) => setCoachForClass(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#3B6EA5]/50">
                {coaches.map((c) => <option key={c.providerId} value={c.providerId}>{c.displayName ?? c.headline ?? t('unnamedCoach')}</option>)}
              </select>
            </div>
            <div className="md:col-span-2">
              <label className="text-xs font-bold text-white/40">{t('classTitleLabel')}</label>
              <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder={t('classTitlePlaceholder')} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white placeholder:text-white/25 outline-none focus:border-[#3B6EA5]/50" />
            </div>
            <div>
              <label className="text-xs font-bold text-white/40">{t('modeLabel')}</label>
              <select value={serviceMode} onChange={(e) => setServiceMode(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#3B6EA5]/50">
                <option value="in_person">{t('modeInPerson')}</option>
                <option value="online">{t('modeOnline')}</option>
                <option value="hybrid">{t('modeHybrid')}</option>
              </select>
            </div>
            <div>
              <label className="text-xs font-bold text-white/40">{t('durationLabel')}</label>
              <input type="number" min={1} value={duration} onChange={(e) => setDuration(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#3B6EA5]/50" />
            </div>
            <div>
              <label className="text-xs font-bold text-white/40">{t('capacityLabel')}</label>
              <input type="number" min={1} value={capacity} onChange={(e) => setCapacity(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#3B6EA5]/50" />
            </div>
            <div>
              <label className="text-xs font-bold text-white/40">{t('priceLabel')}</label>
              <input type="number" min={0} value={price} onChange={(e) => setPrice(e.target.value)} placeholder={t('pricePlaceholder', { currency })} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white placeholder:text-white/25 outline-none focus:border-[#3B6EA5]/50" />
            </div>
            <div>
              <label className="text-xs font-bold text-white/40">{t('currencyLabel')}</label>
              <input value={currency} onChange={(e) => setCurrency(e.target.value.toUpperCase())} maxLength={3} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#3B6EA5]/50 uppercase" />
            </div>
            <div className="md:col-span-2">
              <label className="text-xs font-bold text-white/40">{t('descriptionLabel')}</label>
              <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={2} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#3B6EA5]/50" />
            </div>
          </div>
        )}
        <button type="submit" disabled={busy || coaches.length === 0} className="w-full rounded-xl bg-[#3B6EA5] text-black font-black py-3 disabled:opacity-50">
          {busy ? t('submitting') : t('addClassBtn')}
        </button>
      </form>
    </div>
  )
}
