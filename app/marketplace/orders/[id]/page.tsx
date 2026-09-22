'use client'

import { useEffect, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import Sidebar from '@/components/Sidebar'
import { ArrowLeft, Ban, RotateCcw, ShieldCheck } from 'lucide-react'
import { toSafeMessage } from '@/lib/safe-error'

type OrderItem = { id: string; quantity: number; product_title: string | null; variant_title: string | null; line_total: number | null }

export default function MarketplaceOrderDetailPage(){
 const {id}=useParams<{id:string}>(); const router=useRouter(); const supabase=createClient()
 const [items,setItems]=useState<OrderItem[]>([]); const [loading,setLoading]=useState(true); const [busy,setBusy]=useState(false); const [msg,setMsg]=useState<string|null>(null); const [error,setError]=useState<string|null>(null)
 useEffect(()=>{(async()=>{const {data,error:e}=await supabase.rpc('get_my_marketplace_order_items',{p_order_id:id});if(e)setError(toSafeMessage(e,'marketplace.orderItems'));else setItems(data||[]);setLoading(false)})()},[id,supabase])
 async function cancel(){setBusy(true);setError(null);setMsg(null);const {data,error:e}=await supabase.rpc('cancel_my_marketplace_order',{p_order_id:id});if(e)setError(toSafeMessage(e,'marketplace.cancelOrder'));else setMsg(data?'Orden cancelada.':'No fue posible cancelar la orden.');setBusy(false)}
 async function startReturn(item:OrderItem){setBusy(true);setError(null);setMsg(null);const qty=Number(item.quantity||1);const reason=window.prompt('Motivo de la devolución');if(!reason){setBusy(false);return}const {data,error:e}=await supabase.rpc('create_marketplace_item_return',{p_order_item_id:item.id,p_quantity:qty,p_reason:reason});if(e)setError(toSafeMessage(e,'marketplace.createReturn'));else setMsg(`Solicitud de devolución creada: ${String(data).slice(0,8)}…`);setBusy(false)}
 return <main className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><section className="lg:pl-64 p-6 lg:p-12 max-w-[1100px] mx-auto"><button onClick={()=>router.push('/marketplace/orders')} className="text-sm text-white/50 inline-flex items-center gap-2"><ArrowLeft size={15}/> Mis órdenes</button><div className="mt-6 mb-8"><div className="text-[#D4AF37] text-xs font-black tracking-[.28em] uppercase">Marketplace Order OS</div><h1 className="text-4xl md:text-5xl font-display font-black tracking-wide mt-2">Orden {id.slice(0,8)}…</h1><p className="text-white/45 mt-2">Detalle seguro, cancelación y devoluciones por contrato backend.</p></div>
 {loading?<div className="rounded-3xl border border-white/10 bg-[#161616] p-8">Cargando orden…</div>:error?<div className="rounded-3xl border border-red-400/20 bg-red-400/10 p-8">{error}</div>:<>
 <section className="rounded-3xl border border-white/10 bg-[#161616] p-6"><div className="flex items-center justify-between"><h2 className="text-2xl font-black">Items</h2><ShieldCheck className="text-[#D4AF37]"/></div>{items.length===0?<div className="mt-5 text-white/45">La orden no tiene items visibles.</div>:<div className="mt-5 space-y-3">{items.map(item=><article key={item.id} className="rounded-2xl border border-white/10 p-4 flex flex-wrap items-center justify-between gap-4"><div><div className="font-black">{item.product_title||'Producto'}</div><div className="text-sm text-white/40 mt-1">{item.variant_title||'Variante'} · x{item.quantity}</div></div><div className="flex items-center gap-3"><div className="font-black">{Number(item.line_total||0).toLocaleString('es-CO')}</div><button disabled={busy} onClick={()=>startReturn(item)} className="rounded-xl border border-white/10 px-3 py-2 text-xs font-black inline-flex items-center gap-1"><RotateCcw size={14}/> DEVOLVER</button></div></article>)}</div>}</section>
 <section className="mt-5 rounded-3xl border border-white/10 bg-[#161616] p-6"><div className="flex flex-wrap items-center justify-between gap-4"><div><div className="text-xs text-white/40 uppercase tracking-widest">Acciones de orden</div><p className="text-sm text-white/45 mt-2">La cancelación solo procede cuando el lifecycle del pedido lo permite.</p></div><button disabled={busy} onClick={cancel} className="rounded-xl bg-red-400/10 border border-red-400/20 text-red-100 px-4 py-3 font-black inline-flex items-center gap-2"><Ban size={15}/>{busy?'PROCESANDO…':'CANCELAR ORDEN'}</button></div></section>
 {msg&&<div className="mt-5 rounded-2xl border border-emerald-400/20 bg-emerald-400/10 p-4">{msg}</div>}{error&&<div className="mt-5 rounded-2xl border border-red-400/20 bg-red-400/10 p-4">{error}</div>}
 </>}
 </section></main>
}
