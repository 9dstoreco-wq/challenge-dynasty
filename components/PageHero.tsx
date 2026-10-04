export default function PageHero({children, badge = true, wide = false, className = ''}: {children: React.ReactNode; badge?: boolean; wide?: boolean; className?: string}) {
  return (
    <section className={`hud-corners shine rounded-none border border-[#D4AF37]/25 bg-gradient-to-br from-[#1E1C10] via-[#141416] to-[#0A0A0C] p-6 md:p-10 overflow-hidden relative mb-7 [clip-path:polygon(22px_0,100%_0,100%_calc(100%-22px),calc(100%-22px)_100%,0_100%,0_22px)] ${className}`}>
      <div className="absolute -right-16 -top-16 h-56 w-56 rounded-full bg-gold-400/15 blur-3xl" />
      <div className="absolute inset-x-0 bottom-0 h-px bg-gradient-to-r from-transparent via-[#D4AF37]/70 to-transparent" />
      {badge && <img src="/dynasty-badge.png" alt="" className="float-y hidden md:block absolute right-6 top-1/2 -translate-y-1/2 w-40 h-40 object-contain opacity-[0.2] pointer-events-none select-none" />}
      <div className={`relative reveal ${wide ? '' : 'max-w-3xl'}`}>{children}</div>
    </section>
  )
}
