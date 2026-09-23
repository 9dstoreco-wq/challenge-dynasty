'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createBrowserClient } from '@supabase/ssr'
import { Loader2, PlusCircle, Package, Globe2, Truck } from 'lucide-react'
import { COUNTRIES } from '@/lib/countries'
import { useTranslations } from 'next-intl'

const supabase = createBrowserClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
)

export type Product = {
  id: string
  slug: string
  title: string
  description: string | null
  status: string
  base_price: number
  currency_code: string
  image_url: string | null
  created_at: string
}

type MarketPrice = { id: string; product_id: string; country_code: string; currency_code: string; price: number }
export type ShippingRule = { id: string; country_code: string; currency_code: string; standard_cost: number; free_threshold: number | null; discounted_cost: number | null }

function slugify(title: string): string {
  return title.toLowerCase().trim()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '') || 'producto'
}

export default function ShopProductManager({ products, shippingRules }: { products: Product[]; shippingRules: ShippingRule[] }) {
  const t = useTranslations('ShopAdmin')
  const router = useRouter()
  const [showAdd, setShowAdd] = useState(false)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [basePrice, setBasePrice] = useState('')
  const [imageUrl, setImageUrl] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [expanded, setExpanded] = useState<string | null>(null)

  function friendlyError(message: string): string {
    if (/permission|policy|rls|SHOP_PERMISSION_DENIED/i.test(message)) return t('permissionDenied')
    return message || t('genericError')
  }

  async function addProduct() {
    if (!title.trim()) { setError(t('errTitleRequired')); return }
    if (!basePrice || Number(basePrice) <= 0) { setError(t('errPriceRequired')); return }
    setBusy(true)
    setError(null)
    const { error: rpcError } = await supabase.rpc('create_shop_product', {
      p_slug: `${slugify(title)}-${Date.now().toString(36)}`,
      p_title: title.trim(),
      p_description: description.trim() || null,
      p_base_price: Number(basePrice),
      p_currency_code: 'COP',
      p_product_type: 'merchandise',
      p_image_url: imageUrl.trim() || null,
    })
    setBusy(false)
    if (rpcError) { setError(friendlyError(rpcError.message)); return }
    setTitle(''); setDescription(''); setBasePrice(''); setImageUrl(''); setShowAdd(false)
    router.refresh()
  }

  async function toggleStatus(p: Product) {
    const next = p.status === 'active' ? 'draft' : 'active'
    const { error: rpcError } = await supabase.rpc('update_shop_product', {
      p_product_id: p.id, p_title: null, p_description: null, p_base_price: null, p_currency_code: null, p_status: next, p_image_url: null,
    })
    if (rpcError) { setError(friendlyError(rpcError.message)); return }
    router.refresh()
  }

  return (
    <div className="rounded-3xl border border-white/10 bg-[#161616] p-6 mt-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3"><Package className="text-[#D4AF37]" /><h2 className="font-black text-xl">{t('catalogTitle', {count: products.length})}</h2></div>
        <button onClick={() => setShowAdd((v) => !v)} className="rounded-2xl bg-[#D4AF37] text-black font-black px-5 py-3 inline-flex items-center gap-2"><PlusCircle size={17} /> {showAdd ? t('cancelBtn') : t('addProductBtn')}</button>
      </div>

      {showAdd && (
        <div className="mt-5 rounded-2xl border border-white/10 bg-white/[.03] p-5">
          <div className="grid sm:grid-cols-2 gap-4">
            <div className="sm:col-span-2">
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">{t('titleLabel')}</label>
              <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder={t('titlePlaceholder')} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
            </div>
            <div className="sm:col-span-2">
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">{t('descLabel')}</label>
              <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">{t('basePriceLabel')}</label>
              <input value={basePrice} onChange={(e) => setBasePrice(e.target.value.replace(/[^0-9]/g, ''))} placeholder={t('basePricePlaceholder')} className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-white/45 font-black">{t('imageUrlLabel')}</label>
              <input value={imageUrl} onChange={(e) => setImageUrl(e.target.value)} placeholder="https://..." className="mt-2 w-full rounded-xl bg-white/[.05] border border-white/10 px-4 py-3 text-white" />
            </div>
          </div>
          {error && <p className="text-red-300 text-sm mt-3">{error}</p>}
          <button disabled={busy} onClick={addProduct} className="mt-4 rounded-2xl bg-white text-black font-black px-5 py-3 inline-flex items-center gap-2 disabled:opacity-60">
            {busy ? <Loader2 size={17} className="animate-spin" /> : null} {busy ? t('creating') : t('createProductBtn')}
          </button>
        </div>
      )}

      <div className="mt-5 space-y-3">
        {products.length === 0 ? (
          <p className="text-white/40 text-sm">{t('emptyProducts')}</p>
        ) : products.map((p) => (
          <div key={p.id} className="rounded-2xl border border-white/10 bg-white/[.02] p-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div className="flex items-center gap-3">
                {p.image_url ? <img src={p.image_url} alt="" className="w-12 h-12 rounded-lg object-cover border border-white/10" /> : <div className="w-12 h-12 rounded-lg bg-white/5 border border-white/10 flex items-center justify-center text-white/20"><Package size={18} /></div>}
                <div>
                  <div className="font-black">{p.title}</div>
                  <div className="text-xs text-white/40 mt-1">{Number(p.base_price).toLocaleString('es-CO')} {p.currency_code} · {p.status}</div>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <button onClick={() => setExpanded(expanded === p.id ? null : p.id)} className="rounded-xl border border-white/10 px-4 py-2 text-sm font-black inline-flex items-center gap-1"><Globe2 size={14} /> {t('pricesVariantsBtn')}</button>
                <button onClick={() => toggleStatus(p)} className="rounded-xl border border-white/10 px-4 py-2 text-sm font-black">{p.status === 'active' ? t('unpublishBtn') : t('publishBtn')}</button>
              </div>
            </div>
            {expanded === p.id && <ProductDetail productId={p.id} onChanged={() => router.refresh()} />}
          </div>
        ))}
      </div>

      <ShippingRulesEditor rules={shippingRules} onChanged={() => router.refresh()} />
    </div>
  )
}

function ProductDetail({ productId, onChanged }: { productId: string; onChanged: () => void }) {
  const t = useTranslations('ShopAdmin')
  const [marketPrices, setMarketPrices] = useState<MarketPrice[] | null>(null)
  const [country, setCountry] = useState('US')
  const [currency, setCurrency] = useState('USD')
  const [price, setPrice] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  function friendlyError(message: string): string {
    if (/permission|policy|rls|SHOP_PERMISSION_DENIED/i.test(message)) return t('permissionDenied')
    return message || t('genericError')
  }

  async function load() {
    const { data } = await supabase.from('shop_product_market_prices').select('id,product_id,country_code,currency_code,price').eq('product_id', productId)
    setMarketPrices((data ?? []) as MarketPrice[])
  }

  if (marketPrices === null) { load(); return <div className="mt-4 text-sm text-white/40">{t('loadingEllipsis')}</div> }

  async function addPrice() {
    if (!price || Number(price) <= 0) { setError(t('errPriceInvalid')); return }
    setBusy(true)
    setError(null)
    const { error: rpcError } = await supabase.rpc('set_shop_product_market_price', {
      p_product_id: productId, p_country_code: country, p_currency_code: currency, p_price: Number(price),
    })
    setBusy(false)
    if (rpcError) { setError(friendlyError(rpcError.message)); return }
    setPrice('')
    setMarketPrices(null)
    onChanged()
  }

  return (
    <div className="mt-4 rounded-xl border border-white/10 bg-black/20 p-4">
      <div className="text-xs uppercase tracking-widest text-white/40 font-black mb-2">{t('marketPricesTitle')}</div>
      <div className="space-y-1 mb-3">
        {marketPrices.length === 0 && <p className="text-white/30 text-sm">{t('noMarketPrices')}</p>}
        {marketPrices.map((m) => (
          <div key={m.id} className="flex justify-between text-sm rounded-lg bg-white/[.03] px-3 py-2">
            <span>{COUNTRIES.find((c) => c.code === m.country_code)?.flag} {m.country_code}</span>
            <b>{Number(m.price).toLocaleString('en-US')} {m.currency_code}</b>
          </div>
        ))}
      </div>
      <div className="flex flex-wrap gap-2 items-end">
        <select value={country} onChange={(e) => setCountry(e.target.value)} className="rounded-lg bg-white/[.05] border border-white/10 px-3 py-2 text-sm">
          {COUNTRIES.map((c) => <option key={c.code} value={c.code} className="bg-[#161616]">{c.flag} {c.name}</option>)}
        </select>
        <select value={currency} onChange={(e) => setCurrency(e.target.value)} className="rounded-lg bg-white/[.05] border border-white/10 px-3 py-2 text-sm">
          <option value="USD" className="bg-[#161616]">USD</option>
          <option value="COP" className="bg-[#161616]">COP</option>
          <option value="EUR" className="bg-[#161616]">EUR</option>
        </select>
        <input value={price} onChange={(e) => setPrice(e.target.value.replace(/[^0-9.]/g, ''))} placeholder="Ej: 50" className="rounded-lg bg-white/[.05] border border-white/10 px-3 py-2 text-sm w-28" />
        <button disabled={busy} onClick={addPrice} className="rounded-lg bg-[#D4AF37] text-black font-black px-4 py-2 text-sm disabled:opacity-60">{busy ? '...' : t('saveBtn')}</button>
      </div>
      {error && <p className="text-red-300 text-sm mt-2">{error}</p>}
    </div>
  )
}

function ShippingRulesEditor({ rules, onChanged }: { rules: ShippingRule[]; onChanged: () => void }) {
  const t = useTranslations('ShopAdmin')
  const [country, setCountry] = useState('US')
  const [standardCost, setStandardCost] = useState('')
  const [freeThreshold, setFreeThreshold] = useState('')
  const [discountedCost, setDiscountedCost] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  function friendlyError(message: string): string {
    if (/permission|policy|rls|SHOP_PERMISSION_DENIED/i.test(message)) return t('permissionDenied')
    return message || t('genericError')
  }

  async function save() {
    if (!standardCost) { setError(t('errShippingCostRequired')); return }
    setBusy(true)
    setError(null)
    const { error: rpcError } = await supabase.rpc('set_shop_shipping_rule', {
      p_country_code: country,
      p_currency_code: 'COP',
      p_standard_cost: Number(standardCost),
      p_free_threshold: freeThreshold ? Number(freeThreshold) : null,
      p_discounted_cost: discountedCost ? Number(discountedCost) : null,
    })
    setBusy(false)
    if (rpcError) { setError(friendlyError(rpcError.message)); return }
    setStandardCost(''); setFreeThreshold(''); setDiscountedCost('')
    onChanged()
  }

  return (
    <div className="mt-6 rounded-2xl border border-white/10 bg-white/[.02] p-5">
      <div className="flex items-center gap-2 mb-3"><Truck className="text-[#D4AF37]" size={18} /><h3 className="font-black">{t('shippingRulesTitle')}</h3></div>
      <p className="text-xs text-white/40 mb-3">{t('shippingRulesSubtitle')}</p>
      <div className="space-y-1 mb-4">
        {rules.map((r) => (
          <div key={r.id} className="flex flex-wrap justify-between gap-2 text-sm rounded-lg bg-white/[.03] px-3 py-2">
            <span className="font-black">{r.country_code === '*' ? t('restOfWorld') : r.country_code}</span>
            <span className="text-white/60">{r.free_threshold != null
              ? t('shippingRuleLineWithThreshold', {cost: Number(r.standard_cost).toLocaleString('es-CO'), threshold: Number(r.free_threshold).toLocaleString('es-CO'), discounted: Number(r.discounted_cost ?? 0).toLocaleString('es-CO')})
              : t('shippingRuleLine', {cost: Number(r.standard_cost).toLocaleString('es-CO')})}</span>
          </div>
        ))}
      </div>
      <div className="flex flex-wrap gap-2 items-end">
        <select value={country} onChange={(e) => setCountry(e.target.value)} className="rounded-lg bg-white/[.05] border border-white/10 px-3 py-2 text-sm">
          <option value="*" className="bg-[#161616]">🌍 {t('restOfWorld')}</option>
          {COUNTRIES.map((c) => <option key={c.code} value={c.code} className="bg-[#161616]">{c.flag} {c.name}</option>)}
        </select>
        <input value={standardCost} onChange={(e) => setStandardCost(e.target.value.replace(/[^0-9]/g, ''))} placeholder={t('standardCostPlaceholder')} className="rounded-lg bg-white/[.05] border border-white/10 px-3 py-2 text-sm w-36" />
        <input value={freeThreshold} onChange={(e) => setFreeThreshold(e.target.value.replace(/[^0-9]/g, ''))} placeholder={t('thresholdPlaceholder')} className="rounded-lg bg-white/[.05] border border-white/10 px-3 py-2 text-sm w-40" />
        <input value={discountedCost} onChange={(e) => setDiscountedCost(e.target.value.replace(/[^0-9]/g, ''))} placeholder={t('discountedShippingPlaceholder')} className="rounded-lg bg-white/[.05] border border-white/10 px-3 py-2 text-sm w-40" />
        <button disabled={busy} onClick={save} className="rounded-lg bg-[#D4AF37] text-black font-black px-4 py-2 text-sm disabled:opacity-60">{busy ? '...' : t('saveRuleBtn')}</button>
      </div>
      {error && <p className="text-red-300 text-sm mt-2">{error}</p>}
    </div>
  )
}
