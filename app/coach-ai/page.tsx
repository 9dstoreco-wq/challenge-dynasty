import DynastyAIChat from '@/components/DynastyAIChat'
import Sidebar from '@/components/Sidebar'

export default function CoachAIPage() {
  return (
    <div className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-10 p-6 md:p-10">
      <div className="mx-auto max-w-3xl">
        <p className="text-xs font-black tracking-[0.35em] uppercase opacity-60">DYNASTY AI CORE</p>
        <h1 className="mt-3 text-4xl font-display font-black tracking-wide">Dynasty Coach AI</h1>
        <p className="mt-3 opacity-70">Tu entrenador diario con contexto y memoria de Dynasty.</p>
        <DynastyAIChat mode="coach" placeholder="¿Qué quieres trabajar hoy?" />
      </div>
    </main></div>
  )
}
