'use client'
import { Flame, Heart, MessageCircle, Play, Swords, Trophy, Zap } from 'lucide-react'

export default function SkillChallengeCard({title,user,rank,votes,difficulty,points,category,accent}:{title:string;user:string;rank:string;votes:number;difficulty:string;points:number;category:string;accent:string}){
  return <article className="rounded-3xl border border-white/10 bg-[#161616] overflow-hidden hover:border-gold-300/30 transition group">
    <div className={`aspect-[16/9] bg-gradient-to-br ${accent} relative flex items-center justify-center`}>
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_40%,rgba(255,255,255,.10),transparent_48%)]"/>
      <div className="absolute top-4 left-4 rounded-full bg-black/45 border border-white/10 px-3 py-1 text-[10px] font-black tracking-wider">{difficulty}</div>
      <div className="absolute top-4 right-4 rounded-full bg-black/45 border border-white/10 px-3 py-1 text-[10px] font-black tracking-wider flex items-center gap-1"><Flame size={12} className="text-[#FF3D00]"/> TRENDING</div>
      <button aria-label="Ver video" className="h-16 w-16 rounded-full bg-black/45 backdrop-blur border border-white/20 flex items-center justify-center group-hover:scale-110 transition"><Play fill="white" size={24}/></button>
      <div className="absolute bottom-4 left-4 rounded-full bg-black/50 border border-white/10 px-3 py-1 text-xs font-black">{category}</div>
      <div className="absolute bottom-4 right-4 rounded-full bg-black/50 border border-white/10 px-3 py-1 text-xs font-black flex items-center gap-1"><Zap size={12} className="text-[#D4AF37]"/> +{points}</div>
    </div>
    <div className="p-5">
      <div className="flex items-start justify-between gap-4">
        <div><h3 className="text-xl font-black">{title}</h3><p className="text-sm text-white/45 mt-1">{user} · {rank}</p></div>
        <div className="text-right"><div className="text-[10px] text-white/35">VOTOS</div><div className="font-black text-[#D4AF37]">{votes}</div></div>
      </div>
      <div className="grid grid-cols-3 gap-2 mt-5">
        <button className="rounded-xl bg-white/5 py-3 text-xs font-black flex items-center justify-center gap-1"><Heart size={14}/> VOTAR</button>
        <button className="rounded-xl bg-white/5 py-3 text-xs font-black flex items-center justify-center gap-1"><MessageCircle size={14}/> COMENTAR</button>
        <button className="rounded-xl bg-[#D4AF37] text-black py-3 text-xs font-black flex items-center justify-center gap-1"><Swords size={14}/> SUPERAR</button>
      </div>
    </div>
  </article>
}
