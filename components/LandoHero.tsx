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
    const onDown = (e: PointerEvent) => {
      const r = el.getBoundingClientRect()
      el.style.setProperty('--cx', `${e.clientX - r.left}px`)
      el.style.setProperty('--cy', `${e.clientY - r.top}px`)
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

      <div aria-hidden="true" className="lando-dust-layer pointer-events-none absolute inset-0 z-[0]">
        {DUST.map((d, i) => <span key={i} className="lando-dust" style={{ left: d[0], top: d[1], ['--d' as string]: d[2], ['--z' as string]: d[3] }} />)}
      </div>
      <div aria-hidden="true" className="lando-stage pointer-events-none absolute z-[1] right-[-12%] top-16 w-[48%] opacity-80 md:opacity-100 md:right-[1%] md:top-4 md:w-[min(38%,440px)]">
        <div className="lando-halo" />
        <div className="lando-shadow" />
        <div className="lando-paddle-3d">
          <div className="lando-swing"><PaddleD1 /></div>
        </div>
        <div className="lando-ball"><span className="lando-ball-tail" /></div>
      </div>
      <div aria-hidden="true" className="lando-fx pointer-events-none absolute inset-0 z-[5]">
        <span className="lando-ring" /><span className="lando-ring lando-ring-2" />
        {SPARKS.map((a) => <span key={a} className="lando-spark" style={{ ['--a' as string]: `${a}deg` }} />)}
        <span className="lando-flash" />
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

// Particulas de polvo dorado: [left, top, duracion, profundidad]
const DUST: [string, string, string, string][] = [
  ['6%', '82%', '11s', '.4'], ['14%', '60%', '14s', '.8'], ['22%', '90%', '9s', '.5'], ['31%', '70%', '13s', '1'],
  ['39%', '95%', '10s', '.6'], ['47%', '78%', '15s', '.9'], ['55%', '88%', '12s', '.45'], ['63%', '66%', '9.5s', '1'],
  ['70%', '92%', '13.5s', '.7'], ['77%', '74%', '10.5s', '.55'], ['84%', '86%', '14.5s', '.85'], ['92%', '62%', '11.5s', '.5'],
  ['10%', '40%', '16s', '.35'], ['58%', '48%', '15.5s', '.4'], ['88%', '38%', '12.5s', '.65'], ['35%', '30%', '17s', '.3'],
]
const SPARKS = [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330]

function PaddleD1() {
  const id = useId().replace(/:/g, '')
  const n = (k: string) => `${k}${id}`
  const u = (k: string) => `url(#${n(k)})`
  const HEAD = 'M200 30C300 30 362 102 362 205C362 312 292 370 232 404H168C108 370 38 312 38 205C38 102 100 30 200 30Z'
  const FACE = 'M200 70C275 70 322 125 322 205C322 288 268 335 222 360H178C132 335 78 288 78 205C78 125 125 70 200 70Z'
  const holes: [number, number][] = []
  for (let y = 112; y <= 330; y += 26) for (let x = 104; x <= 296; x += 26) {
    const dx = (x - 200) / 112, dy = (y - 212) / 128
    if (dx * dx + dy * dy < 0.86 && !(x > 150 && x < 230 && y > 210 && y < 300)) holes.push([x + ((y / 26) % 2 ? 13 : 0), y])
  }
  return (
    <svg viewBox="0 0 400 600" className="w-full h-auto overflow-visible">
      <defs>
        <linearGradient id={n('gold')} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#FFF4C2" /><stop offset=".22" stopColor="#E9C65A" /><stop offset=".45" stopColor="#8A6418" />
          <stop offset=".62" stopColor="#F6E6B3" /><stop offset=".8" stopColor="#C49A2C" /><stop offset="1" stopColor="#5E430D" />
        </linearGradient>
        <linearGradient id={n('edge')} x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#6B5413" /><stop offset=".5" stopColor="#2A2008" /><stop offset="1" stopColor="#0E0B04" /></linearGradient>
        <pattern id={n('twill')} width="10" height="10" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
          <rect width="10" height="10" fill="#111113" /><rect width="5" height="5" fill="#1F1F23" /><rect x="5" y="5" width="5" height="5" fill="#1F1F23" />
          <rect width="5" height="1" fill="#2B2B30" /><rect x="5" y="5" width="5" height="1" fill="#2B2B30" />
        </pattern>
        <radialGradient id={n('vig')} cx=".5" cy=".45" r=".6"><stop offset=".55" stopColor="#000" stopOpacity="0" /><stop offset="1" stopColor="#000" stopOpacity=".6" /></radialGradient>
        <radialGradient id={n('hole')} cx=".4" cy=".35" r=".7"><stop offset="0" stopColor="#000" /><stop offset=".7" stopColor="#0A0A0C" /><stop offset="1" stopColor="#3A3A40" /></radialGradient>
        <linearGradient id={n('sheen')} x1="0" y1="0" x2="1" y2="0">
          <stop offset=".38" stopColor="#fff" stopOpacity="0" /><stop offset=".48" stopColor="#fff" stopOpacity=".05" />
          <stop offset=".5" stopColor="#fff" stopOpacity=".32" /><stop offset=".53" stopColor="#fff" stopOpacity=".06" /><stop offset=".62" stopColor="#fff" stopOpacity="0" />
        </linearGradient>
        <linearGradient id={n('grip')} x1="0" y1="0" x2="1" y2="0"><stop offset="0" stopColor="#BDB7A8" /><stop offset=".35" stopColor="#FFFFFF" /><stop offset=".7" stopColor="#E9E4D6" /><stop offset="1" stopColor="#A9A394" /></linearGradient>
        <clipPath id={n('head')}><path d={HEAD} /></clipPath>
        <clipPath id={n('face')}><path d={FACE} /></clipPath>
        <filter id={n('glow')} x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6" result="b" /><feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge></filter>
      </defs>
      <g className="lando-trail" stroke="#D4AF37" strokeLinecap="round">
        <path d="M-60 470 120 420" strokeWidth="3" /><path d="M-80 510 90 460" strokeWidth="2" /><path d="M-40 550 140 495" strokeWidth="1.5" /><path d="M-100 440 60 400" strokeWidth="1" />
      </g>
      <g className="lando-paddle">
        {/* grosor 3D: el canto se desplaza al lado contrario de la inclinacion */}
        <g className="lando-edge"><path d={HEAD} fill={u('edge')} /><path d="M168 404 186 446H214L232 404Z" fill={u('edge')} /></g>
        <path d={HEAD} fill={u('twill')} />
        <path d={HEAD} fill={u('vig')} />
        <g clipPath={`url(#${n('face')})`}>
          {holes.map(([x, y]) => <circle key={`${x}-${y}`} cx={x} cy={y} r="5.2" fill={u('hole')} stroke="#D4AF37" strokeOpacity=".22" strokeWidth=".8" />)}
        </g>
        {/* aro dorado metalico + filo de luz interior */}
        <path d={HEAD} fill="none" stroke={u('gold')} strokeWidth="13" />
        <path d={HEAD} fill="none" stroke="#FFF6CF" strokeOpacity=".45" strokeWidth="1.5" transform="translate(200 205) scale(.955) translate(-200 -205)" />
        {/* protector de canto superior */}
        <path d="M108 80Q200 8 292 80" fill="none" stroke="#0A0A0C" strokeWidth="9" strokeLinecap="round" />
        <path d="M108 80Q200 8 292 80" fill="none" stroke={u('gold')} strokeWidth="2" strokeLinecap="round" strokeDasharray="2 10" />
        <text x="200" y="162" textAnchor="middle" fontFamily="Bebas Neue, sans-serif" fontSize="66" fill={u('gold')} letterSpacing="2">D1</text>
        <path className="lando-bolt" filter={`url(#${n('glow')})`} d="M150 222H192L179 258H218L163 318 178 276H140Z" fill={u('gold')} />
        <text x="254" y="300" textAnchor="middle" fontFamily="Bebas Neue, sans-serif" fontSize="25" fill="#F5F2EA" letterSpacing="5" transform="rotate(14 254 300)">DINASTY</text>
        <text x="200" y="345" textAnchor="middle" fontFamily="Inter, sans-serif" fontSize="9" fontWeight="700" fill="#D4AF37" fillOpacity=".7" letterSpacing="3">CARBON 12K</text>
        {/* reflejo especular que barre la cara segun la inclinacion */}
        <g clipPath={`url(#${n('head')})`}><rect className="lando-sheen" x="-300" y="0" width="1000" height="420" fill={u('sheen')} /></g>
        {/* corazon y mango */}
        <path d="M168 404 186 446H214L232 404Z" fill={u('twill')} stroke={u('gold')} strokeWidth="6" strokeLinejoin="round" />
        <path d="M188 410 200 436 212 410Z" fill="#0A0A0C" />
        <rect x="182" y="444" width="36" height="132" rx="10" fill={u('grip')} />
        <g stroke="#9E988A" strokeOpacity=".7" strokeWidth="2.2">
          {[456, 472, 488, 504, 520, 536, 552].map((y) => <path key={y} d={`M182 ${y} 218 ${y + 13}`} />)}
        </g>
        <rect x="178" y="568" width="44" height="20" rx="7" fill={u('gold')} />
        <text x="200" y="583" textAnchor="middle" fontFamily="Bebas Neue, sans-serif" fontSize="13" fill="#0A0A0C">D</text>
      </g>
    </svg>
  )
}
