'use client'
import { useState, type FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'

type Sport = { id: string; name: string }
type ResourceRow = {
  id: string
  name: string
  resource_type: string
  sport_id: string | null
  capacity: number
  status: string
  bookable_id: string | null
  price: number | null
  currency_code: string | null
}

export default function ClubDashboard({
  organizationId,
  sports,
  resources,
}: {
  organizationId: string
  sports: Sport[]
  resources: ResourceRow[]
}) {
  const t = useTranslations('ClubDashboard')
  const router = useRouter()
  const supabase = createClient()

  const [name, setName] = useState('')
  const [resourceType, setResourceType] = useState('cancha')
  const [sportId, setSportId] = useState(sports[0]?.id ?? '')
  const [capacity, setCapacity] = useState('4')
  const [price, setPrice] = useState('0')
  const [currency, setCurrency] = useState('COP')
  const [bookingMode, setBookingMode] = useState<'instant' | 'approval_required'>('instant')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleAddResource(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!name.trim()) { setError(t('errNameRequired')); return }
    const priceNum = Number(price)
    if (Number.isNaN(priceNum) || priceNum < 0) { setError(t('errPriceInvalid')); return }

    setBusy(true)
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { setBusy(false); return }

    const { data: resource, error: rpcError } = await supabase.rpc('create_organization_resource', {
      p_organization_id: organizationId,
      p_location_id: null,
      p_sport_id: sportId || null,
      p_name: name.trim(),
      p_resource_type: resourceType.trim() || 'cancha',
      p_capacity: Number(capacity) || 1,
      p_metadata: {},
    })

    if (rpcError || !resource) {
      setBusy(false)
      setError(rpcError?.message || t('errCreateFailed'))
      return
    }

    const { error: bookableError } = await supabase.from('bookable_entities').insert({
      owner_id: user.id,
      entity_type: 'resource',
      entity_id: resource.id,
      organization_resource_id: resource.id,
      title: name.trim(),
      sport_id: sportId || null,
      capacity: Number(capacity) || 1,
      price: priceNum,
      currency_code: currency,
      booking_mode: bookingMode,
      status: 'active',
    })

    setBusy(false)
    if (bookableError) {
      setError(t('errCreateFailed'))
      return
    }
    setName(''); setCapacity('4'); setPrice('0')
    router.refresh()
  }

  async function toggleResource(r: ResourceRow) {
    setBusy(true)
    const nextStatus = r.status === 'active' ? 'paused' : 'active'
    const { error: rpcError } = await supabase.rpc('set_organization_resource_status', {
      p_resource_id: r.id,
      p_status: nextStatus,
    })
    if (!rpcError && r.bookable_id) {
      await supabase.from('bookable_entities').update({ status: nextStatus }).eq('id', r.bookable_id)
    }
    setBusy(false)
    router.refresh()
  }

  return (
    <div className="space-y-6">
      <div>
        <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black mb-3">{t('resourcesTitle')}</div>
        <div className="space-y-3">
          {resources.map((r) => (
            <div key={r.id} className="rounded-2xl bg-white/5 p-4 flex items-center justify-between gap-3">
              <div>
                <div className="font-black">{r.name}</div>
                <div className="text-xs text-white/40 mt-0.5">
                  {r.resource_type} · {sports.find((s) => s.id === r.sport_id)?.name ?? '—'} ·{' '}
                  {r.price != null ? `${r.price} ${r.currency_code ?? ''}` : '—'}
                </div>
              </div>
              <div className="flex items-center gap-3">
                <span className={`text-xs font-black px-3 py-1 rounded-full ${r.status === 'active' ? 'bg-[#00E676]/15 text-[#00E676]' : 'bg-white/10 text-white/50'}`}>
                  {r.status === 'active' ? t('statusActive') : t('statusPaused')}
                </span>
                <button
                  onClick={() => toggleResource(r)}
                  disabled={busy}
                  className="rounded-xl border border-white/10 px-3 py-1.5 text-xs font-bold hover:bg-white/5 disabled:opacity-50"
                >
                  {r.status === 'active' ? t('pauseBtn') : t('activateBtn')}
                </button>
              </div>
            </div>
          ))}
          {resources.length === 0 && <div className="rounded-2xl bg-white/5 p-4 text-white/45">{t('emptyResources')}</div>}
        </div>
      </div>

      <form onSubmit={handleAddResource} className="rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-6 space-y-4">
        <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black">{t('addTitle')}</div>
        <div className="grid md:grid-cols-2 gap-4">
          <div>
            <label className="text-xs font-bold text-white/40">{t('nameLabel')}</label>
            <input value={name} onChange={(e) => setName(e.target.value)} placeholder={t('namePlaceholder')} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white placeholder:text-white/25 outline-none focus:border-[#D4AF37]/50" />
          </div>
          <div>
            <label className="text-xs font-bold text-white/40">{t('typeLabel')}</label>
            <input value={resourceType} onChange={(e) => setResourceType(e.target.value)} placeholder={t('typePlaceholder')} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white placeholder:text-white/25 outline-none focus:border-[#D4AF37]/50" />
          </div>
          <div>
            <label className="text-xs font-bold text-white/40">{t('sportLabel')}</label>
            <select value={sportId} onChange={(e) => setSportId(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50">
              <option value="">{t('selectSport')}</option>
              {sports.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
            </select>
          </div>
          <div>
            <label className="text-xs font-bold text-white/40">{t('capacityLabel')}</label>
            <input type="number" min={1} value={capacity} onChange={(e) => setCapacity(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50" />
          </div>
          <div>
            <label className="text-xs font-bold text-white/40">{t('priceLabel')}</label>
            <input type="number" min={0} value={price} onChange={(e) => setPrice(e.target.value)} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50" />
          </div>
          <div>
            <label className="text-xs font-bold text-white/40">{t('currencyLabel')}</label>
            <input value={currency} onChange={(e) => setCurrency(e.target.value.toUpperCase())} maxLength={3} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50 uppercase" />
          </div>
          <div className="md:col-span-2">
            <label className="text-xs font-bold text-white/40">{t('modeLabel')}</label>
            <select value={bookingMode} onChange={(e) => setBookingMode(e.target.value as 'instant' | 'approval_required')} className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-2.5 text-white outline-none focus:border-[#D4AF37]/50">
              <option value="instant">{t('modeInstant')}</option>
              <option value="approval_required">{t('modeApproval')}</option>
            </select>
          </div>
        </div>
        {error && <div className="text-sm text-red-400">{error}</div>}
        <button type="submit" disabled={busy} className="w-full rounded-xl bg-[#D4AF37] text-black font-black py-3 disabled:opacity-50">
          {busy ? t('submitting') : t('submitBtn')}
        </button>
      </form>
    </div>
  )
}
