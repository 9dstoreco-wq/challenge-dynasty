'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { Swords } from 'lucide-react'
import DynastyCard from '@/components/DynastyCard'
import { stakeCard, withdrawCardStake } from '@/app/actions/cards'
import type { DynastyCardView } from '@/lib/dynasty/cards'

// Panel "Carta en juego" del reto: cada jugador puede poner una carta suya; la apuesta solo
// vale si AMBOS ponen una. Quien gana el reto confirmado se queda con la carta del rival.
export default function CardStakePanel({
  challengeId,
  mine,
  theirs,
  eligible,
  canEdit,
  settled,
}: {
  challengeId: string
  mine: DynastyCardView | null
  theirs: DynastyCardView | null
  eligible: DynastyCardView[]
  canEdit: boolean
  settled: boolean
}) {
  const t = useTranslations('Cards')
  const router = useRouter()
  const [pick, setPick] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const bothIn = Boolean(mine && theirs)

  async function run(fn: () => Promise<{ ok: boolean; error?: string }>) {
    if (busy) return
    setBusy(true)
    setError('')
    try {
      const res = await fn()
      if (!res.ok) { setError(res.error || t('stake.errorGeneric')); return }
      setPick(null)
      router.refresh()
    } catch {
      setError(t('stake.errorGeneric'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="hud-corners card-fut-plain relative mt-8 border border-[#D4AF37]/25 bg-gradient-to-br from-[#1E1C10] to-[#0C0C0F] p-5 md:p-6">
      <div className="text-xs font-black tracking-[.3em] text-[#D4AF37]">{t('stake.kicker')}</div>
      <h2 className="mt-1 font-display text-3xl tracking-wide">{t('stake.title')}</h2>
      <p className="mt-1 text-sm text-white/55">{t('stake.intro')}</p>

      <div className="mt-5 grid grid-cols-[1fr_auto_1fr] items-center gap-3">
        <div className="flex flex-col items-center gap-2">
          <div className="text-[10px] font-bold uppercase tracking-widest text-white/45">{t('stake.mine')}</div>
          {mine ? <DynastyCard card={mine} /> : <div className="grid aspect-[2/3] w-full max-w-[260px] place-items-center border border-dashed border-white/15 text-center text-xs text-white/35">{t('stake.empty')}</div>}
        </div>
        <div className="vs-bolt font-display text-4xl">VS</div>
        <div className="flex flex-col items-center gap-2">
          <div className="text-[10px] font-bold uppercase tracking-widest text-white/45">{t('stake.theirs')}</div>
          {theirs ? <DynastyCard card={theirs} /> : <div className="grid aspect-[2/3] w-full max-w-[260px] place-items-center border border-dashed border-white/15 p-3 text-center text-xs text-white/35">{t('stake.waiting')}</div>}
        </div>
      </div>

      <div className="mt-4 text-center text-sm font-bold">
        {settled ? <span className="text-[#00E676]">{t('stake.settled')}</span> : bothIn ? <span className="text-[#00E676]"><Swords className="mr-1 inline" size={14} />{t('stake.locked')}</span> : <span className="text-white/45">{t('stake.needBoth')}</span>}
      </div>

      {canEdit && !bothIn && !settled && (
        <div className="mt-5 border-t border-white/10 pt-5">
          {eligible.length === 0 ? (
            <p className="text-center text-sm text-white/45">{t('stake.noCards')}</p>
          ) : (
            <>
              <div className="mb-3 text-xs font-bold uppercase tracking-widest text-white/45">{t('stake.pick')}</div>
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
                {eligible.map((c) => <DynastyCard key={c.id} card={c} selected={pick === c.id} onClick={() => setPick(c.id)} />)}
              </div>
              <button
                type="button"
                disabled={busy || !pick}
                onClick={() => pick && run(() => stakeCard(challengeId, pick))}
                className="btn-gold mt-5 w-full py-3 disabled:opacity-50"
              >
                {busy ? t('stake.saving') : t('stake.place')}
              </button>
            </>
          )}
          {mine && (
            <button type="button" disabled={busy} onClick={() => run(() => withdrawCardStake(challengeId))} className="btn-ghost mt-3 w-full py-2.5 text-sm disabled:opacity-50">
              {t('stake.withdraw')}
            </button>
          )}
        </div>
      )}
      {error && <p className="mt-3 text-center text-sm text-red-300">{error}</p>}
    </section>
  )
}
