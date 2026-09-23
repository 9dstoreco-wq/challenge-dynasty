'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createBrowserClient } from '@supabase/ssr'
import { Loader2, PlusCircle, Store } from 'lucide-react'
import { COUNTRIES, countryName } from '@/lib/countries'
import { useTranslations, useLocale } from 'next-intl'

const supabase = createBrowserClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
)

export type SellerProfile = {
  id: string
  display_name: string
  seller_type: string
  country_code: string | null
  city: string | null
  status: string
} | null

export type MyListing = {
  id: string
  title: string
  listing_type: string
  status: string
  country_code: string | null
  city: string | null
  price: number | null
  currency_code: string | null
}

const LISTING_TYPE_VALUES = ['tournament', 'club', 'academy', 'coach', 'brand', 'event', 'other'] as const
const SELLER_TYPE_VALUES = ['individual', 'coach', 'club', 'organization', 'brand', 'store'] as const

export function MarketplaceCreateSellerProfile({ userId }: { userId: string }) {
  const t = useTranslations('MarketplaceSeller')
  const locale = useLocale()
  const router = useRouter()
  const [displayName, setDisplayName] = useState('')
  const [sellerType, setSellerType] = useState('individual')
  const [countryCode, setCountryCode] = useState('CO')
  const [city, setCity] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function createProfile() {
    if (!displayName.trim()) { setError(t('escribeNombre')); return }
    setBusy(true)
    setError(null)
    const { error: insertError } = await supabase.from('marketplace_seller_profiles').insert({
      owner_id: userId,
      display_name: displayName.trim(),
      seller_type: sellerType,
      country_code: countryCode,
      city: city.trim() || null,
    })
    setBusy(false)
    if (insertError) { setError(/permission|policy|rls/i.test(insertError.message) ? t('noPermiso') : insertError.message || t('errorInesperado')); return }
    router.refresh()
  }

  return (
    <div className="rounded-3xl border border-white/10 bg-[#161616] p-6">
      <div className="flex items-center gap-3"><Store className="text-[#D4AF37]" /><h2 className="font-black text-xl">{t('activarTitulo')}</h2></div>
      <p className="text-white/45 text-sm mt-2">{t('activarBody')}</p>
      <div className="grid sm:grid-cols-2 gap-4 mt-5">
        <div>
          <label className="text-xs uppercase tracking-widest text-white/45 font-black">{t('nombrePublico')}</label>
          <input value={displayName} onChange={(e) => setDisplayName(e.target.value)} placeholder={t('nombrePublicoPlaceholder')} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
        </div>
        <div>
          <label className="text-xs uppercase tracking-widest text-white/45 font-black">{t('tipoVendedor')}</label>
          <select value={sellerType} onChange={(e) => setSellerType(e.target.value)} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white">
            {SELLER_TYPE_VALUES.map((v) => <option key={v} value={v} className="bg-[#161616]">{t(`sellerTypes.${v}`)}</option>)}
          </select>
        </div>
        <div>
          <label className="text-xs uppercase tracking-widest text-white/45 font-black">{t('pais')}</label>
          <select value={countryCode} onChange={(e) => setCountryCode(e.target.value)} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white">
            {COUNTRIES.map((c) => <option key={c.code} value={c.code} className="bg-[#161616]">{c.flag} {countryName(c.code, locale)}</option>)}
          </select>
        </div>
        <div>
          <label className="text-xs uppercase tracking-widest text-white/45 font-black">{t('ciudadOpcional')}</label>
          <input value={city} onChange={(e) => setCity(e.target.value)} placeholder={t('ciudadPlaceholder')} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
        </div>
      </div>
      {error && <p className="text-red-300 text-sm mt-3">{error}</p>}
      <button disabled={busy} onClick={createProfile} className="mt-5 rounded-2xl bg-[#D4AF37] text-black font-black px-5 py-3 inline-flex items-center gap-2 disabled:opacity-60">
        {busy ? <Loader2 size={17} className="animate-spin" /> : null} {busy ? t('creando') : t('activarBtn')}
      </button>
    </div>
  )
}

export default function MarketplaceSellerPanel({ sellerProfile, myListings }: { sellerProfile: SellerProfile; myListings: MyListing[] }) {
  const t = useTranslations('MarketplaceSeller')
  const locale = useLocale()
  const router = useRouter()
  const [showForm, setShowForm] = useState(false)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [listingType, setListingType] = useState('other')
  const [city, setCity] = useState(sellerProfile?.city || '')
  const [countryCode, setCountryCode] = useState(sellerProfile?.country_code || 'CO')
  const [price, setPrice] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [statusBusyId, setStatusBusyId] = useState<string | null>(null)

  function friendlyError(message: string): string {
    if (/permission|policy|rls/i.test(message)) return t('noPermiso')
    return message || t('errorInesperado')
  }

  const listingTypeLabels: Record<string, string> = Object.fromEntries(
    LISTING_TYPE_VALUES.map((v) => [v, t(`listingTypes.${v}`)])
  )

  async function publish() {
    if (!sellerProfile) return
    if (!title.trim()) { setError(t('escribeTitulo')); return }
    setBusy(true)
    setError(null)
    const { error: insertError } = await supabase.from('marketplace_listings').insert({
      owner_id: (await supabase.auth.getUser()).data.user?.id,
      seller_id: sellerProfile.id,
      title: title.trim(),
      description: description.trim() || null,
      listing_type: listingType,
      city: city.trim() || null,
      country_code: countryCode,
      price: price ? Number(price) : null,
      currency_code: 'COP',
      status: 'published',
      published_at: new Date().toISOString(),
    })
    setBusy(false)
    if (insertError) { setError(friendlyError(insertError.message)); return }
    setTitle(''); setDescription(''); setPrice(''); setShowForm(false)
    router.refresh()
  }

  async function toggleStatus(listing: MyListing) {
    setStatusBusyId(listing.id)
    const nextStatus = listing.status === 'published' ? 'archived' : 'published'
    const { error: updateError } = await supabase.from('marketplace_listings').update({ status: nextStatus }).eq('id', listing.id)
    setStatusBusyId(null)
    if (updateError) { setError(friendlyError(updateError.message)); return }
    router.refresh()
  }

  if (!sellerProfile) return null

  return (
    <div className="rounded-3xl border border-white/10 bg-[#161616] p-6 mt-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3"><Store className="text-[#D4AF37]" /><h2 className="font-black text-xl">{t('misPublicaciones')} ({sellerProfile.display_name})</h2></div>
        <button onClick={() => setShowForm((v) => !v)} className="rounded-2xl bg-[#D4AF37] text-black font-black px-5 py-3 inline-flex items-center gap-2"><PlusCircle size={17} /> {showForm ? t('cancelar') : t('publicarNueva')}</button>
      </div>

      {showForm && (
        <div className="mt-5 rounded-2xl border border-white/10 bg-white/[.03] p-5">
          <div className="grid sm:grid-cols-2 gap-4">
            <div className="sm:col-span-2">
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">{t('titulo')}</label>
              <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder={t('tituloPlaceholder')} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
            </div>
            <div className="sm:col-span-2">
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">{t('descripcion')}</label>
              <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">{t('tipo')}</label>
              <select value={listingType} onChange={(e) => setListingType(e.target.value)} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white">
                {LISTING_TYPE_VALUES.map((v) => <option key={v} value={v} className="bg-[#161616]">{t(`listingTypes.${v}`)}</option>)}
              </select>
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">{t('precioOpcional')}</label>
              <input value={price} onChange={(e) => setPrice(e.target.value.replace(/[^0-9]/g, ''))} placeholder={t('precioPlaceholder')} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">{t('pais')}</label>
              <select value={countryCode} onChange={(e) => setCountryCode(e.target.value)} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white">
                {COUNTRIES.map((c) => <option key={c.code} value={c.code} className="bg-[#161616]">{c.flag} {countryName(c.code, locale)}</option>)}
              </select>
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">{t('ciudadOpcional')}</label>
              <input value={city} onChange={(e) => setCity(e.target.value)} placeholder={t('ciudadPlaceholder2')} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
            </div>
          </div>
          {error && <p className="text-red-300 text-sm mt-3">{error}</p>}
          <button disabled={busy} onClick={publish} className="mt-4 rounded-2xl bg-white text-black font-black px-5 py-3 inline-flex items-center gap-2 disabled:opacity-60">
            {busy ? <Loader2 size={17} className="animate-spin" /> : null} {busy ? t('publicando') : t('publicarBtn')}
          </button>
        </div>
      )}

      <div className="mt-5 space-y-3">
        {myListings.length === 0 ? (
          <p className="text-white/40 text-sm">{t('sinPublicaciones')}</p>
        ) : myListings.map((l) => (
          <div key={l.id} className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-white/10 bg-white/[.02] p-4">
            <div>
              <div className="font-black">{l.title}</div>
              <div className="text-xs text-white/40 mt-1">{listingTypeLabels[l.listing_type] || l.listing_type} · {l.city || t('sinCiudad')} · {l.status}</div>
            </div>
            <button disabled={statusBusyId === l.id} onClick={() => toggleStatus(l)} className="rounded-xl border border-white/10 px-4 py-2 text-sm font-black disabled:opacity-60">
              {statusBusyId === l.id ? '...' : l.status === 'published' ? t('pausar') : t('reactivar')}
            </button>
          </div>
        ))}
      </div>
    </div>
  )
}
