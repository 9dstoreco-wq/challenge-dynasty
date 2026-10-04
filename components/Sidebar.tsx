'use client'
import { useEffect, useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { Home, Swords, Trophy, Radio, Users, Building2, Medal, Bell, UserRound, Zap, Sparkles, ShoppingBag, GraduationCap, Megaphone, CreditCard, CalendarDays, WalletCards, LayoutGrid, History, ShieldCheck, Layers } from 'lucide-react'
import LocaleSwitcher from './LocaleSwitcher'

const groups = [
  { group: 'jugar', items: [['inicio', Home, '/'], ['retos', Swords, '/challenge/new'], ['deportes', LayoutGrid, '/sports'], ['trucos', Sparkles, '/tricks'], ['ranking', Trophy, '/ranking'], ['cartas', Layers, '/cards'], ['historial', History, '/history'], ['arena', Radio, '/arena']] },
  { group: 'comunidad', items: [['jugadores', Users, '/players'], ['partners', Users, '/partners'], ['notificaciones', Bell, '/notifications']] },
  { group: 'negocio', items: [['clubes', Building2, '/clubs'], ['coaches', GraduationCap, '/coaches'], ['miCoachOs', GraduationCap, '/coaches/dashboard'], ['competiciones', Medal, '/competitions'], ['reservas', CalendarDays, '/bookings'], ['promote', Megaphone, '/promote'], ['planes', CreditCard, '/business'], ['finanzas', WalletCards, '/finance']] },
  { group: 'comercio', items: [['marketplace', ShoppingBag, '/marketplace']] },
  { group: 'cuenta', items: [['miPerfil', UserRound, '/settings']] },
] as const

export default function Sidebar() {
  const t = useTranslations('Sidebar')
  const pathname = usePathname() ?? ''
  const isActive = (href: string) => (href === '/' ? pathname === '/' : pathname === href || pathname.startsWith(href + '/'))
  const [isMaster, setIsMaster] = useState(false)
  const [club, setClub] = useState<{ ownsClub: boolean; organizationId: string | null }>({ ownsClub: false, organizationId: null })
  useEffect(() => {
    let cancelled = false
    fetch('/api/master/status')
      .then((res) => (res.ok ? res.json() : { isAdmin: false }))
      .then((data) => { if (!cancelled) setIsMaster(Boolean(data?.isAdmin)) })
      .catch(() => {})
    fetch('/api/club/status')
      .then((res) => (res.ok ? res.json() : { ownsClub: false, organizationId: null }))
      .then((data) => { if (!cancelled) setClub({ ownsClub: Boolean(data?.ownsClub), organizationId: data?.organizationId ?? null }) })
      .catch(() => {})
    return () => { cancelled = true }
  }, [])
  return (
    <aside className="hidden lg:flex fixed left-0 top-0 bottom-0 w-64 border-r border-[#D4AF37]/15 bg-[#0A0A0C]/95 backdrop-blur p-5 flex-col z-40">
      <div className="flex items-center justify-between mb-8">
        <div className="flex items-center gap-3">
          <img src="/dynasty-badge.png" alt="Challenge Dynasty" className="w-11 h-11 object-contain glow" />
          <div className="font-display text-2xl leading-none tracking-wide">CHALLENGE<span className="text-[#D4AF37]"> DYNASTY</span></div>
        </div>
      </div>
      <div className="mb-4"><LocaleSwitcher /></div>
      <Link href="/challenge/new" className="btn-gold shine w-full py-3 mb-6"><Zap size={18} /> {t('retar')}</Link>
      <nav className="space-y-4 overflow-y-auto">
        {groups.map(({ group, items }) => (
          <div key={group}>
            <div className="px-3 mb-1 text-[10px] font-bold uppercase tracking-wider text-white/35">{t(`groups.${group}`)}</div>
            <div className="space-y-1">
              {items.map(([itemKey, Icon, href]) => (
                <Link key={itemKey} href={href} aria-current={isActive(href) ? 'page' : undefined} className={`relative flex items-center gap-3 px-3 py-2.5 text-sm transition ${isActive(href) ? 'bg-gradient-to-r from-[#D4AF37]/20 to-transparent text-white font-bold before:absolute before:left-0 before:top-1 before:bottom-1 before:w-[3px] before:bg-[#D4AF37] before:shadow-[0_0_10px_#D4AF37]' : 'text-white/65 hover:bg-white/5 hover:text-white hover:translate-x-0.5'}`}><Icon size={18} className={isActive(href) ? 'text-[#D4AF37]' : ''} />{t(`items.${itemKey}`)}</Link>
              ))}
            </div>
          </div>
        ))}
        {club.ownsClub ? (
          <div>
            <div className="px-3 mb-1 text-[10px] font-bold uppercase tracking-wider text-white/35">{t('groups.miClubGroup')}</div>
            <div className="space-y-1">
              <Link href={`/clubs/manage/${club.organizationId}`} className="flex items-center gap-3 px-3 py-2.5 text-sm text-[#D4AF37] hover:bg-white/5"><Building2 size={18} />{t('items.miClub')}</Link>
            </div>
          </div>
        ) : null}
        {isMaster ? (
          <div>
            <div className="px-3 mb-1 text-[10px] font-bold uppercase tracking-wider text-white/35">{t('groups.plataforma')}</div>
            <div className="space-y-1">
              <Link href="/master" className="flex items-center gap-3 px-3 py-2.5 text-sm text-[#D4AF37] hover:bg-white/5"><ShieldCheck size={18} />{t('items.master')}</Link>
            </div>
          </div>
        ) : null}
      </nav>
      <div className="card-fut mt-auto"><div className="card-fut-in p-4">
        <div className="text-xs text-white/50">{t('profileCard.kicker')}</div>
        <div className="font-bold mt-1">{t('profileCard.title')}</div>
        <div className="text-[#D4AF37] font-black mt-2">{t('profileCard.badge')}</div>
      </div></div>
    </aside>
  )
}
