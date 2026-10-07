'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { markAllNotificationsRead, markNotificationRead } from '@/app/actions/social'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'
import { useTranslations } from 'next-intl'

type Item = { id: string; read_at?: string | null; type: string; body?: string | null; title?: string | null; created_at: string; href?: string | null; sourceType?: string | null; sourceId?: string | null }

function icon(type: string) {
  const k = type.toLowerCase()
  if (k.includes('card')) return '🃏'
  if (k.includes('challenge_invitation') || k === 'challenge_received') return '⚔️'
  if (k.includes('tournament')) return '🏆'
  if (k.includes('result') || k.includes('match')) return '🏆'
  if (k.includes('partner')) return '👥'
  if (k.includes('challenge')) return '✅'
  return '🔔'
}

export default function NotificationActions({ item, all }: { item?: Item; all?: boolean }) {
  const t = useTranslations('Notifications')
  const router = useRouter()
  const supabase = createClient()
  const [read, setRead] = useState(item ? Boolean(item.read_at) : false)
  const [responding, setResponding] = useState(false)
  const [responded, setResponded] = useState<'confirmed' | 'rejected' | null>(null)
  const [error, setError] = useState<string | null>(null)

  if (all) {
    return <button onClick={async () => { try { await markAllNotificationsRead() } catch {} window.location.reload() }} className="rounded-xl border border-white/10 px-3 py-2 text-xs font-black">{t('markAllRead')}</button>
  }
  if (!item) return null

  async function open() {
    if (!item) return
    if (!read) { try { const r = await markNotificationRead(item.id); if (r.ok) setRead(true) } catch {} }
    if (item.href) router.push(item.href)
  }

  async function respond(accept: boolean) {
    if (!item?.sourceId) return
    setResponding(true); setError(null)
    try {
      const { error: rpcError } = await supabase.rpc('respond_tournament_entry_invite', { p_entry_id: item.sourceId, p_accept: accept })
      if (rpcError) throw rpcError
      setResponded(accept ? 'confirmed' : 'rejected')
      if (!read) { try { await markNotificationRead(item.id); setRead(true) } catch {} }
      router.refresh()
    } catch (e) {
      setError(toSafeMessage(e, 'tournament.respond_invite', t('inviteActionFailed')))
    } finally {
      setResponding(false)
    }
  }

  const heading = item.title || item.body || t('defaultTitle')
  const sub = item.title && item.body ? item.body : null
  const isInvite = item.type === 'tournament_entry_invite_received' && item.sourceType === 'tournament_entry' && Boolean(item.sourceId)

  if (isInvite) {
    return (
      <div className={`w-full rounded-2xl border ${read ? 'border-white/10' : 'border-gold-400/20'} bg-[#161616] p-4`}>
        <div className="flex items-center gap-4">
          <div className="text-xl">{icon(item.type)}</div>
          <div className="flex-1">
            <div className="font-bold">{heading}</div>
            {sub && <div className="text-sm text-white/55 mt-0.5">{sub}</div>}
            <div className="text-xs text-white/35 mt-1">{new Date(item.created_at).toLocaleString('es-CO')}</div>
          </div>
        </div>
        {responded ? (
          <div className="mt-3 text-xs font-black text-[#D4AF37]">{responded === 'confirmed' ? t('inviteAccepted') : t('inviteRejected')}</div>
        ) : (
          <div className="mt-3 flex gap-2">
            <button disabled={responding} onClick={() => respond(true)} className="rounded-xl bg-[#D4AF37] text-black px-4 py-2 text-xs font-black disabled:opacity-50">{t('inviteAccept')}</button>
            <button disabled={responding} onClick={() => respond(false)} className="rounded-xl border border-white/15 px-4 py-2 text-xs font-black disabled:opacity-50">{t('inviteReject')}</button>
          </div>
        )}
        {error && <div className="mt-2 text-xs text-red-400">{error}</div>}
      </div>
    )
  }

  return (
    <button onClick={open} className={`w-full text-left rounded-2xl border ${read ? 'border-white/10' : 'border-gold-400/20'} bg-[#161616] p-4 flex items-center gap-4`}>
      <div className="text-xl">{icon(item.type)}</div>
      <div className="flex-1">
        <div className="font-bold">{heading}</div>
        {sub && <div className="text-sm text-white/55 mt-0.5">{sub}</div>}
        <div className="text-xs text-white/35 mt-1">{new Date(item.created_at).toLocaleString('es-CO')}</div>
      </div>
      {item.href && <span className="text-xs text-[#D4AF37]">→</span>}
      <span className={`text-[10px] font-black ${read ? 'text-white/25' : 'text-[#D4AF37]'}`}>{read ? t('read') : t('new')}</span>
    </button>
  )
}
