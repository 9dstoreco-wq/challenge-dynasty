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
    <div className="mb-8 pb-6 border-b border-white/10">
      {eyebrow && <div className="text-[11px] font-semibold uppercase tracking-wider text-[#6FA3D8]">{eyebrow}</div>}
      <h1 className="text-2xl md:text-3xl font-semibold tracking-tight mt-1.5">{title}</h1>
      {subtitle && <p className="text-white/50 text-sm mt-2 max-w-2xl">{subtitle}</p>}
    </div>
  )
}
