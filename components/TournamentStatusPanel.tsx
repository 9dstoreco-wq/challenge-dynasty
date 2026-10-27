'use client'
// BUG ENCONTRADO EN PRUEBAS QA (2026-10-26): un torneo creado desde /competitions/organize
// se quedaba para siempre en status='draft' -- ninguna pantalla llamaba nunca a la funcion
// transition_tournament_status(...) que ya existe y funciona bien en la base de datos. Como
// register_tournament_entry exige status in ('published','registration_open') para aceptar
// inscripciones, ningun jugador podia inscribirse jamas a un torneo creado por la app, aunque la
// categoria si mostrara cupos abiertos. Este panel es el control que le faltaba al organizador.
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'

type TournamentStatus = 'draft' | 'published' | 'registration_open' | 'registration_closed' | 'in_progress' | 'completed' | 'cancelled'

const NEXT_STATUS: Partial<Record<TournamentStatus, TournamentStatus>> = {
  draft: 'published',
  published: 'registration_open',
  registration_open: 'registration_closed',
  registration_closed: 'in_progress',
  in_progress: 'completed',
}

const ADVANCE_LABEL_KEY: Record<string, string> = {
  published: 'advanceToPublished',
  registration_open: 'advanceToRegistrationOpen',
  registration_closed: 'advanceToRegistrationClosed',
  in_progress: 'advanceToInProgress',
  completed: 'advanceToCompleted',
}

const HINT_KEY: Record<TournamentStatus, string> = {
  draft: 'statusDraftHint',
  published: 'statusPublishedHint',
  registration_open: 'statusRegistrationOpenHint',
  registration_closed: 'statusRegistrationClosedHint',
  in_progress: 'statusInProgressHint',
  completed: 'statusCompletedHint',
  cancelled: 'statusCancelledHint',
}

const CANCELLABLE_FROM: TournamentStatus[] = ['draft', 'published', 'registration_open', 'registration_closed', 'in_progress']

export default function TournamentStatusPanel({ tournamentId, status }: { tournamentId: string; status: TournamentStatus }) {
  const t = useTranslations('Competitions')
  const router = useRouter()
  const supabase = createClient()
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const next = NEXT_STATUS[status]

  async function transition(newStatus: string) {
    setBusy(true)
    setError(null)
    const { error: rpcError } = await supabase.rpc('transition_tournament_status', {
      p_tournament_id: tournamentId,
      p_new_status: newStatus,
    })
    setBusy(false)
    if (rpcError) {
      setError(toSafeMessage(rpcError, 'TournamentStatusPanel.transition', 'No se pudo cambiar el estado del torneo. Intenta de nuevo.'))
      return
    }
    router.refresh()
  }

  async function handleCancel() {
    if (!window.confirm(t('cancelTournamentConfirm'))) return
    await transition('cancelled')
  }

  return (
    <section className="mt-7 rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-6 space-y-3">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div>
          <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black">{t('statusPanelTitle')}</div>
          <p className="text-white/50 text-sm mt-1 max-w-xl">{t(HINT_KEY[status] as 'statusDraftHint')}</p>
        </div>
        <div className="flex items-center gap-2">
          {next && (
            <button
              onClick={() => transition(next)}
              disabled={busy}
              className="rounded-xl bg-[#D4AF37] text-black font-black py-2.5 px-5 text-sm disabled:opacity-50 whitespace-nowrap"
            >
              {busy ? t('submitting') : t(ADVANCE_LABEL_KEY[next] as 'advanceToPublished')}
            </button>
          )}
          {CANCELLABLE_FROM.includes(status) && (
            <button
              onClick={handleCancel}
              disabled={busy}
              className="rounded-xl border border-red-500/40 text-red-400 font-bold py-2.5 px-4 text-xs disabled:opacity-50 whitespace-nowrap"
            >
              {t('cancelTournamentCta')}
            </button>
          )}
        </div>
      </div>
      {error && <div className="text-xs text-red-400">{error}</div>}
    </section>
  )
}
