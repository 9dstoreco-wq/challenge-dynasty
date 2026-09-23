'use client'
import { useMemo, useState } from 'react'
import Link from 'next/link'
import { Search, ShoppingBag, ArrowRight } from 'lucide-react'
import { useTranslations } from 'next-intl'

type Variant={id:string;product_id:string;sku:string|null;title:string|null;price:number;attributes:Record<string, string|number|boolean|null>|null}
type Product={id:string;slug:string;title:string;description:string|null;product_type:string;base_price:number;currency_code:string;featured:boolean;metadata:Record<string, string|number|boolean|null>|null;variants:Variant[]}

export default function ShopCatalogClient({products}:{products:Product[]}){
 const t=useTranslations('Shop')
 const [q,setQ]=useState('')
 const filtered=useMemo(()=>products.filter(p=>`${p.title} ${p.description||''} ${p.variants.map(v=>v.sku||'').join(' ')}`.toLowerCase().includes(q.toLowerCase())),[products,q])
 return <>
  <div className="flex items-center gap-3 rounded-2xl border border-white/10 bg-[#0A0A0C] px-4 py-3 mt-6"><Search size={18} className="text-white/35"/><input value={q} onChange={e=>setQ(e.target.value)} className="bg-transparent outline-none w-full" placeholder={t('searchPlaceholder')}/><ShoppingBag size={18} className="text-[#D4AF37]"/></div>
  <div className="grid md:grid-cols-2 xl:grid-cols-3 gap-5 mt-6">{filtered.map(p=><article key={p.id} className="rounded-3xl border border-white/10 bg-[#161616] overflow-hidden hover:border-[#D4AF37]/30 transition"><div className="aspect-[4/3] bg-gradient-to-br from-white/10 via-[#181B2C] to-[#0A0A0C] p-5 flex flex-col justify-between"><div className="flex justify-between"><span className="text-[10px] tracking-[.2em] uppercase text-white/40">{p.product_type}</span>{p.featured&&<span className="text-[10px] font-black text-[#D4AF37]">{t('featured')}</span>}</div><div className="text-5xl font-display font-black tracking-wide text-white/10">DYNASTY</div></div><div className="p-6"><h3 className="text-xl font-black">{p.title}</h3><p className="text-sm text-white/50 mt-2 min-h-10">{p.description||t('defaultDescription')}</p><div className="mt-4 flex items-end justify-between"><div><div className="text-xs text-white/35">{t('from')}</div><div className="text-2xl font-black">{Number(p.base_price).toLocaleString('es-CO')} {p.currency_code}</div></div><Link href={`/shop/${p.slug}`} className="rounded-xl bg-[#D4AF37] text-black px-4 py-2 font-black inline-flex items-center gap-2">{t('view')} <ArrowRight size={15}/></Link></div><div className="mt-4 text-xs text-white/35">{t('variantsCount',{count:p.variants.length})}</div></div></article>)}</div>
  {filtered.length===0&&products.length===0&&<div className="rounded-3xl border border-dashed border-[#D4AF37]/25 bg-gradient-to-br from-[#161616] to-[#0A0A0C] p-14 text-center mt-6"><div className="text-4xl font-display tracking-wide text-white/15">DYNASTY</div><div className="text-white/60 mt-3 max-w-md mx-auto">{t('emptyCatalogBody')}</div></div>}
  {filtered.length===0&&products.length>0&&<div className="rounded-3xl border border-dashed border-white/10 p-10 text-center text-white/40 mt-6">{t('noResults')}</div>}
 </>
}
