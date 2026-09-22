'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'

type Sport = { id:string; slug:string; name:string; icon:string|null; color:string|null }

export default function OnboardingPage(){
  const supabase=createClient()
  const [sports,setSports]=useState<Sport[]>([]); const [sport,setSport]=useState(''); const [message,setMessage]=useState(''); const [loading,setLoading]=useState(true); const [saving,setSaving]=useState(false)
  useEffect(()=>{(async()=>{const {data,error}=await supabase.from('sports').select('id,slug,name,icon,color').order('name'); if(error)setMessage(toSafeMessage(error,'onboarding.loadSports')); else setSports(data??[]); setLoading(false)})()},[])
  async function save(){const supabase=createClient();if(!sport){setMessage('Selecciona un deporte.');return} setSaving(true); setMessage(''); const {data:{user}}=await supabase.auth.getUser(); if(!user){setMessage('Inicia sesión primero.');setSaving(false);return}
    const meta=(user.user_metadata||{}) as Record<string,unknown>
    const metaFullName=typeof meta.full_name==='string'?meta.full_name:null
    const metaUsername=typeof meta.username==='string'?meta.username:null
    const fallbackName=metaFullName||metaUsername||(user.email?user.email.split('@')[0]:'Jugador Dynasty')
    const {error:profileError}=await supabase.from('profiles').upsert({id:user.id,display_name:fallbackName,username:metaUsername},{onConflict:'id',ignoreDuplicates:true})
    if(profileError&&profileError.code==='23505'){await supabase.from('profiles').upsert({id:user.id,display_name:fallbackName},{onConflict:'id',ignoreDuplicates:true})}
    const {data}=await supabase.from('sports').select('id').eq('slug',sport).single(); if(!data){setMessage('El deporte ya no está disponible.');setSaving(false);return} const {error}=await supabase.from('player_sports').upsert({profile_id:user.id,sport_id:data.id,is_primary:true,is_discoverable:true,relationship:'primary',skill_level:null},{onConflict:'profile_id,sport_id'}); if(error)setMessage(toSafeMessage(error,'onboarding.saveSport')); else setMessage('Listo. Ya puedes crear tu primer reto.'); setSaving(false)}
  return <main className="min-h-screen bg-[#0A0A0C] text-white grid place-items-center p-6"><section className="w-full max-w-3xl rounded-3xl border border-white/10 bg-[#161616] p-7"><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">PRIMER PASO</div><h1 className="text-3xl md:text-5xl font-display font-black tracking-wide mt-2">Elige tu deporte principal.</h1><p className="text-white/50 mt-2">Tu cuenta puede tener varios deportes, pero empezamos con uno.</p><div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3 mt-7">{loading ? <div className="sm:col-span-2 lg:col-span-3 p-6 text-white/45">Cargando deportes...</div> : sports.map(s=><button key={s.id} onClick={()=>setSport(s.slug)} className={`rounded-2xl p-4 text-left border ${sport===s.slug?'border-[#D4AF37] bg-[#D4AF37]/10':'border-white/10 bg-white/5'}`}>{s.icon||'🏆'} {s.name}</button>)}</div>{message&&<p className="text-white/60 mt-4">{message}</p>}<div className="flex flex-wrap gap-3 mt-6"><button disabled={saving||loading} onClick={save} className="rounded-xl bg-[#D4AF37] text-black px-5 py-3 font-black">{saving?'GUARDANDO...':'GUARDAR DEPORTE'}</button><Link href="/" className="rounded-xl bg-white/5 border border-white/10 px-5 py-3 font-bold">IR A CHALLENGE</Link></div></section></main>
}
