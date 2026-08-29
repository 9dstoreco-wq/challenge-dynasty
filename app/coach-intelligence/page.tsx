import DynastyAIContextPanel from '@/components/DynastyAIContextPanel'

export default function Page() {
  return (
    <main className="min-h-screen p-6 md:p-10">
      <div className="mx-auto max-w-5xl">
        <p className="text-xs font-black tracking-[0.35em] uppercase opacity-60">DYNASTY AI CORE</p>
        <h1 className="mt-3 text-4xl font-black tracking-tight">DYNASTY COACH INTELLIGENCE</h1>
        <p className="mt-3 max-w-2xl text-lg opacity-70">Copiloto para coaches y academias.</p>
        <DynastyAIContextPanel area="Coach Intelligence" />
      </div>
    </main>
  )
}
