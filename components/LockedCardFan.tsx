// Tres cartas bloqueadas en abanico (para quien todavia no tiene cartas o no ha entrado).
const FAN = [
  { r: 'rare', rot: '-14deg', x: '-46%', y: '18px', d: '0s' },
  { r: 'legendary', rot: '0deg', x: '0%', y: '0px', d: '-2s' },
  { r: 'epic', rot: '14deg', x: '46%', y: '18px', d: '-4s' },
] as const

export default function LockedCardFan({ label }: { label: string }) {
  return (
    <div className="relative mx-auto h-[270px] w-[min(360px,100%)] md:h-[340px] md:w-[420px]" role="img" aria-label={label}>
      {FAN.map((c) => (
        <div
          key={c.r}
          className="fan-card absolute left-1/2 top-0 w-[140px] md:w-[190px]"
          style={{ ['--rot' as string]: c.rot, ['--fx' as string]: c.x, ['--fy' as string]: c.y, animationDelay: c.d }}
        >
          <div className={`dcard r-${c.r}`}>
            <div className="dcard-body">
              <div className="dcard-in grid place-items-center">
                <div className="font-display text-8xl" style={{ color: 'var(--r)', textShadow: '0 0 30px var(--r)' }}>?</div>
                <svg className="absolute bottom-6" width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" style={{ color: 'var(--r)' }}>
                  <rect x="4" y="11" width="16" height="10" rx="2" /><path d="M8 11V7a4 4 0 0 1 8 0v4" />
                </svg>
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}
