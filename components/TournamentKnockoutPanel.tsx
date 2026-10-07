'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'
import { generateKnockoutStage } from '@/lib/tournamentBracketActions'

type Category = { id: string; name: string }

export default function TournamentKnockoutPanel({
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
      const result = await generateKnockoutStage(supabase, { tournamentId, categoryId, startsAt })
      setMessages((m) => ({ ...m, [categoryId]: t('knockoutGenerated', { count: result.fixturesCreated }) }))
      router.refresh()
    } catch (err) {
      const code = err instanceof Error ? err.message : ''
      const key =
        code === 'GROUPS_NOT_FINISHED'
          ? 'groupsNotFinished'
          : code === 'NOT_ENOUGH_ENTRIES'
            ? 'notEnoughEntries'
            : 'knockoutGenerateFailed'
      setMessages((m) => ({ ...m, [categoryId]: t(key) }))
    } finally {
      setBusyId(null)
    }
  }

  return (
    <section className="mt-7 rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-6 space-y-3">
      <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black">{t('knockoutPanelTitle')}</div>
      {categories.map((c) => (
        <div key={c.id} className="flex items-center justify-between gap-3 rounded-xl bg-white/[.03] border border-white/10 px-4 py-3">
          <div>
            <div className="font-bold text-sm">{c.name}</div>
            {messages[c.id] && <div className="text-xs text-[#D4AF37] mt-1">{messages[c.id]}</div>}
          </div>
          <button
            onClick={() => handleGenerate(c.id)}
            disabled={busyId === c.id}
            className="rounded-xl bg-[#D4AF37] text-black font-black py-2 px-4 text-xs disabled:opacity-40 whitespace-nowrap"
          >
            {busyId === c.id ? t('generating') : t('generateKnockout')}
          </button>
        </div>
      ))}
    </section>
  )
}
