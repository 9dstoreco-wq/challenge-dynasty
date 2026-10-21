import Link from 'next/link'

// Dos mundos (estilo "On Track / Off Track" de landonorris.com):
// competir en la cancha y vivir fuera de ella.
type World = { tag: string; meta: string; title: string; body: string; href: string; cta: string }

function Arrow() {
  return (
    <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M7 17 17 7" /><path d="M8 7h9v9" />
    </svg>
  )
}

export default function SplitWorlds({ on, off }: { on: World; off: World }) {
  return (
    <section className="grid gap-5 md:grid-cols-2 mt-8">
      <Link href={on.href} className="split-world group relative overflow-hidden rounded-[28px] bg-[#161616] p-7 md:p-10 min-h-[360px] md:min-h-[440px] flex flex-col justify-between focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#D4AF37]">
        <span aria-hidden="true" className="split-world-glow" />
        <div className="relative flex items-start justify-between gap-4 text-xs md:text-sm">
          <span className="font-bold tracking-[.2em] uppercase text-[#D4AF37]">{on.tag}</span>
          <span className="text-white/50">{on.meta}</span>
        </div>
        <h2 className="relative font-display font-normal leading-[.86] text-[clamp(64px,8vw,124px)] transition-transform duration-500 group-hover:-translate-y-1 whitespace-pre-line">{on.title}</h2>
        <div className="relative flex flex-wrap items-end justify-between gap-4">
          <p className="max-w-xs text-white/70 leading-relaxed">{on.body}</p>
          <span className="sr-only">{on.cta}</span>
          <span className="split-world-btn h-16 w-16 rounded-full bg-[#D4AF37] text-[#0A0A0C] inline-flex items-center justify-center"><Arrow /></span>
        </div>
      </Link>
      <Link href={off.href} className="split-world group relative overflow-hidden rounded-[28px] bg-[#F5F2EA] text-[#0A0A0C] p-7 md:p-10 min-h-[360px] md:min-h-[440px] flex flex-col justify-between focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#D4AF37]">
        <span aria-hidden="true" className="split-world-glow split-world-glow-light" />
        <div className="relative flex items-start justify-between gap-4 text-xs md:text-sm">
          <span className="font-bold tracking-[.2em] uppercase text-[#7A5F12]">{off.tag}</span>
          <span className="text-black/55">{off.meta}</span>
        </div>
        <h2 className="relative font-display font-normal leading-[.86] text-[clamp(64px,8vw,124px)] transition-transform duration-500 group-hover:-translate-y-1 whitespace-pre-line">{off.title}</h2>
        <div className="relative flex flex-wrap items-end justify-between gap-4">
          <p className="max-w-xs text-black/70 leading-relaxed">{off.body}</p>
          <span className="sr-only">{off.cta}</span>
          <span className="split-world-btn h-16 w-16 rounded-full bg-[#0A0A0C] text-[#D4AF37] inline-flex items-center justify-center"><Arrow /></span>
        </div>
      </Link>
    </section>
  )
}
