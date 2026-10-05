'use client'
import { useEffect, useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { Home, Layers, Zap, Trophy, Menu, X, UserRound } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { navGroups } from './Sidebar'
import LocaleSwitcher from './LocaleSwitcher'

// Barra inferior del celular. El quinto boton abre el menu completo (antes el celular no tenia
// forma de llegar a clubes, mercado, notificaciones, historial, etc.).
export default function BottomNav() {
  const t = useTranslations('Sidebar')
  const pathname = usePathname() ?? ''
  // El menu se cierra solo al cambiar de ruta: guarda en que ruta se abrio.
  const [openAt, setOpenAt] = useState<string | null>(null)
  const open = openAt === pathname
  const setOpen = (v: boolean) => setOpenAt(v ? pathname : null)
  const [loggedIn, setLoggedIn] = useState<boolean | null>(null)

  useEffect(() => {
    let cancelled = false
    async function load() {
      let ok = false
      try { ok = Boolean((await createClient().auth.getUser()).data.user) } catch { ok = false }
      if (!cancelled) setLoggedIn(ok)
    }
    void load()
    return () => { cancelled = true }
  }, [])

  const active = (href: string) => (href === '/' ? pathname === '/' : pathname === href || pathname.startsWith(href + '/'))
  const tab = (href: string) => `flex justify-center ${active(href) ? 'text-[#D4AF37]' : 'text-white/70'}`

  return (
    <>
      {open && (
        <div className="lg:hidden fixed inset-0 z-[60] bg-black/70" onClick={() => setOpen(false)}>
          <div className="absolute left-0 right-0 bottom-0 max-h-[85vh] overflow-y-auto rounded-t-3xl border-t border-[#D4AF37]/25 bg-[#0A0A0C] p-5 pb-24" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <LocaleSwitcher />
              <button onClick={() => setOpen(false)} aria-label={t('close')} className="p-2 text-white/60"><X size={22} /></button>
            </div>
            {loggedIn === false && <Link href="/login" className="btn-gold w-full py-3 mb-5 flex items-center justify-center gap-2">{t('signIn')}</Link>}
            {navGroups
              .filter((g) => loggedIn !== false || g.group !== 'cuenta')
              .map(({ group, items }) => (
                <div key={group} className="mb-5">
                  <div className="px-1 mb-2 text-[10px] font-bold uppercase tracking-wider text-white/35">{t(`groups.${group}`)}</div>
                  <div className="grid grid-cols-2 gap-2">
                    {items.map(([itemKey, Icon, href]) => (
                      <Link key={itemKey} href={href} className={`flex items-center gap-2 rounded-xl border px-3 py-3 text-sm ${active(href) ? 'border-[#D4AF37]/50 bg-[#D4AF37]/10 font-bold' : 'border-white/10 bg-white/5 text-white/80'}`}>
                        <Icon size={16} className={active(href) ? 'text-[#D4AF37]' : ''} />{t(`items.${itemKey}`)}
                      </Link>
                    ))}
                  </div>
                </div>
              ))}
          </div>
        </div>
      )}
      <div className="lg:hidden fixed left-0 right-0 bottom-0 h-16 bg-[#0A0A0C]/95 backdrop-blur border-t border-white/10 z-[70] grid grid-cols-5 items-center">
        <Link href="/" aria-label={t('items.inicio')} className={tab('/')}><Home size={20} /></Link>
        <Link href="/cards" aria-label={t('items.cartas')} className={tab('/cards')}><Layers size={20} /></Link>
        <Link href="/challenge/new" aria-label={t('retar')} className="w-12 h-12 -mt-7 rounded-full bg-[#D4AF37] text-black flex items-center justify-center font-black shadow-lg shadow-gold-500/30 mx-auto"><Zap size={21} /></Link>
        <Link href="/ranking" aria-label={t('items.ranking')} className={tab('/ranking')}><Trophy size={20} /></Link>
        <button onClick={() => setOpen(!open)} aria-label={t('menu')} className={`flex justify-center ${open ? 'text-[#D4AF37]' : 'text-white/70'}`}>{loggedIn === false ? <UserRound size={20} /> : <Menu size={20} />}</button>
      </div>
    </>
  )
}
