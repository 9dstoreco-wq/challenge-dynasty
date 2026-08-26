 'use client'
import { useState } from 'react'
import { requestPartner } from '@/app/actions/partners'
export default function PartnerInviteButton({sportId,recipientId}:{sportId:string;recipientId:string}){
 const [busy,setBusy]=useState(false); const [sent,setSent]=useState(false); const [error,setError]=useState('')
 async function invite(){setBusy(true);setError('');try{await requestPartner({sportId,recipientId});setSent(true)}catch(e){setError(e instanceof Error?e.message:'No se pudo enviar')}finally{setBusy(false)}}
 return <button disabled={busy||sent} onClick={invite} className="flex-1 rounded-xl bg-[#00F0FF] text-black py-3 text-xs font-black">{busy?'ENVIANDO...':sent?'✓ ENVIADA':'INVITAR'}</button>
}
