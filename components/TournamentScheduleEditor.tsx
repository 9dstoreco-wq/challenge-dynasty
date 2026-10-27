'use client'
// FEATURE PEDIDA POR LUIS (2026-10-26): "hay jugadores que juegan dos categorías (mixto, quinta,
// sexta...), que no les den partidos a la misma hora, y que el organizador pueda cuadrar las
// horas él mismo". El generador automático de cuadros le pone una hora de relleno a cada
// categoría por separado, sin saber si un jugador ya tiene otro partido a esa hora en OTRA
// categoría. Este panel junta TODOS los partidos del torneo (todas las categorías) en una sola
// lista, usa la función que ya existía en la base de datos (validate_tournament_schedule, la
// misma que usa /competitions/organize) para marcar en rojo los que chocan con el horario de otro
// partido del MISMO jugador, y deja que el organizador le cambie la hora a cada partido puntual.
// El botón "Avisar a los jugadores" se bloquea mientras queden choques sin resolver, para no
// mandarle a alguien una hora que se va a tener que corregir al rato.
import { useEffect, useMemo, useState } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'

type Row = {
  id: string
  categoryId: string
  categoryName: string
  round: number | null
  labelA: string
  labelB: string
  scheduledAt: string | null
  status: string
}

type ScheduleIssue = {
  severity: 'CRITICAL' | 'OK'
  issue_type: string | null
  fixture_a_id: string
  fixture_b_id: string
  start_gap_minutes: number
  blocks_publication: boolean
}

function toLocalInputValue(iso: string | null): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

export default function TournamentScheduleEditor({ tournamentId, categoryIds, rows }: { tournamentId: string; categoryIds: string[]; rows: Row[] }) {
  const t = useTranslations('Competitions')
  const router = useRouter()
  const supabase = createClient()
  const [drafts, setDrafts] = useState<Record<string, string>>({})
  const [savingId, setSavingId] = useState<string | null>(null)
  const [rowMessages, setRowMessages] = useState<Record<string, string>>({})
  const [issues, setIssues] = useState<ScheduleIssue[]>([])
  const [loadingIssues, setLoadingIssues] = useState(false)
  const [notifying, setNotifying] = useState(false)
  const [notifyMessage, setNotifyMessage] = useState('')

  const scheduled = rows.filter((r) => r.scheduledAt && r.status !== 'cancelled')

  async function loadIssues() {
    if (scheduled.length === 0) return
    setLoadingIssues(true)
    try {
      const { data, error } = await supabase.rpc('validate_tournament_schedule', {
        p_tournament_id: tournamentId,
        p_slot_minutes: 60,
        p_required_rest_slots: 1,
      })
      if (!error) setIssues(((data as { issues?: ScheduleIssue[] } | null)?.issues ?? []) as ScheduleIssue[])
    } finally {
      setLoadingIssues(false)
    }
  }

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { loadIssues() }, [])

  const conflictsByFixtureId = useMemo(() => {
    const map = new Map<string, ScheduleIssue[]>()
    for (const issue of issues) {
      if (issue.severity !== 'CRITICAL') continue
      for (const fid of [issue.fixture_a_id, issue.fixture_b_id]) {
        const list = map.get(fid) ?? []
        list.push(issue)
        map.set(fid, list)
      }
    }
    return map
  }, [issues])

  const hasBlockingConflicts = issues.some((i) => i.blocks_publication)

  function describeConflict(row: Row, conflicts: ScheduleIssue[]): string {
    const other = conflicts[0]
    const otherFixtureId = other.fixture_a_id === row.id ? other.fixture_b_id : other.fixture_a_id
    const otherRow = rows.find((r) => r.id === otherFixtureId)
    const otherLabel = otherRow ? `${otherRow.categoryName} · ${t('round', { round: otherRow.round ?? '—' })}` : ''
    return t('scheduleConflictWith', { other: otherLabel, minutes: Math.round(other.start_gap_minutes) })
  }

  async function handleSave(row: Row) {
    const value = drafts[row.id] ?? toLocalInputValue(row.scheduledAt)
    if (!value) return
    setSavingId(row.id)
    setRowMessages((m) => ({ ...m, [row.id]: '' }))
    try {
      const iso = new Date(value).toISOString()
      const { error } = await supabase.rpc('reschedule_tournament_fixture', { p_fixture_id: row.id, p_scheduled_at: iso })
      if (error) throw error
      setRowMessages((m) => ({ ...m, [row.id]: t('scheduleSaved') }))
      await loadIssues()
      router.refresh()
    } catch (err) {
      setRowMessages((m) => ({ ...m, [row.id]: toSafeMessage(err, 'TournamentScheduleEditor.reschedule') }))
    } finally {
      setSavingId(null)
    }
  }

  async function handleNotifyAll() {
    setNotifying(true)
    setNotifyMessage('')
    try {
      let total = 0
      for (const categoryId of categoryIds) {
        const { data, error } = await supabase.rpc('notify_category_fixture_schedule', { p_category_id: categoryId })
        if (error) throw error
        total += (data as { fixtures_notified?: number } | null)?.fixtures_notified ?? 0
      }
      setNotifyMessage(total > 0 ? t('bracketNotified', { count: total }) : t('scheduleNothingToNotify'))
    } catch (err) {
      setNotifyMessage(toSafeMessage(err, 'TournamentScheduleEditor.notifyAll'))
    } finally {
      setNotifying(false)
    }
  }

  if (rows.length === 0) return null

  return (
    <section className="mt-7 rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-6 space-y-3">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div>
          <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black">{t('schedulePanelTitle')}</div>
          <p className="text-white/50 text-sm mt-1 max-w-xl">{t('schedulePanelHint')}</p>
        </div>
        <div className="flex flex-col items-end gap-1">
          <button
            onClick={handleNotifyAll}
            disabled={notifying || hasBlockingConflicts || loadingIssues}
            title={hasBlockingConflicts ? t('scheduleResolveConflictsFirst') : undefined}
            className="rounded-xl bg-[#D4AF37] text-black font-black py-2.5 px-5 text-sm disabled:opacity-40 whitespace-nowrap"
          >
            {notifying ? t('submitting') : t('scheduleNotifyAll')}
          </button>
          {hasBlockingConflicts && <div className="text-xs text-red-400">{t('scheduleResolveConflictsFirst')}</div>}
          {notifyMessage && <div className="text-xs text-[#D4AF37]">{notifyMessage}</div>}
        </div>
      </div>

      <div className="space-y-2">
        {rows.map((row) => {
          const conflicts = conflictsByFixtureId.get(row.id) ?? []
          return (
            <div
              key={row.id}
              className={`rounded-xl border px-4 py-3 grid md:grid-cols-[1fr_1fr_220px_100px] gap-3 items-center ${
                conflicts.length > 0 ? 'border-red-500/50 bg-red-500/[.06]' : 'border-white/10 bg-white/[.03]'
              }`}
            >
              <div>
                <div className="text-xs text-white/40">{row.categoryName} · {t('round', { round: row.round ?? '—' })}</div>
                <div className="text-sm font-bold">{row.labelA} vs {row.labelB}</div>
                {conflicts.length > 0 && <div className="text-xs text-red-400 mt-1">⚠ {describeConflict(row, conflicts)}</div>}
                {rowMessages[row.id] && <div className="text-xs text-[#D4AF37] mt-1">{rowMessages[row.id]}</div>}
              </div>
              <div />
              <input
                type="datetime-local"
                value={drafts[row.id] ?? toLocalInputValue(row.scheduledAt)}
                onChange={(e) => setDrafts((d) => ({ ...d, [row.id]: e.target.value }))}
                disabled={row.status === 'completed' || row.status === 'cancelled'}
                className="bg-[#0A0A0C] border border-white/10 rounded-xl p-2 text-sm disabled:opacity-40"
              />
              <button
                onClick={() => handleSave(row)}
                disabled={savingId === row.id || row.status === 'completed' || row.status === 'cancelled'}
                className="rounded-xl border border-[#D4AF37]/40 text-[#D4AF37] font-bold py-2 px-3 text-xs disabled:opacity-40 whitespace-nowrap"
              >
                {savingId === row.id ? t('submitting') : t('scheduleSave')}
              </button>
            </div>
          )
        })}
      </div>
    </section>
  )
}
