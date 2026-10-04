// Barra de XP estilo videojuego. Solo presentacion: el ancho es un porcentaje 0-100.
export default function XpBar({ percent, className = '' }: { percent: number; className?: string }) {
  const p = Math.max(0, Math.min(100, Number.isFinite(percent) ? percent : 0))
  return (
    <div className={`xp-track ${className}`} role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(p)}>
      <div className="xp-fill" style={{ ['--xp' as string]: `${p}%` }} />
    </div>
  )
}
