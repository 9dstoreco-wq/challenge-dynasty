'use client'
import { useState } from 'react'
import { respondToChallenge } from '@/app/actions/challenges'
import { useTranslations } from 'next-intl'

export default function ChallengeActions({challengeId,status,currentUserId,challengerId,invitationId}:{challengeId:string;status:string;currentUserId?:string;challengerId?:string;invitationId?:string}){
  const t=useTranslations('Challenge')
  const [busy,setBusy]=useState(false); const [message,setMessage]=useState('')
  async function respond(accept:boolean){setBusy(true);setMessage('');try{if(!invitationId) throw new Error(t('invitationUnavailable')); await respondToChallenge(invitationId,accept);setMessage(accept?t('accepted'):t('rejected'));window.location.reload()}catch(e){setMessage(e instanceof Error?e.message:t('errUpdateFailed'))}finally{setBusy(false)}}
  async function cancel(){setBusy(true);setMessage('');try{setMessage(t('cancelManaged')) ;window.location.reload()}catch(e){setMessage(e instanceof Error?e.message:t('errCancelFailed'))}finally{setBusy(false)}}
  if(status==='pending') return <div className="mt-6 max-w-xl mx-auto"><div className="grid grid-cols-2 gap-3"><button disabled={busy} onClick={()=>respond(true)} className="rounded-2xl bg-[#00E676] text-black py-4 font-black">{t('acceptBtn')}</button><button disabled={busy} onClick={()=>respond(false)} className="rounded-2xl border border-white/10 bg-white/5 py-4 font-bold">{t('rejectBtn')}</button></div>{message&&<p className="text-center text-sm text-white/55 mt-3">{message}</p>}</div>
  if(status==='creator') return <div className="mt-6 text-center"><div className="text-sm text-white/50">{t('creatorNotice')}</div><button disabled={busy} onClick={cancel} className="mt-3 rounded-xl border border-red-400/20 bg-red-500/5 px-4 py-2 text-xs font-black text-red-300">{t('cancelBtn')}</button>{message&&<p className="text-center text-sm text-white/55 mt-3">{message}</p>}</div>
  return <div className="mt-6 text-center text-sm text-white/50">{t('invitationStatus',{status})}</div>
}
