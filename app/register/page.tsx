'use client'

import Link from 'next/link'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'
import { useTranslations } from 'next-intl'

export default function RegisterPage() {
  const t = useTranslations('Register')
  const tLegal = useTranslations('Legal')
  const router = useRouter()
  const [email,setEmail]=useState(''); const [password,setPassword]=useState(''); const [name,setName]=useState(''); const [username,setUsername]=useState(''); const [message,setMessage]=useState(''); const [loading,setLoading]=useState(false)
  // BUG ENCONTRADO EN AUDITORIA FUNCIONAL (2026-11-25): el perfil (tabla `profiles`) solo se
  // creaba en /onboarding, y solo despues de elegir un deporte -- si alguien cerraba la pestana
  // antes de llegar ahi, quedaba con una cuenta de auth.users SIN perfil para siempre (sin
  // trigger en la base de datos que lo cree, y sin ninguna pantalla que lo redirija de vuelta).
  // Como casi todo en la app tiene llave foranea a profiles(id), esa persona no podia crear ni
  // un reto. Fix: crear el perfil YA cuando hay sesion inmediata tras el registro (si el
  // proyecto no exige confirmar el correo), y mandarla derecho a /onboarding en vez de dejarla
  // parada con un mensaje de texto.
  async function submit(e: React.FormEvent){e.preventDefault();setMessage('');setLoading(true);const supabase=createClient();const {data,error}=await supabase.auth.signUp({email,password,options:{data:{full_name:name,username}}}); if(error){setMessage(toSafeMessage(error,'auth.signUp'));setLoading(false);return} if(data.session){await supabase.from('profiles').upsert({id:data.session.user.id,display_name:name||username,username},{onConflict:'id',ignoreDuplicates:true});router.push('/onboarding');return} setMessage(t('accountCreated'));setLoading(false)}
  return <main className="min-h-screen arena-bg text-white grid place-items-center p-6"><form onSubmit={submit} className="hud-corners shine reveal w-full max-w-md border border-[#D4AF37]/30 bg-gradient-to-br from-[#221F0F] via-[#141416] to-[#0A0A0C] p-8 relative overflow-hidden [clip-path:polygon(24px_0,100%_0,100%_calc(100%-24px),calc(100%-24px)_100%,0_100%,0_24px)] shadow-[0_0_80px_rgba(212,175,55,.12)]"><img src="/dynasty-badge.png" alt="Challenge Dynasty" className="float-y w-16 h-16 object-contain mb-3 drop-shadow-[0_0_24px_rgba(212,175,55,.55)]"/><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">CHALLENGE DYNASTY</div><h1 className="text-4xl font-display font-black tracking-wide mt-2">{t('title')}</h1><div className="space-y-3 mt-6"><input value={name} onChange={e=>setName(e.target.value)} required placeholder={t('namePlaceholder')} className="w-full bg-white/5 border border-white/10 px-4 py-3 outline-none transition focus:border-[#D4AF37] focus:bg-[#D4AF37]/5 focus:shadow-[0_0_0_1px_#D4AF37]"/><input value={username} onChange={e=>setUsername(e.target.value)} required placeholder={t('usernamePlaceholder')} className="w-full bg-white/5 border border-white/10 px-4 py-3 outline-none transition focus:border-[#D4AF37] focus:bg-[#D4AF37]/5 focus:shadow-[0_0_0_1px_#D4AF37]"/><input value={email} onChange={e=>setEmail(e.target.value)} required type="email" placeholder={t('emailPlaceholder')} className="w-full bg-white/5 border border-white/10 px-4 py-3 outline-none transition focus:border-[#D4AF37] focus:bg-[#D4AF37]/5 focus:shadow-[0_0_0_1px_#D4AF37]"/><input value={password} onChange={e=>setPassword(e.target.value)} required type="password" minLength={6} placeholder={t('passwordPlaceholder')} className="w-full bg-white/5 border border-white/10 px-4 py-3 outline-none transition focus:border-[#D4AF37] focus:bg-[#D4AF37]/5 focus:shadow-[0_0_0_1px_#D4AF37]"/></div>{message&&<p className="text-white/60 text-sm mt-3">{message}</p>}<button disabled={loading} className="btn-gold w-full mt-5 py-3 disabled:opacity-60">{loading?t('creating'):t('submitBtn')}</button><p className="text-sm text-white/45 mt-5">{t('alreadyHaveAccount')} <Link href="/login" className="text-[#D4AF37] font-bold">{t('login')}</Link></p><p className="text-xs text-white/35 mt-3">{tLegal('registerNote')} <Link href="/legal/terms" className="text-[#D4AF37]/80 underline">{tLegal('termsLink')}</Link> {tLegal('and')} <Link href="/legal/privacy" className="text-[#D4AF37]/80 underline">{tLegal('privacyLink')}</Link>.</p></form></main>
}
