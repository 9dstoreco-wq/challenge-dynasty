'use client'
import { useState } from 'react'
import { cancelChallenge, respondToChallenge } from '@/app/actions/challenges'
import { useTranslations } from 'next-intl'

const CHALLENGE_STATUSES = ['open', 'scheduled', 'active', 'completed', 'cancelled', 'creator', 'pending', 'accepted', 'declined', 'withdrawn', 'invited', 'none', 'expired']

export default function ChallengeActions({challengeId,status,invitationId}:{challengeId:string;status:string;invitationId?:string}){
  const t=useTranslations('Challenge')
  const statusLabel=(s:string)=>(CHALLENGE_STATUSES.includes(s)?t(`status.${s}` as 'status.open'):s)
  const [busy,setBusy]=useState(false); const [message,setMessage]=useState('')
  async function respond(accept:boolean){
    if(busy) return
    setBusy(true);setMessage('')
    try{
      if(!invitationId){setMessage(t('invitationUnavailable'));setBusy(false);return}
      const res=await respondToChallenge(invitationId,accept)
      if(!res.ok){setMessage(res.error||t('errUpdateFailed'));setBusy(false);return}
      setMessage(accept?t('accepted'):t('rejected'))
      window.location.reload()
    }catch{setMessage(t('errUpdateFailed'));setBusy(false)}
  }
  async function cancel(){
    if(busy) return
    if(!window.confirm(t('cancelConfirm'))) return
    setBusy(true);setMessage('')
    try{
      const res=await cancelChallenge(challengeId)
      if(!res.ok){setMessage(res.error||t('errCancelFailed'));setBusy(false);return}
      setMessage(t('cancelled'))
      window.location.reload()
    }catch{setMessage(t('errCancelFailed'));setBusy(false)}
  }
  if(status==='pending') return <div className="mt-6 max-w-xl mx-auto"><div className="grid grid-cols-2 gap-3"><button disabled={busy} onClick={()=>respond(true)} className="rounded-2xl bg-[#00E676] text-black py-4 font-black">{t('acceptBtn')}</button><button disabled={busy} onClick={()=>respond(false)} className="rounded-2xl border border-white/10 bg-white/5 py-4 font-bold">{t('rejectBtn')}</button></div>{message&&<p className="text-center text-sm text-white/55 mt-3">{message}</p>}</div>
  if(status==='creator') return <div className="mt-6 text-center"><div className="text-sm text-white/50">{t('creatorNotice')}</div><button disabled={busy} onClick={cancel} className="mt-3 rounded-xl border border-red-400/20 bg-red-500/5 px-4 py-2 text-xs font-black text-red-300">{t('cancelBtn')}</button>{message&&<p className="text-center text-sm text-white/55 mt-3">{message}</p>}</div>
  if(status==='locked'||status==='none') return null
  if(status==='cancelled') return <div className="mt-6 text-center text-sm text-white/50">{t('cancelled')}</div>
  return <div className="mt-6 text-center text-sm text-white/50">{t('invitationStatus',{status:statusLabel(status)})}</div>
}
