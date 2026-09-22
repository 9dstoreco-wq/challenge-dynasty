export default function PageHero({children, badge = true, wide = false, className = ''}: {children: React.ReactNode; badge?: boolean; wide?: boolean; className?: string}) {
  return (
    <section className={`rounded-3xl border border-[#D4AF37]/20 bg-gradient-to-br from-[#1B1A12] via-[#161616] to-[#0A0A0C] p-6 md:p-10 overflow-hidden relative mb-7 ${className}`}>
      <div className="absolute -right-16 -top-16 h-56 w-56 rounded-full bg-gold-400/10 blur-3xl" />
      {badge && <img src="/dynasty-badge.png" alt="" className="hidden md:block absolute right-6 top-1/2 -translate-y-1/2 w-40 h-40 object-contain opacity-[0.14] pointer-events-none select-none" />}
      <div className={`relative ${wide ? '' : 'max-w-3xl'}`}>{children}</div>
    </section>
  )
}
