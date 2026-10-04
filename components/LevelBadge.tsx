// Insignia hexagonal de nivel (estilo FIFA / esports).
export default function LevelBadge({ level, size = 72, className = '' }: { level: number | string; size?: number; className?: string }) {
  return (
    <div className={`relative grid place-items-center ${className}`} style={{ width: size, height: size }}>
      <span className="pulse-ring" aria-hidden />
      <div className="hex absolute inset-0" aria-hidden />
      <span className="relative font-display font-black leading-none" style={{ fontSize: size * 0.46, color: '#0A0A0C' }}>{level}</span>
    </div>
  )
}
