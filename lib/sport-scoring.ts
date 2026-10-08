// Como se registra y valida el marcador segun el deporte: por sets (padel, tenis y demas deportes
// de sets), un solo marcador (futbol, basquet) o solo el ganador (carrera y deportes sin marcador).
// Este modulo es la UNICA fuente de esa logica -- antes vivia solo dentro de MatchResultForm.tsx
// (el cliente), así que el servidor no tenía forma de volver a calcular el ganador a partir de los
// marcadores y confiaba por completo en lo que mandara el formulario.
export type ScoreMode = 'sets' | 'points' | 'winner'

// Deportes que ya existen hoy en produccion (basketball, football, padel, running, tennis) quedan
// cubiertos, y se deja la lista de "sets" abierta a los demas deportes de sets que puedan agregarse
// despues (volleyball, tenis de mesa, etc.) para que no caigan por accidente en modo "solo ganador"
// sin marcador que validar.
const POINTS_SLUGS = new Set(['football', 'basketball'])
const SETS_SLUGS = new Set(['padel', 'tennis', 'volleyball', 'table-tennis'])

export function modeForSlug(slug?: string | null): ScoreMode {
  if (slug && POINTS_SLUGS.has(slug)) return 'points'
  if (!slug || SETS_SLUGS.has(slug)) return 'sets'
  return 'winner'
}

export function parseScore(score: string): [number, number] | null {
  const m = score.trim().match(/^(\d+)[-:](\d+)$/)
  return m ? [Number(m[1]), Number(m[2])] : null
}

// Lado 0 = quien registro el reto (creador), lado 1 = el rival -- el mismo orden que usa el
// formulario (el primer numero de cada marcador es siempre del creador). Devuelve null cuando el
// marcador no alcanza para decidir un ganador (empate, formato invalido, o modo "winner" sin
// marcador que revisar) -- en ese caso no hay nada que contrastar contra el ganador declarado.
export function computeWinnerSide(mode: ScoreMode, set1: string, set2?: string | null, set3?: string | null): 0 | 1 | null {
  if (mode === 'winner') return null
  if (mode === 'points') {
    const p = parseScore(set1 ?? '')
    if (!p || p[0] === p[1]) return null
    return p[0] > p[1] ? 0 : 1
  }
  const wins = [0, 0]
  for (const sc of [set1, set2, set3]) {
    if (!sc) continue
    const p = parseScore(sc)
    if (p && p[0] !== p[1]) wins[p[0] > p[1] ? 0 : 1] += 1
  }
  if (wins[0] === wins[1]) return null
  return wins[0] > wins[1] ? 0 : 1
}
