'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'
import { recordRotationMatchResult } from '@/lib/tournamentBracketActions'

// A diferencia de TournamentResultForm (eliminación/grupos/escalera), acá no se elige un
// "ganador" — en Americano cada jugador suma el puntaje de SU lado, gane o pierda, así que solo
// hace falta el marcador de cada lado.
export default function TournamentRotationResultForm({ matchId }: { matchId: string }) {
  const t = useTranslations('Competitions')
  const router = useRouter()
  const supabase = createClient()

  const [scoreA, setScoreA] = useState('')
  const [scoreB, setScoreB] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit() {
    if (scoreA === '' || scoreB === '') { setError(t('rotationScoresRequired')); return }
    setBusy(true); setError(null)
    try {
      await recordRotationMatchResult(supabase, { matchId, scoreA: Number(scoreA), scoreB: Number(scoreB) })
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
        min={0}
        value={scoreA}
        onChange={(e) => setScoreA(e.target.value)}
        placeholder={t('scoreA')}
        className="w-16 rounded-lg bg-white/5 border border-white/10 px-2 py-1 text-white outline-none focus:border-[#D4AF37]/50"
      />
      <span className="text-white/30">—</span>
      <input
        type="number"
        min={0}
        value={scoreB}
        onChange={(e) => setScoreB(e.target.value)}
        placeholder={t('scoreB')}
        className="w-16 rounded-lg bg-white/5 border border-white/10 px-2 py-1 text-white outline-none focus:border-[#D4AF37]/50"
      />
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
