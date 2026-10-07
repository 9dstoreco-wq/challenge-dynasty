'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'
import { recordFixtureResult } from '@/lib/tournamentBracketActions'

export default function TournamentResultForm({
  fixtureId,
  entryAId,
  entryBId,
  labelA,
  labelB,
}: {
  fixtureId: string
  entryAId: string | null
  entryBId: string | null
  labelA: string
  labelB: string
}) {
  const t = useTranslations('Competitions')
  const router = useRouter()
  const supabase = createClient()

  const [winner, setWinner] = useState('')
  const [scoreA, setScoreA] = useState('')
  const [scoreB, setScoreB] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  if (!entryAId || !entryBId) return null // falta un rival (TBD), todavía no se puede jugar

  async function submit() {
    if (!winner) { setError(t('selectWinner')); return }
    setBusy(true); setError(null)
    try {
      await recordFixtureResult(supabase, {
        fixtureId,
        winnerEntryId: winner,
        scoreA: scoreA ? Number(scoreA) : null,
        scoreB: scoreB ? Number(scoreB) : null,
      })
      router.refresh()
    } catch {
      setError(t('resultFailed'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="mt-2 flex flex-wrap items-center gap-2 text-xs">
      <input
        type="number"
        value={scoreA}
        onChange={(e) => setScoreA(e.target.value)}
        placeholder={t('scoreA')}
        className="w-16 rounded-lg bg-white/5 border border-white/10 px-2 py-1 text-white outline-none focus:border-[#D4AF37]/50"
      />
      <input
        type="number"
        value={scoreB}
        onChange={(e) => setScoreB(e.target.value)}
        placeholder={t('scoreB')}
        className="w-16 rounded-lg bg-white/5 border border-white/10 px-2 py-1 text-white outline-none focus:border-[#D4AF37]/50"
      />
      <select
        value={winner}
        onChange={(e) => setWinner(e.target.value)}
        className="rounded-lg bg-white/5 border border-white/10 px-2 py-1 text-white outline-none focus:border-[#D4AF37]/50"
      >
        <option value="">{t('selectWinner')}</option>
        <option value={entryAId}>{labelA}</option>
        <option value={entryBId}>{labelB}</option>
      </select>
      <button
        onClick={submit}
        disabled={busy}
        className="rounded-lg bg-[#D4AF37] text-black font-black py-1 px-3 disabled:opacity-50"
      >
        {busy ? t('submitting') : t('recordResult')}
      </button>
      {error && <div className="text-red-400 w-full">{error}</div>}
    </div>
  )
}
