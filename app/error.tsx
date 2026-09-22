'use client'

import { useEffect } from 'react'

export default function Error({error,reset}:{error:Error&{digest?:string};reset:()=>void}){
  useEffect(()=>{console.error('CHALLENGE_DYNASTY_APP_ERROR',error)},[error])
  return <main className="min-h-screen bg-[#0A0A0C] text-white grid place-items-center p-6"><section className="w-full max-w-lg rounded-3xl border border-red-400/20 bg-[#161616] p-7"><div className="text-xs tracking-[.3em] text-red-300 font-black">CHALLENGE DYNASTY · ERROR</div><h1 className="text-3xl md:text-4xl font-display font-black tracking-wide mt-3">Algo salió mal.</h1><p className="text-white/55 mt-3">El problema quedó aislado para que puedas volver a intentar sin perder el contexto de la aplicación.</p><button onClick={reset} className="mt-6 rounded-xl bg-[#D4AF37] text-black px-5 py-3 font-black">INTENTAR DE NUEVO</button></section></main>
}
