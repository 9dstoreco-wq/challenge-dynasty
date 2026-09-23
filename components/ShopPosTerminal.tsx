'use client'
import { useMemo, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Search, Plus, Minus, Trash2, UserPlus, CreditCard, Banknote, Receipt, LockOpen, X } from 'lucide-react'
import { toSafeMessage } from '@/lib/safe-error'
import { useTranslations } from 'next-intl'

type Variant = {id:string;sku:string|null;title:string|null;price:number|null}
type Json = string | number | boolean | null | Json[] | {[key:string]:Json}
type Product = { id:string; title:string; base_price:number; variants:Variant[] }
type Location = { id:string; name:string; code:string }
type Register = { id:string; name:string; code:string; location_id:string; status:string; opening_float:number|null }

type CartItem = { product_id:string; variant_id:string; title:string; sku:string; price:number; quantity:number }

export default function ShopPosTerminal({products, locations, registers}:{products:Product[];locations:Location[];registers:Register[]}){
  const t = useTranslations('ShopPos')
  const supabase = createClient()
  const [locationId,setLocationId]=useState(locations[0]?.id||'')
  const [registerId,setRegisterId]=useState(registers.find(r=>r.location_id===locationId)?.id||'')
  const [query,setQuery]=useState('')
  const [cart,setCart]=useState<CartItem[]>([])
  const [payment,setPayment]=useState('cash')
  const [openingFloat,setOpeningFloat]=useState('0')
  const [fullName,setFullName]=useState('')
  const [phone,setPhone]=useState('')
  const [email,setEmail]=useState('')
  const [customerId,setCustomerId]=useState<string|null>(null)
  const [notes,setNotes]=useState('')
  const [busy,setBusy]=useState(false)
  const [message,setMessage]=useState<string|null>(null)
  const [result,setResult]=useState<Json>(null)

  const filtered=useMemo(()=>products.filter(p=>`${p.title} ${p.variants.map(v=>v.sku).join(' ')}`.toLowerCase().includes(query.toLowerCase())).slice(0,18),[products,query])
  const activeRegister=registers.find(r=>r.id===registerId)
  const total=cart.reduce((a,i)=>a+i.price*i.quantity,0)

  function add(product:Product, variant:Variant){
    setCart(c=>{const found=c.find(x=>x.variant_id===variant.id); if(found) return c.map(x=>x.variant_id===variant.id?{...x,quantity:x.quantity+1}:x); return [...c,{product_id:product.id,variant_id:variant.id,title:`${product.title}${variant.title?` · ${variant.title}`:''}`,sku:variant.sku||'',price:Number(variant.price ?? product.base_price ?? 0),quantity:1}]})
  }
  function change(id:string,delta:number){setCart(c=>c.map(x=>x.variant_id===id?{...x,quantity:x.quantity+delta}:x).filter(x=>x.quantity>0))}

  async function openRegister(){
    setBusy(true);setMessage(null)
    const {error}=await supabase.rpc('open_shop_pos_register',{p_register_id:registerId,p_opening_float:Number(openingFloat||0)})
    setMessage(error?toSafeMessage(error,'shopPos.openRegister'):t('registerOpened'))
    setBusy(false)
  }
  async function saveCustomer(){
    if(!fullName.trim()) return
    setBusy(true);setMessage(null)
    const {data,error}=await supabase.rpc('upsert_shop_customer',{p_customer_id:null,p_full_name:fullName,p_document_type:null,p_document_number:null,p_phone:phone||null,p_email:email||null,p_address:null,p_notes:null})
    if(!error) setCustomerId(data)
    setMessage(error?toSafeMessage(error,'shopPos.saveCustomer'):t('customerSaved'))
    setBusy(false)
  }
  async function sell(){
    if(!locationId||!registerId||!cart.length) return setMessage(t('selectFieldsMessage'))
    setBusy(true);setMessage(null);setResult(null)
    const {data,error}=await supabase.rpc('create_physical_shop_sale',{p_location_id:locationId,p_register_id:registerId,p_customer_id:customerId,p_items:cart.map(i=>({variant_id:i.variant_id,product_id:i.product_id,quantity:i.quantity,unit_price:i.price})),p_payment_method:payment,p_notes:notes||null,p_tax_amount:0,p_discount_amount:0})
    if(!error){setResult(data);setCart([]);setMessage(t('saleRegistered'))} else setMessage(toSafeMessage(error,'shopPos.sell'))
    setBusy(false)
  }

  return <div className="grid xl:grid-cols-[1fr_430px] gap-6">
    <section className="rounded-3xl border border-white/10 bg-[#161616] p-5">
      <div className="flex flex-wrap gap-3 items-center mb-5">
        <select value={locationId} onChange={e=>{setLocationId(e.target.value);setRegisterId(registers.find(r=>r.location_id===e.target.value)?.id||'')}} className="bg-[#0A0A0C] border border-white/10 rounded-xl px-3 py-2 text-sm"><option value="">{t('locationPlaceholder')}</option>{locations.map(l=><option key={l.id} value={l.id}>{l.name}</option>)}</select>
        <select value={registerId} onChange={e=>setRegisterId(e.target.value)} className="bg-[#0A0A0C] border border-white/10 rounded-xl px-3 py-2 text-sm"><option value="">{t('registerPlaceholder')}</option>{registers.filter(r=>r.location_id===locationId).map(r=><option key={r.id} value={r.id}>{r.name} · {r.status}</option>)}</select>
        <div className="ml-auto text-xs text-white/40">{activeRegister?.status||t('noRegisterSelected')}</div>
      </div>
      <div className="flex gap-2 mb-5"><div className="flex-1 flex items-center gap-2 bg-[#0A0A0C] border border-white/10 rounded-2xl px-4"><Search size={18} className="text-white/35"/><input value={query} onChange={e=>setQuery(e.target.value)} className="bg-transparent outline-none py-3 w-full" placeholder={t('searchPlaceholder')}/></div></div>
      {products.length===0?<div className="rounded-2xl border border-dashed border-white/10 p-8 text-center text-white/40">{t('emptyProducts')}</div>:<div className="grid md:grid-cols-2 lg:grid-cols-3 gap-3">{filtered.map(p=><div key={p.id} className="rounded-2xl bg-white/[.03] border border-white/10 p-4"><div className="font-black text-sm">{p.title}</div><div className="space-y-2 mt-3">{(p.variants.length?p.variants:[{id:`base-${p.id}`,sku:'',title:'',price:p.base_price}]).map((v)=><button key={v.id} onClick={()=>v.id.startsWith('base-')?setMessage(t('noVariantMessage')):add(p,v)} className="w-full text-left rounded-xl border border-white/10 hover:border-[#D4AF37]/50 p-3"><div className="flex justify-between gap-2"><span>{v.title||v.sku||t('variantFallback')}</span><b>{Number(v.price??p.base_price).toLocaleString('es-CO')}</b></div><div className="text-[10px] text-white/30 mt-1">{v.sku||t('noSku')}</div></button>)}</div></div>)}</div>}
    </section>
    <aside className="space-y-5">
      <section className="rounded-3xl border border-white/10 bg-[#161616] p-5"><div className="flex items-center justify-between"><h2 className="font-black text-lg">{t('saleTitle')}</h2><Receipt size={18} className="text-[#D4AF37]"/></div>
        <div className="mt-4 space-y-2 max-h-72 overflow-auto">{cart.length===0?<div className="text-white/35 text-sm">{t('emptyCart')}</div>:cart.map(i=><div key={i.variant_id} className="rounded-xl bg-white/[.03] p-3"><div className="font-bold text-sm">{i.title}</div><div className="flex items-center justify-between mt-2"><span>{(i.price*i.quantity).toLocaleString('es-CO')}</span><div className="flex items-center gap-1"><button onClick={()=>change(i.variant_id,-1)} className="p-1 rounded bg-white/5"><Minus size={14}/></button><span className="w-6 text-center">{i.quantity}</span><button onClick={()=>change(i.variant_id,1)} className="p-1 rounded bg-white/5"><Plus size={14}/></button><button onClick={()=>change(i.variant_id,-999)} className="p-1 rounded bg-red-400/10 text-red-200"><Trash2 size={14}/></button></div></div></div>)}</div>
        <div className="border-t border-white/10 mt-4 pt-4 flex justify-between text-xl font-black"><span>{t('totalLabel')}</span><span>{total.toLocaleString('es-CO')} COP</span></div>
        <div className="grid grid-cols-2 gap-2 mt-4">{([['cash',t('cash'),Banknote],['card',t('card'),CreditCard]] as const).map(([v,label,Icon])=><button key={v} onClick={()=>setPayment(v)} className={`rounded-xl p-3 border ${payment===v?'border-[#D4AF37] bg-[#D4AF37]/10':'border-white/10'}`}><Icon size={17} className="mx-auto mb-1"/><span className="text-xs font-bold">{label}</span></button>)}</div>
        <textarea value={notes} onChange={e=>setNotes(e.target.value)} className="mt-3 w-full bg-[#0A0A0C] border border-white/10 rounded-xl p-3 text-sm" placeholder={t('notesPlaceholder')}/>
        <button disabled={busy||!cart.length} onClick={sell} className="mt-3 w-full rounded-xl bg-[#D4AF37] text-black font-black py-3 disabled:opacity-40">{busy?t('processing'):t('chargeBtn')}</button>
      </section>
      <section className="rounded-3xl border border-white/10 bg-[#161616] p-5"><div className="flex items-center gap-2 font-black"><UserPlus size={17}/> {t('customerTitle')}</div><div className="grid grid-cols-2 gap-2 mt-3"><input value={fullName} onChange={e=>setFullName(e.target.value)} className="col-span-2 bg-[#0A0A0C] border border-white/10 rounded-xl p-3 text-sm" placeholder={t('fullNamePlaceholder')}/><input value={phone} onChange={e=>setPhone(e.target.value)} className="bg-[#0A0A0C] border border-white/10 rounded-xl p-3 text-sm" placeholder={t('phonePlaceholder')}/><input value={email} onChange={e=>setEmail(e.target.value)} className="bg-[#0A0A0C] border border-white/10 rounded-xl p-3 text-sm" placeholder={t('emailPlaceholder')}/></div><button disabled={busy||!fullName.trim()} onClick={saveCustomer} className="mt-3 w-full rounded-xl border border-white/10 py-3 text-sm font-black">{customerId?t('customerAssigned'):t('saveAssignCustomerBtn')}</button></section>
      <section className="rounded-3xl border border-white/10 bg-[#161616] p-5"><div className="font-black flex items-center gap-2"><LockOpen size={17}/> {t('registerOpeningTitle')}</div><div className="flex gap-2 mt-3"><input value={openingFloat} onChange={e=>setOpeningFloat(e.target.value)} className="flex-1 bg-[#0A0A0C] border border-white/10 rounded-xl p-3 text-sm" type="number" min="0" placeholder={t('openingFloatPlaceholder')}/><button disabled={busy||!registerId} onClick={openRegister} className="rounded-xl bg-[#D4AF37] text-black px-4 font-black">{t('openBtn')}</button></div></section>
      {message&&<div className="rounded-2xl border border-white/10 bg-white/[.03] p-4 text-sm">{message}</div>}
      {result&&<div className="rounded-2xl border border-[#D4AF37]/20 bg-[#D4AF37]/5 p-4 text-sm"><div className="font-black">{t('receiptGenerated')}</div><pre className="text-[10px] text-white/50 mt-2 whitespace-pre-wrap">{JSON.stringify(result,null,2)}</pre></div>}
    </aside>
  </div>
}
