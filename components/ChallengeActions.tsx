'use client'
import { useState } from 'react'
import { respondToChallenge } from '@/app/actions/challenges'

export default function ChallengeActions({challengeId,status,currentUserId,challengerId,invitationId}:{challengeId:string;status:string;currentUserId?:string;challengerId?:string;invitationId?:string}){
  const [busy,setBusy]=useState(false); const [message,setMessage]=useState('')
  async function respond(accept:boolean){setBusy(true);setMessage('');try{if(!invitationId) throw new Error('Invitación no disponible'); await respondToChallenge(invitationId,accept);setMessage(accept?'✅ Reto aceptado':'Reto rechazado');window.location.reload()}catch(e){setMessage(e instanceof Error?e.message:'No se pudo actualizar el reto')}finally{setBusy(false)}}
  async function cancel(){setBusy(true);setMessage('');try{setMessage('La cancelación del reto se gestionará desde el flujo de organización.') ;window.location.reload()}catch(e){setMessage(e instanceof Error?e.message:'No se pudo cancelar')}finally{setBusy(false)}}
  if(status==='pending') return <div className="mt-6 max-w-xl mx-auto"><div className="grid grid-cols-2 gap-3"><button disabled={busy} onClick={()=>respond(true)} className="rounded-2xl bg-[#00E676] text-black py-4 font-black">✅ ACEPTAR RETO</button><button disabled={busy} onClick={()=>respond(false)} className="rounded-2xl border border-white/10 bg-white/5 py-4 font-bold">❌ RECHAZAR</button></div>{message&&<p className="text-center text-sm text-white/55 mt-3">{message}</p>}</div>
  if(status==='creator') return <div className="mt-6 text-center"><div className="text-sm text-white/50">Eres el creador de este reto.</div><button disabled={busy} onClick={cancel} className="mt-3 rounded-xl border border-red-400/20 bg-red-500/5 px-4 py-2 text-xs font-black text-red-300">CANCELAR RETO</button>{message&&<p className="text-center text-sm text-white/55 mt-3">{message}</p>}</div>
  return <div className="mt-6 text-center text-sm text-white/50">Estado de invitación: {status}</div>
}
