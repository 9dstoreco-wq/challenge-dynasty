'use client'

import Link from 'next/link'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'

export default function LoginPage() {
  const [email,setEmail] = useState('')
  const [password,setPassword] = useState('')
  const [error,setError] = useState('')
  const [loading,setLoading] = useState(false)
  async function submit(e: React.FormEvent) {
    e.preventDefault(); setError(''); setLoading(true)
    const supabase = createClient()
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) setError(toSafeMessage(error,'auth.signIn')); else window.location.href='/onboarding'
    setLoading(false)
  }
  return <main className="min-h-screen bg-[#0A0A0C] text-white grid place-items-center p-6"><form onSubmit={submit} className="w-full max-w-md rounded-3xl border border-[#D4AF37]/20 bg-gradient-to-br from-[#1B1A12] via-[#161616] to-[#0A0A0C] p-7 relative overflow-hidden"><img src="/dynasty-badge.png" alt="Challenge Dynasty" className="w-14 h-14 object-contain mb-3"/><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">CHALLENGE DYNASTY</div><h1 className="text-3xl font-display font-black tracking-wide mt-2">Entrar</h1><div className="space-y-3 mt-6"><input value={email} onChange={e=>setEmail(e.target.value)} type="email" required placeholder="Correo" className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3 outline-none"/><input value={password} onChange={e=>setPassword(e.target.value)} type="password" required placeholder="Contraseña" className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3 outline-none"/></div>{error&&<p className="text-red-300 text-sm mt-3">{error}</p>}<button disabled={loading} className="w-full mt-5 rounded-xl bg-[#D4AF37] text-black py-3 font-black">{loading?'ENTRANDO...':'ENTRAR'}</button><p className="text-sm text-white/45 mt-5">¿No tienes cuenta? <Link href="/register" className="text-[#D4AF37] font-bold">Crear cuenta</Link></p></form></main>
}
