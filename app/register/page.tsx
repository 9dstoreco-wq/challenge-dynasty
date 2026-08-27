export const dynamic = 'force-dynamic'
'use client'

import Link from 'next/link'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'

export default function RegisterPage() {
  const [email,setEmail]=useState(''); const [password,setPassword]=useState(''); const [name,setName]=useState(''); const [username,setUsername]=useState(''); const [message,setMessage]=useState(''); const [loading,setLoading]=useState(false)
  async function submit(e: React.FormEvent){e.preventDefault();setMessage('');setLoading(true);const supabase=createClient();const {error}=await supabase.auth.signUp({email,password,options:{data:{full_name:name,username}}}); if(error)setMessage(error.message); else setMessage('Cuenta creada. Revisa tu correo si la confirmación está activada.');setLoading(false)}
  return <main className="min-h-screen bg-[#0B0F19] text-white grid place-items-center p-6"><form onSubmit={submit} className="w-full max-w-md rounded-3xl border border-white/10 bg-[#141B2D] p-7"><div className="text-xs tracking-[.3em] text-[#00F0FF] font-black">CHALLENGE DYNASTY</div><h1 className="text-3xl font-black mt-2">Crear cuenta</h1><div className="space-y-3 mt-6"><input value={name} onChange={e=>setName(e.target.value)} required placeholder="Nombre" className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3"/><input value={username} onChange={e=>setUsername(e.target.value)} required placeholder="Usuario" className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3"/><input value={email} onChange={e=>setEmail(e.target.value)} required type="email" placeholder="Correo" className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3"/><input value={password} onChange={e=>setPassword(e.target.value)} required type="password" minLength={6} placeholder="Contraseña" className="w-full rounded-xl bg-white/5 border border-white/10 px-4 py-3"/></div>{message&&<p className="text-white/60 text-sm mt-3">{message}</p>}<button disabled={loading} className="w-full mt-5 rounded-xl bg-[#00F0FF] text-black py-3 font-black">{loading?'CREANDO...':'CREAR CUENTA'}</button><p className="text-sm text-white/45 mt-5">¿Ya tienes cuenta? <Link href="/login" className="text-[#00F0FF] font-bold">Entrar</Link></p></form></main>
}
