'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { confirmMatch, submitMatchResult } from '@/app/actions/challenges'
import { useTranslations } from 'next-intl'

type Props = {
  challengeId: string
  matchId: string
  resultId?: string | null
  creatorId: string
  opponentId?: string | null
  creatorName?: string
  opponentName?: string
  currentUserId: string
  winnerId?: string | null
  submittedBy?: string | null
  resultStatus?: string | null
  scoreSet1?: string | null
  scoreSet2?: string | null
  scoreSet3?: string | null
}

const scorePattern = /^\d{1,2}[-:]\d{1,2}$/

export default function MatchResultForm({ challengeId, matchId, resultId, creatorId, opponentId, creatorName, opponentName, currentUserId, winnerId, submittedBy, resultStatus, scoreSet1='', scoreSet2='', scoreSet3='' }: Props) {
  const t = useTranslations('Challenge')
  const router = useRouter()
  const [winner, setWinner] = useState(winnerId ?? '')
  const [set1, setSet1] = useState(scoreSet1 ?? '')
  const [set2, setSet2] = useState(scoreSet2 ?? '')
  const [set3, setSet3] = useState(scoreSet3 ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const isParticipant = currentUserId === creatorId || currentUserId === opponentId
  const isPendingReview = resultStatus === 'pending'
  const submittedByMe = submittedBy === currentUserId

  function validateForm() {
    if (!winner) return t('selectWinner')
    if (!scorePattern.test(set1.trim()) || !scorePattern.test(set2.trim())) return t('setsFormat12')
    if (set3.trim() && !scorePattern.test(set3.trim())) return t('set3Format')
    return ''
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    const validation = validateForm()
    if (validation) { setError(validation); return }
    setBusy(true); setError('')
    try {
      await submitMatchResult({ matchId, winnerId: winner, scoreSet1: set1.trim(), scoreSet2: set2.trim(), scoreSet3: set3.trim() || null })
      router.refresh()
    } catch (e) { setError(e instanceof Error ? e.message : t('errSaveFailed')) }
    finally { setBusy(false) }
  }

  async function confirm() {
    if (submittedByMe || resultStatus !== 'pending') return
    setBusy(true); setError('')
    try { await confirmMatch(resultId!, true); router.refresh() }
    catch (e) { setError(e instanceof Error ? e.message : t('errConfirmFailed')) }
    finally { setBusy(false) }
  }

  if (!isParticipant) return null

  if (resultStatus === 'confirmed') return <div className="mt-8 rounded-3xl border border-[#00E676]/20 bg-[#00E676]/10 p-5 text-center"><div className="text-xs tracking-[.25em] text-[#00E676] font-black">{t('officialResult')}</div><div className="text-2xl font-black mt-2">{scoreSet1}{scoreSet2 ? ` · ${scoreSet2}` : ''}{scoreSet3 ? ` · ${scoreSet3}` : ''}</div><div className="text-sm text-white/50 mt-2">{t('resultConfirmed')}</div></div>

  if (isPendingReview) return <section className="mt-8 rounded-3xl border border-yellow-400/20 bg-yellow-400/5 p-5"><div className="text-xs tracking-[.25em] text-yellow-200 font-black">{t('pendingResult')}</div><h2 className="text-2xl font-black mt-2">{t('waitingConfirmation')}</h2><p className="text-sm text-white/50 mt-2">{submittedByMe ? t('otherMustConfirm') : t('reviewRivalResult')}</p><div className="mt-4 text-sm text-white/70">{t('winnerLabel')} <strong>{winner===creatorId ? creatorName : opponentName}</strong> · {scoreSet1}{scoreSet2 ? ` · ${scoreSet2}` : ''}{scoreSet3 ? ` · ${scoreSet3}` : ''}</div>{!submittedByMe && <button disabled={busy} onClick={confirm} className="w-full mt-4 rounded-2xl bg-[#00E676] text-black py-4 font-black">{t('confirmResultBtn')}</button>}{error&&<div className="rounded-xl bg-red-500/10 border border-red-400/20 p-3 text-sm text-red-200 mt-3">{error}</div>}</section>

  return <section className="mt-8 rounded-3xl border border-white/10 bg-white/[.03] p-5"><div className="text-xs tracking-[.25em] text-[#D4AF37] font-black">{t('matchResultTag')}</div><h2 className="text-2xl font-black mt-2">{t('playRegisterConfirm')}</h2><p className="text-sm text-white/45 mt-1">{t('otherWillReview')}</p><form onSubmit={submit} className="mt-5 space-y-4"><div><label className="text-xs text-white/45">{t('winnerFieldLabel')}</label><div className="grid sm:grid-cols-2 gap-2 mt-2"><button type="button" onClick={()=>setWinner(creatorId)} className={`rounded-xl px-4 py-3 border font-black ${winner===creatorId?'border-[#D4AF37] bg-[#D4AF37]/10':'border-white/10 bg-white/5'}`}>{creatorName ?? t('defaultCreator')}</button><button type="button" onClick={()=>opponentId&&setWinner(opponentId)} disabled={!opponentId} className={`rounded-xl px-4 py-3 border font-black ${winner===opponentId?'border-[#D4AF37] bg-[#D4AF37]/10':'border-white/10 bg-white/5'}`}>{opponentName ?? t('defaultRival')}</button></div></div><div className="grid sm:grid-cols-3 gap-3"><input value={set1} onChange={e=>setSet1(e.target.value)} placeholder={t('set1Placeholder')} required className="rounded-xl bg-white/5 border border-white/10 px-4 py-3"/><input value={set2} onChange={e=>setSet2(e.target.value)} placeholder={t('set2Placeholder')} required className="rounded-xl bg-white/5 border border-white/10 px-4 py-3"/><input value={set3} onChange={e=>setSet3(e.target.value)} placeholder={t('set3Placeholder')} className="rounded-xl bg-white/5 border border-white/10 px-4 py-3"/></div>{error&&<div className="rounded-xl bg-red-500/10 border border-red-400/20 p-3 text-sm text-red-200">{error}</div>}<button disabled={busy||!winner||!opponentId} className="w-full rounded-2xl bg-[#D4AF37] text-black py-4 font-black">{busy?t('saving'):t('saveResultBtn')}</button></form>{resultId && <div className="mt-3 text-center text-xs text-white/30">{t('resultRegistered',{id:resultId})}</div>}</section>
}
