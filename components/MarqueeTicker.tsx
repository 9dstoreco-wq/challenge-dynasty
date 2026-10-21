// Franja dorada en movimiento (estilo Lando). Se duplica la lista para que el loop no tenga salto.
export default function MarqueeTicker({ items }: { items: string[] }) {
  const loop = [...items, ...items]
  return (
    <div className="lando-ticker -mx-4 md:-mx-6 my-2 overflow-hidden bg-[#D4AF37] py-3 text-[#0A0A0C]" aria-label={items.join(' · ')} role="marquee">
      <div aria-hidden="true" className="lando-track flex w-max gap-10 whitespace-nowrap font-display text-4xl md:text-5xl leading-none">
        {loop.map((w, i) => (
          <span key={i} className="inline-flex items-center gap-10">
            {w}
            <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><path d="M13 2 4 14h7l-1 8 9-12h-7z" /></svg>
          </span>
        ))}
      </div>
    </div>
  )
}
