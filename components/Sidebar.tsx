'use client'
import { useEffect, useState } from 'react'
import Link from 'next/link'
import { useTranslations } from 'next-intl'
import { Home, Swords, Trophy, Radio, Users, Building2, Medal, Bell, UserRound, Zap, Sparkles, Store, ShoppingBag, GraduationCap, Megaphone, CreditCard, CalendarDays, WalletCards, Bot, LayoutGrid, History, ShieldCheck } from 'lucide-react'
import LocaleSwitcher from './LocaleSwitcher'

const groups = [
  { group: 'jugar', items: [['inicio', Home, '/'], ['retos', Swords, '/challenge/new'], ['deportes', LayoutGrid, '/sports'], ['trucos', Sparkles, '/tricks'], ['ranking', Trophy, '/ranking'], ['historial', History, '/history'], ['arena', Radio, '/arena']] },
  { group: 'comunidad', items: [['jugadores', Users, '/players'], ['partners', Users, '/partners'], ['notificaciones', Bell, '/notifications']] },
  { group: 'dynastyAi', items: [['dynastyAi', Bot, '/intelligence']] },
  { group: 'negocio', items: [['clubes', Building2, '/clubs'], ['coaches', GraduationCap, '/coaches'], ['miCoachOs', GraduationCap, '/coaches/dashboard'], ['competiciones', Medal, '/competitions'], ['reservas', CalendarDays, '/bookings'], ['promote', Megaphone, '/promote'], ['planes', CreditCard, '/business'], ['finanzas', WalletCards, '/finance']] },
  { group: 'comercio', items: [['marketplace', ShoppingBag, '/marketplace'], ['dynastyShop', Store, '/shop'], ['miTienda', Store, '/shop/admin']] },
  { group: 'cuenta', items: [['miPerfil', UserRound, '/settings']] },
] as const

export default function Sidebar() {
  const t = useTranslations('Sidebar')
  const [isMaster, setIsMaster] = useState(false)
  useEffect(() => {
    let cancelled = false
    fetch('/api/master/status')
      .then((res) => (res.ok ? res.json() : { isAdmin: false }))
      .then((data) => { if (!cancelled) setIsMaster(Boolean(data?.isAdmin)) })
      .catch(() => {})
    return () => { cancelled = true }
  }, [])
  return (
    <aside className="hidden lg:flex fixed left-0 top-0 bottom-0 w-64 border-r border-white/10 bg-[#0A0A0C]/95 p-5 flex-col z-40">
      <div className="flex items-center justify-between mb-8">
        <div className="flex items-center gap-3">
          <img src="/dynasty-badge.png" alt="Challenge Dynasty" className="w-11 h-11 object-contain glow" />
          <div className="font-display text-2xl leading-none tracking-wide">CHALLENGE<span className="text-[#D4AF37]"> DYNASTY</span></div>
        </div>
      </div>
      <div className="mb-4"><LocaleSwitcher /></div>
      <Link href="/challenge/new" className="w-full rounded-2xl bg-[#D4AF37] text-black font-extrabold py-3 flex items-center justify-center gap-2 mb-6 glow"><Zap size={18} /> {t('retar')}</Link>
      <nav className="space-y-4 overflow-y-auto">
        {groups.map(({ group, items }) => (
          <div key={group}>
            <div className="px-3 mb-1 text-[10px] font-bold uppercase tracking-wider text-white/35">{t(`groups.${group}`)}</div>
            <div className="space-y-1">
              {items.map(([itemKey, Icon, href]) => (
                <Link key={itemKey} href={href} className="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm text-white/70 hover:bg-white/5 hover:text-white"><Icon size={18} />{t(`items.${itemKey}`)}</Link>
              ))}
            </div>
          </div>
        ))}
        {isMaster ? (
          <div>
            <div className="px-3 mb-1 text-[10px] font-bold uppercase tracking-wider text-white/35">{t('groups.plataforma')}</div>
            <div className="space-y-1">
              <Link href="/master" className="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm text-[#D4AF37] hover:bg-white/5"><ShieldCheck size={18} />{t('items.master')}</Link>
            </div>
          </div>
        ) : null}
      </nav>
      <div className="mt-auto rounded-2xl bg-[#161616] p-4">
        <div className="text-xs text-white/50">{t('profileCard.kicker')}</div>
        <div className="font-bold mt-1">{t('profileCard.title')}</div>
        <div className="text-[#D4AF37] font-black mt-2">{t('profileCard.badge')}</div>
      </div>
    </aside>
  )
}
