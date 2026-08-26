import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'

export default function RankingPage(){
  return <div className="min-h-screen bg-[#0B0F19] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-5xl mx-auto px-4 md:px-6 py-8"><div className="text-xs tracking-[.3em] text-[#00F0FF] font-black">CHALLENGE DYNASTY · RANKING</div><h1 className="text-4xl md:text-6xl font-black mt-2">RANKING</h1><p className="text-white/50 mt-2">El motor de ranking competitivo todavía no está conectado al backend vivo.</p><div className="mt-7 rounded-3xl border border-white/10 bg-[#141B2D] p-8 text-center"><div className="text-5xl mb-4">🏆</div><h2 className="text-xl font-black">RANKING EN PREPARACIÓN</h2><p className="text-white/45 mt-2 max-w-xl mx-auto">No mostramos posiciones inventadas. Esta pantalla quedará conectada cuando exista el motor oficial de ranking en Supabase.</p></div></div></main><BottomNav/></div>
}
