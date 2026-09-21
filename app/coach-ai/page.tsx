import DynastyAIChat from '@/components/DynastyAIChat'

export default function CoachAIPage() {
  return (
    <main className="min-h-screen p-6 md:p-10">
      <div className="mx-auto max-w-3xl">
        <p className="text-xs font-black tracking-[0.35em] uppercase opacity-60">DYNASTY AI CORE</p>
        <h1 className="mt-3 text-4xl font-black">Dynasty Coach AI</h1>
        <p className="mt-3 opacity-70">Tu entrenador diario con contexto y memoria de Dynasty.</p>
        <DynastyAIChat mode="coach" placeholder="¿Qué quieres trabajar hoy?" />
      </div>
    </main>
  )
}
