// Reemplazo sobrio de PageHero para la cara de negocio: sin degradado dorado, sin blur ni
// marca de agua -- un encabezado simple, como el de un panel administrativo cualquiera.
export default function BusinessHeader({
  eyebrow,
  title,
  subtitle,
}: {
  eyebrow?: string
  title: string
  subtitle?: string
}) {
  return (
    <div className="mb-8 border-b border-white/10 border-l-4 border-l-[#6FA3D8]/50 pb-6 pl-5">
      {eyebrow && <div className="text-[11px] font-semibold uppercase tracking-[.2em] text-[#6FA3D8]">{eyebrow}</div>}
      <h1 className="mt-2 text-4xl font-black leading-[0.98] tracking-tight md:text-5xl">{title}</h1>
      {subtitle && <p className="text-white/50 text-sm mt-2 max-w-2xl">{subtitle}</p>}
    </div>
  )
}
