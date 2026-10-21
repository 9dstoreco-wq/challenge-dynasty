'use client'
import { useId, useRef, type ReactNode } from 'react'

// Portada estilo "piloto de elite": tipografia gigante apilada, brillo dorado
// que sigue el cursor y la pala D1 flotando entre las letras.
// El brillo se mueve con variables CSS (sin re-render de React por cada mouse move).
export default function LandoHero({ kicker, sideNote, lines, subtitle, actions, children }: {
  kicker: string
  sideNote: string
  lines: [string, string, string]
  subtitle: string
  actions: ReactNode
  children?: ReactNode
}) {
  const ref = useRef<HTMLElement>(null)
  const onMove = (e: React.PointerEvent<HTMLElement>) => {
    const el = ref.current
    if (!el || e.pointerType === 'touch') return
    const r = el.getBoundingClientRect()
    el.style.setProperty('--gx', `${e.clientX - r.left}px`)
    el.style.setProperty('--gy', `${e.clientY - r.top}px`)
  }
  return (
    <section ref={ref} onPointerMove={onMove} className="lando-hero relative overflow-hidden isolate px-1 pt-2 pb-10 md:pb-14">
      <div aria-hidden="true" className="lando-glow" />
      <div className="relative z-[1] flex flex-wrap justify-between gap-3 text-xs md:text-sm font-bold tracking-[.25em] uppercase text-white/55">
        <span className="text-[#D4AF37]">{kicker}</span>
        <span>{sideNote}</span>
      </div>
      <div aria-hidden="true" className="pointer-events-none absolute right-[2%] top-6 z-[1] hidden md:block w-[min(38%,440px)]">
        <PaddleD1 />
      </div>
      <h1 className="relative mt-6 md:mt-10 font-display font-normal leading-[.84] tracking-tight text-[clamp(88px,15vw,220px)]">
        <span className="reveal block relative z-[0]">{lines[0]}</span>
        <span className="reveal lando-outline block relative z-[2] pl-[10%]" style={{ ['--i' as string]: 1 }}>{lines[1]}</span>
        <span className="reveal block relative z-[0] text-[#D4AF37]" style={{ ['--i' as string]: 2 }}>{lines[2]}</span>
      </h1>
      <div className="reveal relative z-[2] mt-8 md:mt-10 flex flex-wrap items-center justify-between gap-6" style={{ ['--i' as string]: 3 }}>
        <p className="max-w-md text-base md:text-lg leading-relaxed text-white/75">{subtitle}</p>
        <div className="flex flex-wrap gap-3">{actions}</div>
      </div>
      {children ? <div className="relative z-[2]">{children}</div> : null}
    </section>
  )
}

function PaddleD1() {
  const id = useId().replace(/:/g, '')
  const gold = `g${id}`, carbon = `c${id}`, holes = `h${id}`, ball = `b${id}`, face = `f${id}`
  return (
    <svg viewBox="0 0 400 600" className="w-full h-auto overflow-visible">
      <defs>
        <linearGradient id={gold} x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#F7E29A" /><stop offset=".45" stopColor="#D4AF37" /><stop offset="1" stopColor="#6B5413" /></linearGradient>
        <pattern id={carbon} width="12" height="12" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="12" height="12" fill="#141416" /><rect width="6" height="6" fill="#1D1D20" /><rect x="6" y="6" width="6" height="6" fill="#1D1D20" /></pattern>
        <pattern id={holes} width="28" height="28" patternUnits="userSpaceOnUse"><circle cx="14" cy="14" r="5" fill="#0A0A0C" stroke="#2A2A2E" /></pattern>
        <radialGradient id={ball} cx=".35" cy=".35" r=".7"><stop offset="0" stopColor="#FFF6CF" /><stop offset=".5" stopColor="#E8C752" /><stop offset="1" stopColor="#8A6B16" /></radialGradient>
        <clipPath id={face}><path d="M200 70C275 70 322 125 322 205C322 288 268 335 222 360H178C132 335 78 288 78 205C78 125 125 70 200 70Z" /></clipPath>
      </defs>
      <g stroke="#D4AF37" strokeLinecap="round" opacity=".5">
        <path d="M-60 470 120 420" strokeWidth="3" /><path d="M-80 510 90 460" strokeWidth="2" /><path d="M-40 550 140 495" strokeWidth="1.5" />
      </g>
      <g className="lando-paddle">
        <path d="M200 30C300 30 362 102 362 205C362 312 292 370 232 404H168C108 370 38 312 38 205C38 102 100 30 200 30Z" fill={`url(#${carbon})`} stroke={`url(#${gold})`} strokeWidth="12" />
        <g clipPath={`url(#${face})`}><rect x="60" y="60" width="280" height="320" fill={`url(#${holes})`} /></g>
        <path d="M150 228H190L178 262H214L162 318 176 278H140Z" fill={`url(#${gold})`} />
        <text x="200" y="168" textAnchor="middle" fontFamily="Bebas Neue, sans-serif" fontSize="64" fill={`url(#${gold})`} letterSpacing="2">D1</text>
        <text x="252" y="300" textAnchor="middle" fontFamily="Bebas Neue, sans-serif" fontSize="26" fill="#F5F2EA" letterSpacing="4">DINASTY</text>
        <path d="M168 404 186 446H214L232 404Z" fill={`url(#${carbon})`} stroke={`url(#${gold})`} strokeWidth="6" strokeLinejoin="round" />
        <rect x="183" y="444" width="34" height="132" rx="9" fill="#F5F2EA" />
        <g stroke="#CFCABD" strokeWidth="2"><path d="M183 462 217 474" /><path d="M183 482 217 494" /><path d="M183 502 217 514" /><path d="M183 522 217 534" /><path d="M183 542 217 554" /></g>
        <rect x="179" y="570" width="42" height="16" rx="6" fill={`url(#${gold})`} />
      </g>
      <circle cx="70" cy="110" r="34" fill={`url(#${ball})`} />
      <circle cx="70" cy="110" r="70" fill="none" stroke="#D4AF37" opacity=".35" />
    </svg>
  )
}
