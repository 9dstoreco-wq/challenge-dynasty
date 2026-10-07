'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'
import { generateBracket } from '@/lib/tournamentBracketActions'

type Category = { id: string; name: string; participant_mode: string }

export default function TournamentBracketPanel({
  tournamentId,
  formatType,
  startsAt,
  categories,
  categoriesWithFixtures,
  confirmedCountByCategory,
}: {
  tournamentId: string
  formatType: string
  startsAt: string | null
  categories: Category[]
  categoriesWithFixtures: Set<string>
  confirmedCountByCategory: Map<string, number>
}) {
  const t = useTranslations('Competitions')
  const router = useRouter()
  const supabase = createClient()
  const [busyId, setBusyId] = useState<string | null>(null)
  const [messages, setMessages] = useState<Record<string, string>>({})

  const supported =
    formatType === 'single_elimination' || formatType === 'round_robin' || formatType === 'groups_then_knockout'
  const pending = categories.filter((c) => !categoriesWithFixtures.has(c.id))
  if (!supported || pending.length === 0) return null

  async function handleGenerate(categoryId: string) {
    setBusyId(categoryId)
    setMessages((m) => ({ ...m, [categoryId]: '' }))
    try {
      const result = await generateBracket(supabase, { tournamentId, categoryId, formatType, startsAt })
      setMessages((m) => ({ ...m, [categoryId]: t('bracketGenerated', { count: result.fixturesCreated }) }))
      router.refresh()
    } catch (err) {
      const code = err instanceof Error ? err.message : ''
      const key =
        code === 'ALREADY_GENERATED'
          ? 'bracketAlreadyGenerated'
          : code === 'NOT_ENOUGH_ENTRIES'
            ? 'notEnoughEntries'
            : 'bracketGenerateFailed'
      setMessages((m) => ({ ...m, [categoryId]: t(key) }))
    } finally {
      setBusyId(null)
    }
  }

  return (
    <section className="mt-7 rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-6 space-y-3">
      <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black">{t('bracketPanelTitle')}</div>
      {pending.map((c) => {
        const confirmed = confirmedCountByCategory.get(c.id) ?? 0
        return (
          <div key={c.id} className="flex items-center justify-between gap-3 rounded-xl bg-white/[.03] border border-white/10 px-4 py-3">
            <div>
              <div className="font-bold text-sm">{c.name}</div>
              <div className="text-xs text-white/40">{t('confirmedEntries', { count: confirmed })}</div>
              {messages[c.id] && <div className="text-xs text-[#D4AF37] mt-1">{messages[c.id]}</div>}
            </div>
            <button
              onClick={() => handleGenerate(c.id)}
              disabled={busyId === c.id || confirmed < 2}
              className="rounded-xl bg-[#D4AF37] text-black font-black py-2 px-4 text-xs disabled:opacity-40 whitespace-nowrap"
            >
              {busyId === c.id ? t('generating') : t('generateBracket')}
            </button>
          </div>
        )
      })}
    </section>
  )
}
