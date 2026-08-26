import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'

export default function CompetitionsPage(){
  return <div className="min-h-screen bg-[#0B0F19] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-6xl mx-auto px-4 md:px-6 py-8"><div className="text-xs tracking-[.3em] text-[#00F0FF] font-black">COMPETITIONS</div><h1 className="text-4xl md:text-6xl font-black mt-2">COMPETICIONES</h1><p className="text-white/50 mt-2">El motor oficial de temporadas todavía no está conectado al backend vivo.</p><div className="rounded-3xl border border-white/10 bg-[#141B2D] p-8 text-center mt-7"><div className="text-5xl mb-4">🏆</div><h2 className="text-xl font-black">COMPETICIONES EN PREPARACIÓN</h2><p className="text-white/45 mt-2 max-w-xl mx-auto">No mostramos temporadas ni cuadros que todavía no existen en Supabase.</p></div></div></main><BottomNav/></div>
}
