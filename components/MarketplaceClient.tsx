'use client'

import { useMemo, useState } from 'react'
import { createBrowserClient } from '@supabase/ssr'
import { CheckCircle2, Loader2, ShoppingCart, X } from 'lucide-react'
import { toSafeMessage } from '@/lib/safe-error'
import { COUNTRIES, countryLabel } from '@/lib/countries'

type Listing = {
  id: string
  title: string
  description: string | null
  city: string | null
  price: number | null
  currency_code: string | null
  listing_type: string
  is_featured: boolean | null
  published_at: string | null
  seller_id: string | null
  country_code: string | null
}

const supabase = createBrowserClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
)

export default function MarketplaceClient({ listings }: { listings: Listing[] }) {
  const [selected, setSelected] = useState<Listing | null>(null)
  const [qty, setQty] = useState(1)
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [countryFilter, setCountryFilter] = useState<string>('all')

  const availableCountries = useMemo(() => {
    const codes = new Set(listings.map((x) => x.country_code).filter(Boolean) as string[])
    return COUNTRIES.filter((c) => codes.has(c.code))
  }, [listings])

  const filtered = useMemo(() => {
    if (countryFilter === 'all') return listings
    if (countryFilter === 'none') return listings.filter((x) => !x.country_code)
    return listings.filter((x) => x.country_code === countryFilter)
  }, [listings, countryFilter])

  const total = useMemo(() => (selected?.price ?? 0) * qty, [selected, qty])

  async function reserve() {
    if (!selected) return
    setBusy(true)
    setError(null)
    setMessage(null)
    try {
      const { data: userData } = await supabase.auth.getUser()
      if (!userData.user) throw new Error('Debes iniciar sesión para comprar.')
      const { data, error: rpcError } = await supabase.rpc('create_marketplace_order', {
        p_items: [{ listing_id: selected.id, quantity: qty }],
        p_delivery_amount: 0,
      })
      if (rpcError) throw rpcError
      setMessage(`Orden reservada correctamente: ${String(data).slice(0, 8)}…`)
      setSelected(null)
    } catch (e) {
      setError(toSafeMessage(e, 'marketplace.reserve', 'No se pudo crear la orden.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      {availableCountries.length > 1 && (
        <div className="mb-6 flex items-center gap-3 flex-wrap">
          <span className="text-xs uppercase tracking-widest text-white/40 font-black">País</span>
          <button onClick={() => setCountryFilter('all')} className={`rounded-full px-4 py-2 text-sm font-black border ${countryFilter === 'all' ? 'bg-[#D4AF37] text-black border-[#D4AF37]' : 'border-white/10 text-white/60'}`}>Todos</button>
          {availableCountries.map((c) => (
            <button key={c.code} onClick={() => setCountryFilter(c.code)} className={`rounded-full px-4 py-2 text-sm font-black border ${countryFilter === c.code ? 'bg-[#D4AF37] text-black border-[#D4AF37]' : 'border-white/10 text-white/60'}`}>{c.flag} {c.name}</button>
          ))}
        </div>
      )}

      <div className="grid md:grid-cols-2 xl:grid-cols-3 gap-5">
        {filtered.map((x) => (
          <article key={x.id} className="rounded-3xl border border-white/10 bg-[#161616] p-6 flex flex-col">
            <div className="flex items-center justify-between gap-3">
              <div className="text-xs text-[#D4AF37] font-black uppercase tracking-widest">{x.listing_type}</div>
              {x.is_featured ? <span className="text-[10px] rounded-full border border-[#D4AF37]/30 px-2 py-1 text-[#D4AF37] font-black">DESTACADO</span> : null}
            </div>
            <h2 className="text-xl font-black mt-2">{x.title}</h2>
            <p className="text-white/45 text-sm mt-2 flex-1">{x.description || 'Publicación Marketplace'}</p>
            <div className="mt-4 text-lg font-black">{x.price != null ? `${Number(x.price).toLocaleString('es-CO')} ${x.currency_code || 'COP'}` : 'Precio a consultar'}</div>
            <div className="text-xs text-white/35 mt-2 flex items-center gap-2 flex-wrap">
              <span>{x.city || 'Ubicación no especificada'}</span>
              <span className="text-white/20">·</span>
              <span>{countryLabel(x.country_code)}</span>
            </div>
            <button onClick={() => { setSelected(x); setQty(1); setError(null); setMessage(null) }} className="mt-5 rounded-2xl bg-white text-black font-black px-4 py-3 inline-flex items-center justify-center gap-2">
              <ShoppingCart size={17} /> Reservar / comprar
            </button>
          </article>
        ))}
      </div>

      {filtered.length === 0 && (
        <div className="rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-8 text-center text-white/45">No hay publicaciones para ese país.</div>
      )}

      {(message || error) && (
        <div className={`mt-6 rounded-2xl border p-4 ${error ? 'border-red-400/30 bg-red-400/10 text-red-100' : 'border-emerald-400/30 bg-emerald-400/10 text-emerald-100'}`}>
          <div className="flex items-start gap-3">
            {error ? <X size={18} className="mt-0.5" /> : <CheckCircle2 size={18} className="mt-0.5" />}
            <span>{error || message}</span>
          </div>
        </div>
      )}

      {selected && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4" role="dialog" aria-modal="true">
          <div className="w-full max-w-md rounded-3xl border border-white/10 bg-[#111827] p-6 shadow-2xl">
            <div className="flex items-start justify-between gap-4">
              <div>
                <div className="text-xs uppercase tracking-widest text-[#D4AF37] font-black">Nueva orden</div>
                <h3 className="text-2xl font-black mt-1">{selected.title}</h3>
              </div>
              <button onClick={() => setSelected(null)} className="rounded-full border border-white/10 p-2" aria-label="Cerrar"><X size={18} /></button>
            </div>
            <div className="mt-6">
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">Cantidad</label>
              <div className="flex items-center gap-3 mt-2">
                <button onClick={() => setQty(Math.max(1, qty - 1))} className="rounded-xl border border-white/10 px-4 py-2">−</button>
                <div className="min-w-14 text-center font-black text-xl">{qty}</div>
                <button onClick={() => setQty(Math.min(20, qty + 1))} className="rounded-xl border border-white/10 px-4 py-2">+</button>
              </div>
            </div>
            <div className="mt-6 rounded-2xl bg-white/[.04] p-4 flex items-center justify-between">
              <span className="text-white/45">Subtotal</span>
              <strong>{total.toLocaleString('es-CO')} {selected.currency_code || 'COP'}</strong>
            </div>
            <button disabled={busy} onClick={reserve} className="mt-5 w-full rounded-2xl bg-[#D4AF37] text-black font-black px-5 py-3 flex items-center justify-center gap-2 disabled:opacity-60">
              {busy ? <Loader2 size={17} className="animate-spin" /> : <ShoppingCart size={17} />} {busy ? 'Procesando…' : 'Crear orden reservada'}
            </button>
            <p className="text-xs text-white/35 mt-3 text-center">La orden reserva inventario. El pago real se confirma posteriormente mediante el proveedor conectado.</p>
          </div>
        </div>
      )}
    </>
  )
}
