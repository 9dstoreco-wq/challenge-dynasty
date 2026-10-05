 'use client'
import { useState } from 'react'
import { requestPartner } from '@/app/actions/partners'
import { useTranslations } from 'next-intl'
export default function PartnerInviteButton({sportId,recipientId}:{sportId:string;recipientId:string}){
 const t=useTranslations('Partners')
 const [busy,setBusy]=useState(false); const [sent,setSent]=useState(false); const [error,setError]=useState('')
 async function invite(){if(busy)return;setBusy(true);setError('');try{const r=await requestPartner({sportId,recipientId});if(!r.ok){setError(r.error||t('inviteFailed'));return}setSent(true)}catch{setError(t('inviteFailed'))}finally{setBusy(false)}}
 return <button disabled={busy||sent} onClick={invite} className="flex-1 rounded-xl bg-[#D4AF37] text-black py-3 text-xs font-black">{busy?t('inviting'):sent?t('invited'):t('invite')}</button>
}
