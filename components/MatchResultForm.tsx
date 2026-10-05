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
  sportSlug?: string | null
}

const scorePattern = /^\d{1,2}[-:]\d{1,2}$/
const pointsPattern = /^\d{1,3}[-:]\d{1,3}$/

// Como se registra el marcador segun el deporte: por sets (padel, tenis), un solo marcador
// (futbol, basquet) o solo el ganador (carrera y deportes sin marcador).
type ScoreMode = 'sets' | 'points' | 'winner'
function modeFor(slug?: string | null): ScoreMode {
  if (slug === 'football' || slug === 'basketball') return 'points'
  if (slug === 'padel' || slug === 'tennis' || !slug) return 'sets'
  return 'winner'
}
function parse(score: string): [number, number] | null {
  const m = score.trim().match(/^(\d+)[-:](\d+)$/)
  return m ? [Number(m[1]), Number(m[2])] : null
}

export default function MatchResultForm({ matchId, resultId, creatorId, opponentId, creatorName, opponentName, currentUserId, winnerId, submittedBy, resultStatus, scoreSet1='', scoreSet2='', scoreSet3='', sportSlug }: Props) {
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

  const mode = modeFor(sportSlug)

  function validateForm() {
    if (!winner) return t('selectWinner')
    if (mode === 'winner') return ''
    // El primer numero de cada marcador es del reto-creador y el segundo del rival.
    const side = winner === creatorId ? 0 : 1
    if (mode === 'points') {
      if (!pointsPattern.test(set1.trim())) return t('scoreFormatPoints')
      const [x, y] = parse(set1)!
      if (x === y) return t('drawNotAllowed')
      if ((x > y ? 0 : 1) !== side) return t('winnerMismatch')
      return ''
    }
    if (!scorePattern.test(set1.trim()) || !scorePattern.test(set2.trim())) return t('setsFormat12')
    if (set3.trim() && !scorePattern.test(set3.trim())) return t('set3Format')
    const wins = [0, 0]
    for (const sc of [set1, set2, set3]) { const p = parse(sc); if (p && p[0] !== p[1]) wins[p[0] > p[1] ? 0 : 1] += 1 }
    if (wins[0] === wins[1]) return t('setsNeedWinner')
    if ((wins[0] > wins[1] ? 0 : 1) !== side) return t('winnerMismatch')
    return ''
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    if (busy) return
    const validation = validateForm()
    if (validation) { setError(validation); return }
    setBusy(true); setError('')
    try {
      const res = await submitMatchResult({ matchId, winnerId: winner, scoreSet1: mode === 'winner' ? '' : set1.trim(), scoreSet2: mode === 'sets' ? set2.trim() : '', scoreSet3: mode === 'sets' ? (set3.trim() || null) : null })
      if (!res.ok) { setError(res.error || t('errSaveFailed')); return }
      router.refresh()
    } catch { setError(t('errSaveFailed')) }
    finally { setBusy(false) }
  }

  async function review(approve: boolean) {
    if (busy || submittedByMe || resultStatus !== 'pending' || !resultId) return
    setBusy(true); setError('')
    try {
      const res = await confirmMatch(resultId, approve)
      if (!res.ok) { setError(res.error || t('errConfirmFailed')); return }
      router.refresh()
    } catch { setError(t('errConfirmFailed')) }
    finally { setBusy(false) }
  }

  if (!isParticipant) return null

  if (resultStatus === 'confirmed') return <div className="mt-8 rounded-3xl border border-[#00E676]/20 bg-[#00E676]/10 p-5 text-center"><div className="text-xs tracking-[.25em] text-[#00E676] font-black">{t('officialResult')}</div><div className="text-2xl font-black mt-2">{scoreSet1}{scoreSet2 ? ` · ${scoreSet2}` : ''}{scoreSet3 ? ` · ${scoreSet3}` : ''}</div><div className="text-sm text-white/50 mt-2">{t('resultConfirmed')}</div></div>

  if (isPendingReview) return <section className="mt-8 rounded-3xl border border-yellow-400/20 bg-yellow-400/5 p-5"><div className="text-xs tracking-[.25em] text-yellow-200 font-black">{t('pendingResult')}</div><h2 className="text-2xl font-black mt-2">{t('waitingConfirmation')}</h2><p className="text-sm text-white/50 mt-2">{submittedByMe ? t('otherMustConfirm') : t('reviewRivalResult')}</p><div className="mt-4 text-sm text-white/70">{t('winnerLabel')} <strong>{winner===creatorId ? creatorName : opponentName}</strong> · {scoreSet1}{scoreSet2 ? ` · ${scoreSet2}` : ''}{scoreSet3 ? ` · ${scoreSet3}` : ''}</div>{!submittedByMe && <div className="mt-4 grid gap-3"><button disabled={busy} onClick={()=>review(true)} className="w-full rounded-2xl bg-[#00E676] text-black py-4 font-black">{t('confirmResultBtn')}</button><button disabled={busy} onClick={()=>review(false)} className="w-full rounded-2xl border border-red-400/30 bg-red-500/10 text-red-200 py-3 font-black">{t('disputeBtn')}</button></div>}{error&&<div className="rounded-xl bg-red-500/10 border border-red-400/20 p-3 text-sm text-red-200 mt-3">{error}</div>}</section>

  if (resultStatus === 'disputed' && submittedByMe) return <section className="mt-8 rounded-3xl border border-red-400/20 bg-red-500/5 p-5 text-center"><div className="text-xs tracking-[.25em] text-red-300 font-black">{t('pendingResult')}</div><p className="text-sm text-white/60 mt-3">{t('disputedByRival')}</p></section>

  return <section className="mt-8 rounded-3xl border border-white/10 bg-white/[.03] p-5"><div className="text-xs tracking-[.25em] text-[#D4AF37] font-black">{t('matchResultTag')}</div><h2 className="text-2xl font-black mt-2">{t('playRegisterConfirm')}</h2><p className="text-sm text-white/45 mt-1">{resultStatus === 'disputed' ? t('disputedEnterYours') : t('otherWillReview')}</p><form onSubmit={submit} className="mt-5 space-y-4"><div><label className="text-xs text-white/45">{t('winnerFieldLabel')}</label><div className="grid sm:grid-cols-2 gap-2 mt-2"><button type="button" onClick={()=>setWinner(creatorId)} className={`rounded-xl px-4 py-3 border font-black ${winner===creatorId?'border-[#D4AF37] bg-[#D4AF37]/10':'border-white/10 bg-white/5'}`}>{creatorName ?? t('defaultCreator')}</button><button type="button" onClick={()=>opponentId&&setWinner(opponentId)} disabled={!opponentId} className={`rounded-xl px-4 py-3 border font-black ${winner===opponentId?'border-[#D4AF37] bg-[#D4AF37]/10':'border-white/10 bg-white/5'}`}>{opponentName ?? t('defaultRival')}</button></div></div>{mode === 'sets' && <div className="grid sm:grid-cols-3 gap-3"><input value={set1} onChange={e=>setSet1(e.target.value)} placeholder={t('set1Placeholder')} required className="rounded-xl bg-white/5 border border-white/10 px-4 py-3"/><input value={set2} onChange={e=>setSet2(e.target.value)} placeholder={t('set2Placeholder')} required className="rounded-xl bg-white/5 border border-white/10 px-4 py-3"/><input value={set3} onChange={e=>setSet3(e.target.value)} placeholder={t('set3Placeholder')} className="rounded-xl bg-white/5 border border-white/10 px-4 py-3"/></div>}{mode === 'points' && <div><input value={set1} onChange={e=>setSet1(e.target.value)} placeholder={t('scorePlaceholder')} required className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3"/></div>}{mode === 'winner' && <p className="text-sm text-white/45">{t('noScoreHint')}</p>}{mode !== 'winner' && <p className="text-xs text-white/35">{t('scoreOrderHint',{a:creatorName ?? t('defaultCreator'),b:opponentName ?? t('defaultRival')})}</p>}{error&&<div className="rounded-xl bg-red-500/10 border border-red-400/20 p-3 text-sm text-red-200">{error}</div>}<button disabled={busy||!winner||!opponentId} className="w-full rounded-2xl bg-[#D4AF37] text-black py-4 font-black">{busy?t('saving'):t('saveResultBtn')}</button></form>{resultId && <div className="mt-3 text-center text-xs text-white/30">{t('resultRegistered',{id:resultId})}</div>}</section>
}
