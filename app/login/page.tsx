'use client'

import Link from 'next/link'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'
import { useTranslations } from 'next-intl'

export default function LoginPage() {
  const t = useTranslations('Login')
  const [email,setEmail] = useState('')
  const [password,setPassword] = useState('')
  const [error,setError] = useState('')
  const [loading,setLoading] = useState(false)
  async function submit(e: React.FormEvent) {
    e.preventDefault(); setError(''); setLoading(true)
    const supabase = createClient()
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    // Recarga completa a proposito: asegura que el servidor lea la cookie de sesion recien creada.
    // eslint-disable-next-line @next/next/no-location-assign-relative-destination
    if (error) setError(toSafeMessage(error,'auth.signIn')); else window.location.href='/onboarding'
    setLoading(false)
  }
  return <main className="min-h-screen arena-bg text-white grid place-items-center p-6"><form onSubmit={submit} className="hud-corners shine reveal w-full max-w-md border border-[#D4AF37]/30 bg-gradient-to-br from-[#221F0F] via-[#141416] to-[#0A0A0C] p-8 relative overflow-hidden [clip-path:polygon(24px_0,100%_0,100%_calc(100%-24px),calc(100%-24px)_100%,0_100%,0_24px)] shadow-[0_0_80px_rgba(212,175,55,.12)]"><img src="/dynasty-badge.png" alt="Challenge Dynasty" className="float-y w-16 h-16 object-contain mb-3 drop-shadow-[0_0_24px_rgba(212,175,55,.55)]"/><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">CHALLENGE DYNASTY</div><h1 className="text-4xl font-display font-black tracking-wide mt-2">{t('title')}</h1><div className="space-y-3 mt-6"><input value={email} onChange={e=>setEmail(e.target.value)} type="email" required placeholder={t('emailPlaceholder')} className="w-full bg-white/5 border border-white/10 px-4 py-3 outline-none transition focus:border-[#D4AF37] focus:bg-[#D4AF37]/5 focus:shadow-[0_0_0_1px_#D4AF37] outline-none"/><input value={password} onChange={e=>setPassword(e.target.value)} type="password" required placeholder={t('passwordPlaceholder')} className="w-full bg-white/5 border border-white/10 px-4 py-3 outline-none transition focus:border-[#D4AF37] focus:bg-[#D4AF37]/5 focus:shadow-[0_0_0_1px_#D4AF37] outline-none"/></div>{error&&<p className="text-red-300 text-sm mt-3">{error}</p>}<button disabled={loading} className="btn-gold w-full mt-5 py-3 disabled:opacity-60">{loading?t('loggingIn'):t('submitBtn')}</button><p className="text-sm mt-4"><Link href="/forgot-password" className="text-[#D4AF37] font-bold">{t('forgotPassword')}</Link></p><p className="text-sm text-white/45 mt-3">{t('noAccount')} <Link href="/register" className="text-[#D4AF37] font-bold">{t('createAccount')}</Link></p></form></main>
}
