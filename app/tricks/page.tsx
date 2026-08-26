import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { Sparkles } from 'lucide-react'

export default function TricksPage(){
  return <div className="min-h-screen bg-[#0B0F19] grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-[1500px] mx-auto px-4 md:px-6 py-7 space-y-7"><section className="rounded-3xl border border-[#00F0FF]/20 bg-gradient-to-br from-[#141B2D] via-[#101827] to-[#0B0F19] p-6 md:p-10"><div className="flex items-center gap-2 text-xs font-black tracking-[.25em] text-[#00F0FF]"><Sparkles size={15}/> SKILL CHALLENGES</div><h1 className="text-4xl md:text-6xl font-black tracking-tight mt-3">RETOS DE HABILIDAD</h1><p className="text-white/60 mt-4 text-lg max-w-2xl">El motor de skill challenges no está conectado al backend vivo en esta versión.</p></section><section className="rounded-3xl border border-white/10 bg-[#141B2D] p-8 text-center text-white/45">No mostramos retos de habilidad ficticios. La sección quedará activa cuando exista su módulo backend oficial.</section></div></main><BottomNav/></div>
}
