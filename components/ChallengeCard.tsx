'use client'
import { Clock3, MapPin, Swords } from 'lucide-react'

// Tarjeta de reto estilo "versus" de videojuego: dos jugadores enfrentados con un VS central.
function initial(name: string) { return (name.trim()[0] ?? '?').toUpperCase() }

export default function ChallengeCard({id,title,a,b,points,status,club='—'}:{id?:string;title:string;a:string;b:string;points:number;status:string;club?:string}){
  return <div className="card-fut group"><div className="card-fut-in p-5">
    <div className="text-[11px] font-bold tracking-[.22em] text-[#D4AF37]/80">{title}</div>
    <div className="mt-4 grid grid-cols-[1fr_auto_1fr] items-center gap-3">
      <div className="flex items-center gap-3 min-w-0"><div className="hex grid h-11 w-11 shrink-0 place-items-center font-display text-xl">{initial(a)}</div><div className="truncate text-lg md:text-xl font-black">{a}</div></div>
      <div className="vs-bolt font-display text-3xl leading-none">VS</div>
      <div className="flex items-center justify-end gap-3 min-w-0"><div className="truncate text-right text-lg md:text-xl font-black">{b}</div><div className="grid h-11 w-11 shrink-0 place-items-center bg-white/10 font-display text-xl [clip-path:polygon(50%_0,100%_25%,100%_75%,50%_100%,0_75%,0_25%)]">{initial(b)}</div></div>
    </div>
    <div className="grid grid-cols-3 gap-2 mt-5 text-xs">
      <div className="bg-white/5 p-3"><div className="text-white/40">PUNTOS</div><div className="font-display text-2xl leading-none mt-1 text-[#D4AF37]">{points}</div></div>
      <div className="bg-white/5 p-3 min-w-0"><div className="text-white/40">LUGAR</div><div className="font-bold mt-1 flex items-center gap-1 truncate"><MapPin size={12}/> {club}</div></div>
      <div className="bg-white/5 p-3 min-w-0"><div className="text-white/40">FECHA</div><div className="font-bold mt-1 flex items-center gap-1 truncate"><Clock3 size={12}/>{status}</div></div>
    </div>
    <div className="mt-4 flex gap-2"><a href={id?`/challenge/${id}`:'/arena'} className="btn-ghost flex-1 py-2.5 text-center text-sm font-bold">VER ARENA</a>{id&&<a href={`/challenge/${id}`} className="btn-gold px-4 py-2.5 text-sm"><Swords size={15}/> VER RETO</a>}</div>
  </div></div>
}
