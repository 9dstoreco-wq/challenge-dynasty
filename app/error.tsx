'use client'

import { useEffect } from 'react'
import { useTranslations } from 'next-intl'

export default function Error({error,reset}:{error:Error&{digest?:string};reset:()=>void}){
  const t = useTranslations('AppError')
  useEffect(()=>{console.error('CHALLENGE_DYNASTY_APP_ERROR',error)},[error])
  return <main className="min-h-screen arena-bg text-white grid place-items-center p-6"><section className="w-full max-w-lg rounded-3xl border border-red-400/20 bg-[#161616] p-7"><div className="text-xs tracking-[.3em] text-red-300 font-black">CHALLENGE DYNASTY · ERROR</div><h1 className="text-3xl md:text-4xl font-display font-black tracking-wide mt-3">{t('title')}</h1><p className="text-white/55 mt-3">{t('description')}</p><button onClick={reset} className="mt-6 rounded-xl bg-[#D4AF37] text-black px-5 py-3 font-black">{t('retry')}</button></section></main>
}
