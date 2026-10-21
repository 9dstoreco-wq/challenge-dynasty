'use client'
import { useEffect, useId, useRef, type ReactNode } from 'react'

// Portada estilo "piloto de elite" (inspirada en landonorris.com):
// - Lupa dorada que sigue el cursor y revela las letras invertidas (negro sobre dorado).
// - Pala D1 en 3D que se inclina hacia el cursor y gira con el scroll.
// - Clic / toque = smash: la pala hace swing y dispara la pelota.
// - En pantallas tactiles la lupa recorre las letras sola.
// Todo se mueve con variables CSS desde un solo requestAnimationFrame (sin re-render de React).
export default function LandoHero({ kicker, sideNote, lines, subtitle, actions, children }: {
  kicker: string
  sideNote: string
  lines: [string, string, string]
  subtitle: string
  actions: ReactNode
  children?: ReactNode
}) {
  const hero = useRef<HTMLElement>(null)
  const type = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const el = hero.current, tp = type.current
    if (!el || !tp) return
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
    const touch = window.matchMedia('(hover: none)').matches
    // objetivo (t) y valor suavizado (c): tilt -1..1, lupa en px, scroll 0..1
    const t = { sx: 0, sy: 0, lx: 0, ly: 0 }, c = { sx: 0, sy: 0, lx: 0, ly: 0, sp: 0 }
    let raf = 0, visible = true
    const start = performance.now()

    const onMove = (e: PointerEvent) => {
      if (e.pointerType === 'touch') return
      const r = el.getBoundingClientRect(), tr = tp.getBoundingClientRect()
      t.sx = ((e.clientX - r.left) / r.width) * 2 - 1
      t.sy = ((e.clientY - r.top) / r.height) * 2 - 1
      t.lx = e.clientX - tr.left
      t.ly = e.clientY - tr.top
      // la lupa solo aparece sobre las letras (con un margen), no en el espacio vacio
      const m = 40
      let right = tr.left
      tp.querySelectorAll('h1 .lando-l1, h1 .lando-l2, h1 .lando-l3').forEach((n) => { right = Math.max(right, n.getBoundingClientRect().right) })
      const over = e.clientX > tr.left - m && e.clientX < right + m && e.clientY > tr.top - m && e.clientY < tr.bottom + m
      el.dataset.hover = over ? '1' : '0'
    }
    const onLeave = () => { t.sx = 0; t.sy = 0; if (!touch) el.dataset.hover = '0' }
    const onDown = () => {
      el.dataset.swing = '0'
      void el.offsetWidth // reinicia la animacion si se hace clic seguido
      el.dataset.swing = '1'
    }
    const onEnd = (e: AnimationEvent) => { if (e.animationName === 'lando-shot') el.dataset.swing = '0' }

    const tick = (now: number) => {
      if (touch) {
        // recorrido automatico de la lupa (curva de Lissajous) sobre las letras
        const s = (now - start) / 1000, w = tp.clientWidth, h = tp.clientHeight
        t.lx = w * (0.34 + 0.26 * Math.sin(s * 0.7))
        t.ly = h * (0.5 + 0.34 * Math.sin(s * 1.1 + 1))
        t.sx = Math.sin(s * 0.5) * 0.6
        t.sy = Math.cos(s * 0.4) * 0.4
      }
      const r = el.getBoundingClientRect()
      const sp = Math.min(1, Math.max(0, -r.top / Math.max(1, r.height)))
      c.sx += (t.sx - c.sx) * 0.08
      c.sy += (t.sy - c.sy) * 0.08
      c.lx += (t.lx - c.lx) * 0.16
      c.ly += (t.ly - c.ly) * 0.16
      c.sp += (sp - c.sp) * 0.12
      el.style.setProperty('--sx', c.sx.toFixed(4))
      el.style.setProperty('--sy', c.sy.toFixed(4))
      el.style.setProperty('--sp', c.sp.toFixed(4))
      el.style.setProperty('--lx', `${c.lx.toFixed(1)}px`)
      el.style.setProperty('--ly', `${c.ly.toFixed(1)}px`)
      raf = visible ? requestAnimationFrame(tick) : 0
    }
    const io = new IntersectionObserver(([en]) => {
      visible = en.isIntersecting
      if (visible && !raf) raf = requestAnimationFrame(tick)
    })
    io.observe(el)
    if (touch) { el.dataset.hover = '1'; const tr = tp.getBoundingClientRect(); c.lx = tr.width / 2; c.ly = tr.height / 2 }
    el.addEventListener('pointermove', onMove)
    el.addEventListener('pointerleave', onLeave)
    el.addEventListener('pointerdown', onDown)
    el.addEventListener('animationend', onEnd)
    raf = requestAnimationFrame(tick)
    return () => {
      cancelAnimationFrame(raf); io.disconnect()
      el.removeEventListener('pointermove', onMove)
      el.removeEventListener('pointerleave', onLeave)
      el.removeEventListener('pointerdown', onDown)
      el.removeEventListener('animationend', onEnd)
    }
  }, [])

  const renderLines = (lens: boolean) => (
    <>
      <span className={lens ? 'block' : 'reveal block'}><span className="lando-l1 inline-block">{lines[0]}</span></span>
      <span className={lens ? 'block' : 'reveal block'} style={lens ? undefined : { ['--i' as string]: 1 }}><span className="lando-l2 lando-outline inline-block pl-[10%]">{lines[1]}</span></span>
      <span className={lens ? 'block' : 'reveal block'} style={lens ? undefined : { ['--i' as string]: 2 }}><span className="lando-l3 inline-block text-[#D4AF37]">{lines[2]}</span></span>
    </>
  )

  return (
    <section ref={hero} data-hover="0" data-swing="0" className="lando-hero relative overflow-hidden isolate select-none px-1 pt-2 pb-10 md:pb-14">
      <div aria-hidden="true" className="lando-glow" />
      <div className="relative z-[4] flex flex-wrap justify-between gap-3 text-xs md:text-sm font-bold tracking-[.25em] uppercase text-white/55">
        <span className="text-[#D4AF37]">{kicker}</span>
        <span>{sideNote}</span>
      </div>

      <div aria-hidden="true" className="lando-stage pointer-events-none absolute z-[1] right-[-12%] top-16 w-[48%] opacity-80 md:opacity-100 md:right-[1%] md:top-4 md:w-[min(38%,440px)]">
        <div className="lando-paddle-3d">
          <div className="lando-swing"><PaddleD1 /></div>
        </div>
        <div className="lando-ball" />
      </div>

      <div ref={type} className="lando-type relative mt-6 md:mt-10">
        <h1 className="relative z-[2] font-display font-normal leading-[.84] tracking-tight text-[clamp(88px,15vw,220px)]">
          {renderLines(false)}
        </h1>
        <div aria-hidden="true" className="lando-lens">
          <div className="font-display font-normal leading-[.84] tracking-tight text-[clamp(88px,15vw,220px)]">
            {renderLines(true)}
          </div>
        </div>
      </div>

      <div className="reveal relative z-[4] mt-8 md:mt-10 flex flex-wrap items-center justify-between gap-6" style={{ ['--i' as string]: 3 }}>
        <p className="max-w-md text-base md:text-lg leading-relaxed text-white/75">{subtitle}</p>
        <div className="flex flex-wrap gap-3">{actions}</div>
      </div>
      {children ? <div className="relative z-[4]">{children}</div> : null}
    </section>
  )
}

function PaddleD1() {
  const id = useId().replace(/:/g, '')
  const gold = `g${id}`, carbon = `c${id}`, holes = `h${id}`, face = `f${id}`
  return (
    <svg viewBox="0 0 400 600" className="w-full h-auto overflow-visible">
      <defs>
        <linearGradient id={gold} x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#F7E29A" /><stop offset=".45" stopColor="#D4AF37" /><stop offset="1" stopColor="#6B5413" /></linearGradient>
        <pattern id={carbon} width="12" height="12" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="12" height="12" fill="#141416" /><rect width="6" height="6" fill="#1D1D20" /><rect x="6" y="6" width="6" height="6" fill="#1D1D20" /></pattern>
        <pattern id={holes} width="28" height="28" patternUnits="userSpaceOnUse"><circle cx="14" cy="14" r="5" fill="#0A0A0C" stroke="#2A2A2E" /></pattern>
        <clipPath id={face}><path d="M200 70C275 70 322 125 322 205C322 288 268 335 222 360H178C132 335 78 288 78 205C78 125 125 70 200 70Z" /></clipPath>
      </defs>
      <g className="lando-trail" stroke="#D4AF37" strokeLinecap="round">
        <path d="M-60 470 120 420" strokeWidth="3" /><path d="M-80 510 90 460" strokeWidth="2" /><path d="M-40 550 140 495" strokeWidth="1.5" />
      </g>
      <g className="lando-paddle">
        <path d="M200 30C300 30 362 102 362 205C362 312 292 370 232 404H168C108 370 38 312 38 205C38 102 100 30 200 30Z" fill={`url(#${carbon})`} stroke={`url(#${gold})`} strokeWidth="12" />
        <g clipPath={`url(#${face})`}><rect x="60" y="60" width="280" height="320" fill={`url(#${holes})`} /></g>
        <path className="lando-bolt" d="M150 228H190L178 262H214L162 318 176 278H140Z" fill={`url(#${gold})`} />
        <text x="200" y="168" textAnchor="middle" fontFamily="Bebas Neue, sans-serif" fontSize="64" fill={`url(#${gold})`} letterSpacing="2">D1</text>
        <text x="252" y="300" textAnchor="middle" fontFamily="Bebas Neue, sans-serif" fontSize="26" fill="#F5F2EA" letterSpacing="4">DINASTY</text>
        <path d="M168 404 186 446H214L232 404Z" fill={`url(#${carbon})`} stroke={`url(#${gold})`} strokeWidth="6" strokeLinejoin="round" />
        <rect x="183" y="444" width="34" height="132" rx="9" fill="#F5F2EA" />
        <g stroke="#CFCABD" strokeWidth="2"><path d="M183 462 217 474" /><path d="M183 482 217 494" /><path d="M183 502 217 514" /><path d="M183 522 217 534" /><path d="M183 542 217 554" /></g>
        <rect x="179" y="570" width="42" height="16" rx="6" fill={`url(#${gold})`} />
      </g>
    </svg>
  )
}
