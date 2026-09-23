'use client'
import { useEffect, useState } from 'react'
import Link from 'next/link'
import { Home, Swords, Trophy, Radio, Users, Building2, Medal, Bell, UserRound, Zap, Sparkles, Store, ShoppingBag, GraduationCap, Megaphone, CreditCard, CalendarDays, WalletCards, Bot, LayoutGrid, History, ShieldCheck } from 'lucide-react'

const groups = [
  {
    label: 'Jugar',
    items: [
      ['Inicio', Home, '/'],
      ['Retos', Swords, '/challenge/new'],
      ['Deportes', LayoutGrid, '/sports'],
      ['Trucos', Sparkles, '/tricks'],
      ['Ranking', Trophy, '/ranking'],
      ['Historial', History, '/history'],
      ['Arena', Radio, '/arena'],
    ],
  },
  {
    label: 'Comunidad',
    items: [
      ['Jugadores', Users, '/players'],
      ['Partners', Users, '/partners'],
      ['Notificaciones', Bell, '/notifications'],
    ],
  },
  {
    label: 'Dynasty AI',
    items: [['Dynasty AI', Bot, '/intelligence']],
  },
  {
    label: 'Negocio',
    items: [
      ['Clubes', Building2, '/clubs'],
      ['Coaches', GraduationCap, '/coaches'],
      ['Mi Coach OS', GraduationCap, '/coaches/dashboard'],
      ['Competiciones', Medal, '/competitions'],
      ['Reservas', CalendarDays, '/bookings'],
      ['Promote', Megaphone, '/promote'],
      ['Planes', CreditCard, '/business'],
      ['Finanzas', WalletCards, '/finance'],
    ],
  },
  {
    label: 'Comercio',
    items: [
      ['Marketplace', ShoppingBag, '/marketplace'],
      ['Dynasty Shop', Store, '/shop'],
      ['Mi Tienda', Store, '/shop/admin'],
    ],
  },
  {
    label: 'Cuenta',
    items: [['Mi perfil', UserRound, '/settings']],
  },
] as const

export default function Sidebar() {
  const [isMaster, setIsMaster] = useState(false)

  useEffect(() => {
    let cancelled = false
    fetch('/api/master/status')
      .then((res) => (res.ok ? res.json() : { isAdmin: false }))
      .then((data) => {
        if (!cancelled) setIsMaster(Boolean(data?.isAdmin))
      })
      .catch(() => {})
    return () => {
      cancelled = true
    }
  }, [])

  return (
    <aside className="hidden lg:flex fixed left-0 top-0 bottom-0 w-64 border-r border-white/10 bg-[#0A0A0C]/95 p-5 flex-col z-40">
      <div className="flex items-center gap-3 mb-8">
        <img src="/dynasty-badge.png" alt="Challenge Dynasty" className="w-11 h-11 object-contain glow" />
        <div className="font-display text-2xl leading-none tracking-wide">CHALLENGE<span className="text-[#D4AF37]"> DYNASTY</span></div>
      </div>
      <Link href="/challenge/new" className="w-full rounded-2xl bg-[#D4AF37] text-black font-extrabold py-3 flex items-center justify-center gap-2 mb-6 glow">
        <Zap size={18} /> RETAR
      </Link>
      <nav className="space-y-4 overflow-y-auto">
        {groups.map(({ label, items }) => (
          <div key={label}>
            <div className="px-3 mb-1 text-[10px] font-bold uppercase tracking-wider text-white/35">{label}</div>
            <div className="space-y-1">
              {items.map(([itemLabel, Icon, href]) => (
                <Link key={itemLabel} href={href} className="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm text-white/70 hover:bg-white/5 hover:text-white">
                  <Icon size={18} />{itemLabel}
                </Link>
              ))}
            </div>
          </div>
        ))}
        {isMaster ? (
          <div>
            <div className="px-3 mb-1 text-[10px] font-bold uppercase tracking-wider text-white/35">Plataforma</div>
            <div className="space-y-1">
              <Link href="/master" className="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm text-[#D4AF37] hover:bg-white/5">
                <ShieldCheck size={18} />Master
              </Link>
            </div>
          </div>
        ) : null}
      </nav>
      <div className="mt-auto rounded-2xl bg-[#161616] p-4">
        <div className="text-xs text-white/50">SPORTS + PLAYER</div>
        <div className="font-bold mt-1">Tu perfil</div>
        <div className="text-[#D4AF37] font-black mt-2">PASAPORTE</div>
      </div>
    </aside>
  )
}
