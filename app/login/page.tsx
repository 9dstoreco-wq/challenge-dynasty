export const dynamic = 'force-dynamic'
'use client'

import Link from 'next/link'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'

export default function LoginPage() {
  const [email,setEmail] = useState('')
  const [password,setPassword] = useState('')
  const [error,setError] = useState('')
  const [loading,setLoading] = useState(false)
  async function submit(e: React.FormEvent) {
    e.preventDefault(); setError(''); setLoading(true)
    const supabase = createClient()
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) setError(error.message); else window.location.href='/onboarding'
    setLoading(false)
  }
  return <main className="min-h-screen bg-[#0B0F19] text-white grid place-items-center p-6"><form onSubmit={submit} className="w-full max-w-md rounded-3xl border border-white/10 bg-[#141B2D] p-7"><div className="text-xs tracking-[.3em] text-[#00F0FF] font-black">CHALLENGE DYNASTY</div><h1 className="text-3xl font-black mt-2">Entrar</h1><div className="space-y-3 mt-6"><input value={email} onChange={e=>setEmail(e.target.value)} type="email" required placeholder="Correo" className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3 outline-none"/><input value={password} onChange={e=>setPassword(e.target.value)} type="password" required placeholder="Contraseña" className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3 outline-none"/></div>{error&&<p className="text-red-300 text-sm mt-3">{error}</p>}<button disabled={loading} className="w-full mt-5 rounded-xl bg-[#00F0FF] text-black py-3 font-black">{loading?'ENTRANDO...':'ENTRAR'}</button><p className="text-sm text-white/45 mt-5">¿No tienes cuenta? <Link href="/register" className="text-[#00F0FF] font-bold">Crear cuenta</Link></p></form></main>
}
