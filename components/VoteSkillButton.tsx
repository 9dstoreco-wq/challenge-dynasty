'use client'
import { useState } from 'react'
import { voteSkillSubmission } from '@/app/actions/skills'
import { useTranslations } from 'next-intl'

export default function VoteSkillButton({ submissionId }: { submissionId: string }) {
  const t = useTranslations('Tricks')
  const [busy, setBusy] = useState(false)
  const [done, setDone] = useState(false)
  const [err, setErr] = useState('')
  async function vote() {
    if (busy || done) return
    setBusy(true); setErr('')
    try {
      const r = await voteSkillSubmission(submissionId, 5)
      if (!r.ok) { setErr(r.error); return }
      setDone(true)
    } catch { setErr(t('errVoteFailed')) } finally { setBusy(false) }
  }
  return <span className="inline-flex flex-col items-start"><button disabled={busy || done} onClick={vote} className="rounded-xl bg-[#D4AF37] text-black px-4 py-2 text-xs font-black">{done ? t('voted') : t('vote5')}</button>{err && <span className="mt-1 text-xs text-red-300">{err}</span>}</span>
}
