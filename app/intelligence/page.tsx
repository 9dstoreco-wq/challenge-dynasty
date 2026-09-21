import Link from "next/link";

const cards = [
  ["Coach AI", "Tu entrenador personal diario.", "Pádel, fitness, hábitos y progreso.", "/coach-ai"],
  ["Fitness Intelligence", "Entrena con contexto.", "Planifica y adapta tus sesiones.", "/fitness-intelligence"],
  ["Club Intelligence", "Haz crecer tu club.", "Finanzas, marketing, ocupación y CRM.", "/club-intelligence"],
  ["Coach Intelligence", "Haz más con menos.", "Copiloto para alumnos y negocio.", "/coach-intelligence"],
  ["Tournament Intelligence", "Organiza mejor.", "Fair Play, draw, scheduler y promoción.", "/tournament-intelligence"],
  ["Commerce Intelligence", "Vende inteligentemente.", "Shop, Marketplace y recomendaciones.", "/commerce-intelligence"],
] as const;

export default function IntelligencePage() {
  return (
    <main className="min-h-screen p-6 md:p-10">
      <div className="mx-auto max-w-6xl">
        <div className="mb-10">
          <p className="text-xs font-black tracking-[0.35em] uppercase opacity-60">DYNASTY AI CORE</p>
          <h1 className="mt-3 text-4xl md:text-6xl font-black tracking-tight">
            Intelligence for sport.
          </h1>
          <p className="mt-4 max-w-2xl text-base md:text-lg opacity-70">
            Una capa de inteligencia compartida para jugadores, coaches, clubes,
            organizadores y comercio. Cada suscripción desbloquea el nivel de IA correspondiente.
          </p>
        </div>

        <section className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {cards.map(([title, tagline, detail, href]) => (
            <Link
              key={title}
              href={href}
              className="rounded-3xl border border-white/10 bg-white/5 p-6 block hover:border-[#00F0FF]/40 hover:bg-white/[0.07] transition-colors"
            >
              <h2 className="text-xl font-black">{title}</h2>
              <p className="mt-2 font-semibold">{tagline}</p>
              <p className="mt-2 text-sm opacity-65">{detail}</p>
            </Link>
          ))}
        </section>

        <div className="mt-10 flex flex-wrap gap-3">
          <Link href="/business" className="rounded-full border border-white/15 px-5 py-3 text-sm font-bold">
            Ver Business
          </Link>
          <Link href="/shop" className="rounded-full border border-white/15 px-5 py-3 text-sm font-bold">
            Ver Shop
          </Link>
          <Link href="/marketplace" className="rounded-full border border-white/15 px-5 py-3 text-sm font-bold">
            Ver Marketplace
          </Link>
        </div>
      </div>
    </main>
  );
}
