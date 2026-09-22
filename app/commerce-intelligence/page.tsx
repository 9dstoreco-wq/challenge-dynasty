import DynastyAIContextPanel from '@/components/DynastyAIContextPanel'
import DynastyAIChat from '@/components/DynastyAIChat'
import Sidebar from '@/components/Sidebar'

export default function Page() {
  return (
    <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-10 p-6 md:p-10">
      <div className="mx-auto max-w-5xl">
        <p className="text-xs font-black tracking-[0.35em] uppercase opacity-60">DYNASTY AI CORE</p>
        <h1 className="mt-3 text-4xl font-display font-black tracking-wide tracking-tight">DYNASTY COMMERCE INTELLIGENCE</h1>
        <p className="mt-3 max-w-2xl text-lg opacity-70">Recomendaciones y crecimiento para Shop y Marketplace.</p>
        <DynastyAIContextPanel area="Commerce Intelligence" />
        <DynastyAIChat mode="commerce" placeholder="Pregúntame sobre tu tienda o marketplace..." />
      </div>
    </main></div>
  )
}
