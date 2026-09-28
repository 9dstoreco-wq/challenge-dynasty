import Link from 'next/link'

type Section = { title: string; body: string }

function renderBody(body: string) {
  return body.split('\n').map((line, i) => {
    const trimmed = line.trim()
    if (trimmed.startsWith('- ')) {
      return (
        <li key={i} className="ml-4 list-disc text-white/60 leading-relaxed">
          {trimmed.slice(2)}
        </li>
      )
    }
    return (
      <p key={i} className="text-white/60 leading-relaxed">
        {line}
      </p>
    )
  })
}

export default function LegalDocument({
  title,
  lastUpdated,
  intro,
  sections,
  disclaimer,
  backHomeLabel,
  crossLinkHref,
  crossLinkLabel,
  eyebrow,
}: {
  title: string
  lastUpdated: string
  intro: string
  sections: Section[]
  disclaimer: string
  backHomeLabel: string
  crossLinkHref: string
  crossLinkLabel: string
  eyebrow: string
}) {
  return (
    <main className="min-h-screen bg-[#0A0A0C] text-white">
      <div className="max-w-3xl mx-auto px-4 md:px-6 py-10">
        <section className="rounded-3xl border border-[#D4AF37]/20 bg-gradient-to-br from-[#1B1A12] via-[#161616] to-[#0A0A0C] p-6 md:p-10 overflow-hidden relative mb-8">
          <div className="absolute -right-16 -top-16 h-56 w-56 rounded-full bg-gold-400/10 blur-3xl" />
          <div className="relative">
            <div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">{eyebrow}</div>
            <h1 className="text-3xl md:text-5xl font-display font-black tracking-wide mt-2">{title}</h1>
            <p className="text-white/45 mt-2 text-sm">{lastUpdated}</p>
          </div>
        </section>

        <p className="text-white/70 leading-relaxed mb-8">{intro}</p>

        <div className="space-y-8">
          {sections.map((s, idx) => (
            <section key={idx} className="rounded-2xl border border-white/10 bg-[#141414] p-5 md:p-6">
              <h2 className="text-lg md:text-xl font-display font-black tracking-wide text-[#D4AF37] mb-3">
                {s.title}
              </h2>
              <div className="space-y-1.5">{renderBody(s.body)}</div>
            </section>
          ))}
        </div>

        <p className="text-white/40 text-sm leading-relaxed mt-8 italic">{disclaimer}</p>

        <div className="flex flex-wrap gap-4 mt-8 pt-6 border-t border-white/10">
          <Link href="/" className="rounded-xl bg-white/10 border border-white/10 px-5 py-3 font-black text-sm">
            {backHomeLabel}
          </Link>
          <Link
            href={crossLinkHref}
            className="rounded-xl bg-[#D4AF37]/10 border border-[#D4AF37]/30 text-[#D4AF37] px-5 py-3 font-black text-sm"
          >
            {crossLinkLabel}
          </Link>
        </div>
      </div>
    </main>
  )
}
