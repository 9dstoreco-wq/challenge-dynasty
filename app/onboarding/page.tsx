'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'
import { useTranslations } from 'next-intl'
import { Swords, Medal, Layers, Trophy } from 'lucide-react'

type Sport = { id:string; slug:string; name:string; icon:string|null; color:string|null }

// BUG ENCONTRADO EN AUDITORIA FUNCIONAL (2026-11-25): esta pagina era el UNICO lugar de toda la
// app que creaba la fila en `profiles`, y solo la creaba DENTRO de save(), despues de elegir un
// deporte. Alguien que llegara aqui y no eligiera deporte (o cerrara la pestana) se quedaba sin
// perfil para siempre -- y como casi toda la app tiene llave foranea a profiles(id), no podia
// crear ni un reto, con un error generico que no explicaba nada. Fix: asegurar el perfil apenas
// carga la pagina (independiente de si elige deporte o no), ademas del fix en /register que ya
// lo crea apenas hay sesion.
async function ensureProfile(supabase: ReturnType<typeof createClient>, fallbackName: string, metaUsername: string | null, userId: string){
  const {error}=await supabase.from('profiles').upsert({id:userId,display_name:fallbackName,username:metaUsername},{onConflict:'id',ignoreDuplicates:true})
  if(error&&error.code==='23505'){await supabase.from('profiles').upsert({id:userId,display_name:fallbackName},{onConflict:'id',ignoreDuplicates:true})}
}

export default function OnboardingPage(){
  const t=useTranslations('Onboarding')
  const [sports,setSports]=useState<Sport[]>([]); const [sport,setSport]=useState(''); const [message,setMessage]=useState(''); const [loading,setLoading]=useState(true); const [saving,setSaving]=useState(false)
  useEffect(()=>{(async()=>{
    const supabase=createClient()
    const [{data:sportsData,error:sportsError},{data:{user}}]=await Promise.all([
      supabase.from('sports').select('id,slug,name,icon,color').order('name'),
      supabase.auth.getUser(),
    ])
    if(sportsError)setMessage(toSafeMessage(sportsError,'onboarding.loadSports')); else setSports(sportsData??[])
    if(user){
      const meta=(user.user_metadata||{}) as Record<string,unknown>
      const metaFullName=typeof meta.full_name==='string'?meta.full_name:null
      const metaUsername=typeof meta.username==='string'?meta.username:null
      const fallbackName=metaFullName||metaUsername||(user.email?user.email.split('@')[0]:t('defaultName'))
      await ensureProfile(supabase,fallbackName,metaUsername,user.id)
    }
    setLoading(false)
  })()},[t])
  async function save(){const supabase=createClient();if(!sport){setMessage(t('selectSport'));return} setSaving(true); setMessage(''); const {data:{user}}=await supabase.auth.getUser(); if(!user){setMessage(t('loginFirst'));setSaving(false);return}
    const meta=(user.user_metadata||{}) as Record<string,unknown>
    const metaFullName=typeof meta.full_name==='string'?meta.full_name:null
    const metaUsername=typeof meta.username==='string'?meta.username:null
    const fallbackName=metaFullName||metaUsername||(user.email?user.email.split('@')[0]:t('defaultName'))
    await ensureProfile(supabase,fallbackName,metaUsername,user.id)
    const {data}=await supabase.from('sports').select('id').eq('slug',sport).single(); if(!data){setMessage(t('sportUnavailable'));setSaving(false);return} const {error}=await supabase.from('player_sports').upsert({profile_id:user.id,sport_id:data.id,is_primary:true,is_discoverable:true,relationship:'primary',skill_level:null},{onConflict:'profile_id,sport_id'}); if(error)setMessage(toSafeMessage(error,'onboarding.saveSport')); else setMessage(t('done')); setSaving(false)}
  const features=[
    {Icon:Swords,title:t('featureRetosTitle'),body:t('featureRetosBody'),cta:t('featureRetosCta'),href:'/challenge/new'},
    {Icon:Medal,title:t('featureTorneosTitle'),body:t('featureTorneosBody'),cta:t('featureTorneosCta'),href:'/competitions'},
    {Icon:Layers,title:t('featureCartasTitle'),body:t('featureCartasBody'),cta:t('featureCartasCta'),href:'/cards'},
    {Icon:Trophy,title:t('featureRankingTitle'),body:t('featureRankingBody'),cta:t('featureRankingCta'),href:'/ranking'},
  ] as const
  return <main className="min-h-screen arena-bg text-white p-6"><div className="max-w-3xl mx-auto space-y-6">
    <section className="rounded-3xl border border-[#D4AF37]/20 bg-gradient-to-br from-[#1B1A12] via-[#161616] to-[#0A0A0C] p-7"><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">{t('step')}</div><h1 className="text-3xl md:text-5xl font-display font-black tracking-wide mt-2">{t('title')}</h1><p className="text-white/50 mt-2">{t('subtitle')}</p><div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3 mt-7">{loading ? <div className="sm:col-span-2 lg:col-span-3 p-6 text-white/45">{t('loading')}</div> : sports.map(s=><button key={s.id} onClick={()=>setSport(s.slug)} className={`rounded-2xl p-4 text-left border ${sport===s.slug?'border-[#D4AF37] bg-[#D4AF37]/10':'border-white/10 bg-white/5'}`}>{s.icon||'🏆'} {s.name}</button>)}</div>{message&&<p className="text-white/60 mt-4">{message}</p>}<div className="flex flex-wrap gap-3 mt-6"><button disabled={saving||loading} onClick={save} className="rounded-xl bg-[#D4AF37] text-black px-5 py-3 font-black">{saving?t('saving'):t('saveSport')}</button><Link href="/" className="rounded-xl bg-white/5 border border-white/10 px-5 py-3 font-bold">{t('goToChallenge')}</Link></div></section>
    <section className="rounded-3xl border border-white/10 bg-[#141416] p-7"><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">{t('featuresStep')}</div><h2 className="text-2xl md:text-3xl font-display font-black tracking-wide mt-2">{t('featuresTitle')}</h2><p className="text-white/50 mt-2">{t('featuresSubtitle')}</p><div className="grid sm:grid-cols-2 gap-3 mt-6">{features.map(({Icon,title,body,cta,href})=><Link key={href} href={href} className="rounded-2xl border border-white/10 bg-white/5 p-4 flex flex-col gap-2 hover:border-[#D4AF37]/40 hover:bg-white/[.07]"><Icon size={20} className="text-[#D4AF37]"/><div className="font-black">{title}</div><p className="text-sm text-white/50">{body}</p><span className="text-xs font-black text-[#D4AF37] mt-1">{cta} →</span></Link>)}</div></section>
  </div></main>
}
