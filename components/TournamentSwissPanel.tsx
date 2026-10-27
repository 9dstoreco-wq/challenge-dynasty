'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'
import { generateNextSwissRound } from '@/lib/tournamentBracketActions'

type Category = { id: string; name: string; currentRound: number }

export default function TournamentSwissPanel({
  tournamentId,
  startsAt,
  categories,
}: {
  tournamentId: string
  startsAt: string | null
  categories: Category[]
}) {
  const t = useTranslations('Competitions')
  const router = useRouter()
  const supabase = createClient()
  const [busyId, setBusyId] = useState<string | null>(null)
  const [messages, setMessages] = useState<Record<string, string>>({})

  if (categories.length === 0) return null

  async function handleGenerate(categoryId: string) {
    setBusyId(categoryId)
    setMessages((m) => ({ ...m, [categoryId]: '' }))
    try {
      const result = await generateNextSwissRound(supabase, { tournamentId, categoryId, startsAt })
      // AVISO AUTOMATICO (pedido de Luis, 2026-10-26): cada vez que sale una ronda nueva del
      // suizo, se avisa a los jugadores de esa ronda. notify_category_fixture_schedule solo
      // avisa los partidos que todavia no se habian avisado, asi que rondas anteriores no se
      // vuelven a notificar.
      let notified = 0
      try {
        const { data: notifyResult } = await supabase.rpc('notify_category_fixture_schedule', { p_category_id: categoryId })
        notified = (notifyResult as { fixtures_notified?: number } | null)?.fixtures_notified ?? 0
      } catch {
        // silencioso: la ronda ya se generó; el aviso es un extra, no debe tumbar el flujo.
      }
      setMessages((m) => ({
        ...m,
        [categoryId]: `${result.isFinal ? t('swissComplete') : t('swissRoundGenerated', { round: result.roundNumber })}${notified > 0 ? ' ' + t('bracketNotified', { count: notified }) : ''}`,
      }))
      router.refresh()
    } catch (err) {
      const code = err instanceof Error ? err.message : ''
      const key =
        code === 'ROUND_NOT_FINISHED'
          ? 'swissRoundNotFinished'
          : code === 'SWISS_COMPLETE'
            ? 'swissComplete'
            : 'swissGenerateFailed'
      setMessages((m) => ({ ...m, [categoryId]: t(key) }))
    } finally {
      setBusyId(null)
    }
  }

  return (
    <section className="mt-7 rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-6 space-y-3">
      <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black">{t('swissPanelTitle')}</div>
      {categories.map((c) => (
        <div key={c.id} className="flex items-center justify-between gap-3 rounded-xl bg-white/[.03] border border-white/10 px-4 py-3">
          <div>
            <div className="font-bold text-sm">{c.name}</div>
            <div className="text-xs text-white/40">{t('swissCurrentRound', { round: c.currentRound })}</div>
            {messages[c.id] && <div className="text-xs text-[#D4AF37] mt-1">{messages[c.id]}</div>}
          </div>
          <button
            onClick={() => handleGenerate(c.id)}
            disabled={busyId === c.id}
            className="rounded-xl bg-[#D4AF37] text-black font-black py-2 px-4 text-xs disabled:opacity-40 whitespace-nowrap"
          >
            {busyId === c.id ? t('generating') : t('swissNextRound')}
          </button>
        </div>
      ))}
    </section>
  )
}
