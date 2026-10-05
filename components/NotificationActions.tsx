'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { markAllNotificationsRead, markNotificationRead } from '@/app/actions/social'
import { useTranslations } from 'next-intl'

type Item = { id: string; read_at?: string | null; type: string; body?: string | null; title?: string | null; created_at: string; href?: string | null }

function icon(type: string) {
  const k = type.toLowerCase()
  if (k.includes('card')) return '🃏'
  if (k.includes('challenge_invitation') || k === 'challenge_received') return '⚔️'
  if (k.includes('result') || k.includes('match')) return '🏆'
  if (k.includes('partner')) return '👥'
  if (k.includes('challenge')) return '✅'
  return '🔔'
}

export default function NotificationActions({ item, all }: { item?: Item; all?: boolean }) {
  const t = useTranslations('Notifications')
  const router = useRouter()
  const [read, setRead] = useState(item ? Boolean(item.read_at) : false)

  if (all) {
    return <button onClick={async () => { try { await markAllNotificationsRead() } catch {} window.location.reload() }} className="rounded-xl border border-white/10 px-3 py-2 text-xs font-black">{t('markAllRead')}</button>
  }
  if (!item) return null

  async function open() {
    if (!item) return
    if (!read) { try { await markNotificationRead(item.id); setRead(true) } catch {} }
    if (item.href) router.push(item.href)
  }

  const heading = item.title || item.body || t('defaultTitle')
  const sub = item.title && item.body ? item.body : null
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
