'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createBrowserClient } from '@supabase/ssr'
import { Loader2, PlusCircle, Store } from 'lucide-react'
import { COUNTRIES } from '@/lib/countries'

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

const LISTING_TYPES: { value: string; label: string }[] = [
  { value: 'tournament', label: 'Torneo' },
  { value: 'club', label: 'Club' },
  { value: 'academy', label: 'Academia' },
  { value: 'coach', label: 'Coach' },
  { value: 'brand', label: 'Marca' },
  { value: 'event', label: 'Evento' },
  { value: 'other', label: 'Otro' },
]

const SELLER_TYPES: { value: string; label: string }[] = [
  { value: 'individual', label: 'Individual' },
  { value: 'coach', label: 'Coach' },
  { value: 'club', label: 'Club' },
  { value: 'organization', label: 'Organización' },
  { value: 'brand', label: 'Marca' },
  { value: 'store', label: 'Tienda' },
]

function friendlyError(message: string): string {
  if (/permission|policy|rls/i.test(message)) return 'No tienes permiso para hacer esto.'
  return message || 'Ocurrió un error inesperado.'
}

export function MarketplaceCreateSellerProfile({ userId }: { userId: string }) {
  const router = useRouter()
  const [displayName, setDisplayName] = useState('')
  const [sellerType, setSellerType] = useState('individual')
  const [countryCode, setCountryCode] = useState('CO')
  const [city, setCity] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function createProfile() {
    if (!displayName.trim()) { setError('Escribe un nombre para tu perfil de vendedor.'); return }
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
    if (insertError) { setError(friendlyError(insertError.message)); return }
    router.refresh()
  }

  return (
    <div className="rounded-3xl border border-white/10 bg-[#161616] p-6">
      <div className="flex items-center gap-3"><Store className="text-[#D4AF37]" /><h2 className="font-black text-xl">Activa tu perfil de vendedor</h2></div>
      <p className="text-white/45 text-sm mt-2">Antes de publicar en el Marketplace necesitas un perfil de vendedor. Toma un minuto.</p>
      <div className="grid sm:grid-cols-2 gap-4 mt-5">
        <div>
          <label className="text-xs uppercase tracking-widest text-white/45 font-black">Nombre público</label>
          <input value={displayName} onChange={(e) => setDisplayName(e.target.value)} placeholder="Ej: Dynasty Academy" className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
        </div>
        <div>
          <label className="text-xs uppercase tracking-widest text-white/45 font-black">Tipo de vendedor</label>
          <select value={sellerType} onChange={(e) => setSellerType(e.target.value)} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white">
            {SELLER_TYPES.map((t) => <option key={t.value} value={t.value} className="bg-[#161616]">{t.label}</option>)}
          </select>
        </div>
        <div>
          <label className="text-xs uppercase tracking-widest text-white/45 font-black">País</label>
          <select value={countryCode} onChange={(e) => setCountryCode(e.target.value)} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white">
            {COUNTRIES.map((c) => <option key={c.code} value={c.code} className="bg-[#161616]">{c.flag} {c.name}</option>)}
          </select>
        </div>
        <div>
          <label className="text-xs uppercase tracking-widest text-white/45 font-black">Ciudad (opcional)</label>
          <input value={city} onChange={(e) => setCity(e.target.value)} placeholder="Ej: Bogotá" className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
        </div>
      </div>
      {error && <p className="text-red-300 text-sm mt-3">{error}</p>}
      <button disabled={busy} onClick={createProfile} className="mt-5 rounded-2xl bg-[#D4AF37] text-black font-black px-5 py-3 inline-flex items-center gap-2 disabled:opacity-60">
        {busy ? <Loader2 size={17} className="animate-spin" /> : null} {busy ? 'Creando…' : 'Activar perfil de vendedor'}
      </button>
    </div>
  )
}

export default function MarketplaceSellerPanel({ sellerProfile, myListings }: { sellerProfile: SellerProfile; myListings: MyListing[] }) {
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

  async function publish() {
    if (!sellerProfile) return
    if (!title.trim()) { setError('Escribe un título.'); return }
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
        <div className="flex items-center gap-3"><Store className="text-[#D4AF37]" /><h2 className="font-black text-xl">Mis publicaciones ({sellerProfile.display_name})</h2></div>
        <button onClick={() => setShowForm((v) => !v)} className="rounded-2xl bg-[#D4AF37] text-black font-black px-5 py-3 inline-flex items-center gap-2"><PlusCircle size={17} /> {showForm ? 'Cancelar' : 'Publicar nueva'}</button>
      </div>

      {showForm && (
        <div className="mt-5 rounded-2xl border border-white/10 bg-white/[.03] p-5">
          <div className="grid sm:grid-cols-2 gap-4">
            <div className="sm:col-span-2">
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">Título</label>
              <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Ej: Clases grupales de padel nivel intermedio" className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
            </div>
            <div className="sm:col-span-2">
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">Descripción</label>
              <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">Tipo</label>
              <select value={listingType} onChange={(e) => setListingType(e.target.value)} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white">
                {LISTING_TYPES.map((t) => <option key={t.value} value={t.value} className="bg-[#161616]">{t.label}</option>)}
              </select>
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">Precio (opcional)</label>
              <input value={price} onChange={(e) => setPrice(e.target.value.replace(/[^0-9]/g, ''))} placeholder="Ej: 150000" className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">País</label>
              <select value={countryCode} onChange={(e) => setCountryCode(e.target.value)} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white">
                {COUNTRIES.map((c) => <option key={c.code} value={c.code} className="bg-[#161616]">{c.flag} {c.name}</option>)}
              </select>
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">Ciudad (opcional)</label>
              <input value={city} onChange={(e) => setCity(e.target.value)} placeholder="Ej: Medellín" className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
            </div>
          </div>
          {error && <p className="text-red-300 text-sm mt-3">{error}</p>}
          <button disabled={busy} onClick={publish} className="mt-4 rounded-2xl bg-white text-black font-black px-5 py-3 inline-flex items-center gap-2 disabled:opacity-60">
            {busy ? <Loader2 size={17} className="animate-spin" /> : null} {busy ? 'Publicando…' : 'Publicar en el Marketplace'}
          </button>
        </div>
      )}

      <div className="mt-5 space-y-3">
        {myListings.length === 0 ? (
          <p className="text-white/40 text-sm">Todavía no tienes publicaciones.</p>
        ) : myListings.map((l) => (
          <div key={l.id} className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-white/10 bg-white/[.02] p-4">
            <div>
              <div className="font-black">{l.title}</div>
              <div className="text-xs text-white/40 mt-1">{l.listing_type} · {l.city || 'Sin ciudad'} · {l.status}</div>
            </div>
            <button disabled={statusBusyId === l.id} onClick={() => toggleStatus(l)} className="rounded-xl border border-white/10 px-4 py-2 text-sm font-black disabled:opacity-60">
              {statusBusyId === l.id ? '...' : l.status === 'published' ? 'Pausar' : 'Reactivar'}
            </button>
          </div>
        ))}
      </div>
    </div>
  )
}
