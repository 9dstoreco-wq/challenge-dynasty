'use client'

import { useMemo, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { CalendarDays, Clock3, CreditCard, Loader2, ShieldCheck, XCircle } from 'lucide-react'
import { toSafeMessage } from '@/lib/safe-error'

type Bookable={id:string;title:string;activity_name:string|null;duration_minutes:number;price:number;currency_code:string;capacity:number;booking_mode:string;location_id:string|null}
type Booking={id:string;bookable_id:string;starts_at:string;ends_at:string;status:string;payment_status:string;amount:number;currency_code:string;quantity:number}

export default function BookingControlCenter({bookables,bookings}:{bookables:Bookable[];bookings:Booking[]}){
 const supabase=createClient()
 const [bookableId,setBookableId]=useState(bookables[0]?.id||'')
 const [starts,setStarts]=useState(()=>new Date(Date.now()+60*60*1000).toISOString().slice(0,16))
 const [quantity,setQuantity]=useState(1)
 const [busy,setBusy]=useState(false)
 const [message,setMessage]=useState<string|null>(null)
 const [error,setError]=useState<string|null>(null)
 const selected=useMemo(()=>bookables.find(x=>x.id===bookableId),[bookables,bookableId])
 const end=useMemo(()=> selected ? new Date(new Date(starts).getTime()+selected.duration_minutes*60000).toISOString() : '',[starts,selected])
 async function reserve(){
  if(!selected) return
  setBusy(true); setError(null); setMessage(null)
  try{
   const {data:userData}=await supabase.auth.getUser(); if(!userData.user) throw new Error('Debes iniciar sesión para reservar.')
   const {data,error:rpcError}=await supabase.rpc('create_atomic_booking',{p_requested_by:userData.user.id,p_starts_at:new Date(starts).toISOString(),p_ends_at:end,p_items:[{bookable_id:selected.id,quantity}]})
   if(rpcError) throw rpcError
   setMessage(`Reserva creada: ${String(data).slice(0,8)}…`)
  }catch(e){setError(toSafeMessage(e,'bookings.reserve','No se pudo crear la reserva.'))}finally{setBusy(false)}
 }
 async function cancel(id:string){setBusy(true);setError(null);setMessage(null);try{const {error:e}=await supabase.rpc('cancel_booking',{p_booking_id:id});if(e)throw e;setMessage('Reserva cancelada. Recarga para actualizar el calendario.')}catch(e){setError(toSafeMessage(e,'bookings.cancel','No se pudo cancelar.'))}finally{setBusy(false)}}
 return <div className="space-y-6">
  <section className="rounded-3xl border border-white/10 bg-[#141B2D] p-6">
   <div className="flex items-start justify-between gap-4"><div><div className="text-xs tracking-[.25em] text-[#FFD700] font-black">BOOKING ENGINE</div><h2 className="text-2xl font-black mt-1">RESERVA ATÓMICA</h2><p className="text-sm text-white/45 mt-2 max-w-2xl">Disponibilidad, capacidad, conflictos y pago quedan validados por el backend antes de confirmar.</p></div><ShieldCheck className="text-[#00F0FF]"/></div>
   {bookables.length===0 ? <div className="mt-6 rounded-2xl border border-dashed border-white/10 p-8 text-white/45">No hay recursos reservables activos todavía.</div> : <>
    <div className="grid md:grid-cols-[1.4fr_.8fr_.5fr] gap-3 mt-6">
      <select value={bookableId} onChange={e=>setBookableId(e.target.value)} className="bg-[#0B0F19] border border-white/10 rounded-xl p-3 text-sm">{bookables.map(x=><option key={x.id} value={x.id}>{x.title} · {x.activity_name||'Servicio'} · {Number(x.price).toLocaleString('es-CO')} {x.currency_code}</option>)}</select>
      <input type="datetime-local" value={starts} onChange={e=>setStarts(e.target.value)} className="bg-[#0B0F19] border border-white/10 rounded-xl p-3 text-sm" aria-label="Inicio de reserva"/>
      <input type="number" min="1" max={selected?.capacity||1} value={quantity} onChange={e=>setQuantity(Math.max(1,Math.min(selected?.capacity||1,Number(e.target.value)||1)))} className="bg-[#0B0F19] border border-white/10 rounded-xl p-3 text-sm" aria-label="Cantidad"/>
    </div>
    {selected&&<div className="grid md:grid-cols-4 gap-3 mt-4 text-sm"><div className="rounded-xl bg-black/15 p-3"><Clock3 size={15} className="text-[#00F0FF]"/><div className="text-white/40 mt-1">Duración</div><strong>{selected.duration_minutes} min</strong></div><div className="rounded-xl bg-black/15 p-3"><CalendarDays size={15} className="text-[#00F0FF]"/><div className="text-white/40 mt-1">Capacidad</div><strong>{selected.capacity}</strong></div><div className="rounded-xl bg-black/15 p-3"><CreditCard size={15} className="text-[#FFD700]"/><div className="text-white/40 mt-1">Total</div><strong>{(Number(selected.price)*quantity).toLocaleString('es-CO')} {selected.currency_code}</strong></div><div className="rounded-xl bg-black/15 p-3"><div className="text-white/40">Termina</div><strong>{new Date(end).toLocaleString('es-CO')}</strong></div></div>}
    <button disabled={busy||!selected} onClick={reserve} className="mt-5 w-full md:w-auto rounded-xl bg-[#FFD700] text-black font-black px-6 py-3 inline-flex items-center justify-center gap-2">{busy?<Loader2 size={16} className="animate-spin"/>:<CalendarDays size={16}/>} {busy?'PROCESANDO…':'CONFIRMAR RESERVA'}</button>
   </>}
   {(message||error)&&<div className={`mt-4 rounded-2xl border p-4 text-sm ${error?'border-red-400/20 bg-red-400/10':'border-emerald-400/20 bg-emerald-400/10'}`}>{error||message}</div>}
  </section>
  <section className="rounded-3xl border border-white/10 bg-[#141B2D] p-6"><div className="flex items-center justify-between"><div><div className="text-xs tracking-[.2em] text-[#00F0FF] font-black">MY BOOKINGS</div><h2 className="text-2xl font-black mt-1">Agenda y control</h2></div><span className="text-xs text-white/40">{bookings.length} reservas</span></div>{bookings.length===0?<div className="mt-5 rounded-2xl border border-dashed border-white/10 p-8 text-white/45">Aún no tienes reservas. Cuando haya datos, aquí aparecerán estado, pago y acciones.</div>:<div className="mt-5 space-y-3">{bookings.map(b=><article key={b.id} className="rounded-2xl border border-white/10 bg-black/10 p-4"><div className="flex flex-wrap items-start justify-between gap-4"><div><div className="text-xs text-[#FFD700] uppercase tracking-widest font-black">{b.status}</div><div className="font-black mt-1">{new Date(b.starts_at).toLocaleString('es-CO')}</div><div className="text-xs text-white/40 mt-1">Pago: {b.payment_status} · Cantidad: {b.quantity}</div></div><div className="text-right"><div className="font-black">{Number(b.amount).toLocaleString('es-CO')} {b.currency_code}</div><button disabled={busy||b.status==='cancelled'} onClick={()=>cancel(b.id)} className="mt-2 text-xs font-black text-red-200 inline-flex items-center gap-1"><XCircle size={14}/> Cancelar</button></div></div></article>)}</div>}</section>
 </div>
}
