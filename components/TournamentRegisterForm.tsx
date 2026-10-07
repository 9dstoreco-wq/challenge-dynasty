'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'

type Category = { id: string; participant_mode: string; status: string }
type Player = { id: string; username: string | null; display_name: string | null }

export default function TournamentRegisterForm({ category, players, currentUserId }: { category: Category; players: Player[]; currentUserId: string }) {
  const t = useTranslations('Competitions')
  const router = useRouter()
  const supabase = createClient()

  const [partnerId, setPartnerId] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [done, setDone] = useState(false)

  if (category.status !== 'open') {
    return <div className="mt-4 text-xs text-white/35">{t('categoryClosed')}</div>
  }

  if (category.participant_mode === 'team') {
    return <div className="mt-4 text-xs text-white/35">{t('teamComingSoon')}</div>
  }

  async function register() {
    setBusy(true); setError(null)
    const memberIds = category.participant_mode === 'pair' && partnerId ? [currentUserId, partnerId] : [currentUserId]
    const { error: rpcError } = await supabase.rpc('register_tournament_entry', { p_category_id: category.id, p_member_profile_ids: memberIds })
    setBusy(false)
    if (rpcError) { setError(toSafeMessage(rpcError, 'tournament.register', t('registerFailed'))); return }
    setDone(true)
    router.refresh()
  }

  if (done) return <div className="mt-4 text-xs font-black text-[#D4AF37]">{t('registerSuccess')}</div>

  return (
    <div className="mt-4 space-y-2">
      {category.participant_mode === 'pair' && (
        <select value={partnerId} onChange={(e) => setPartnerId(e.target.value)} className="w-full rounded-xl bg-white/5 border border-white/10 px-3 py-2 text-sm text-white outline-none focus:border-[#D4AF37]/50">
          <option value="">{t('selectPartner')}</option>
          {players.map((p) => <option key={p.id} value={p.id}>{p.display_name || p.username}</option>)}
        </select>
      )}
      {error && <div className="text-xs text-red-400">{error}</div>}
      <button
        onClick={register}
        disabled={busy || (category.participant_mode === 'pair' && !partnerId)}
        className="w-full rounded-xl bg-[#D4AF37] text-black font-black py-2.5 text-sm disabled:opacity-50"
      >
        {busy ? t('submitting') : t('registerCta')}
      </button>
      {category.participant_mode === 'pair' && <div className="text-[10px] text-white/30">{t('partnerMustAccept')}</div>}
    </div>
  )
}
