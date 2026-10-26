// Generador de cuadros de torneo (puro, sin red ni base de datos — fácil de probar).
// Hoy soporta: eliminación simple, round robin (todos contra todos), grupos+eliminación
// (round robin por grupo + un cuadro de eliminación armado después, con los que clasifican),
// y King of the Court / escalera de canchas (buildLadderInitialRound + buildLadderNextRound).
// Formatos pendientes: doble eliminación, Americano, Mexicano, cuadro de consolación y sistema
// suizo — ver el plan de "cubrir todos los formatos de torneo" para el orden de construcción.

export type FixtureSpec = {
  round: number
  slot: number
  sideA: string | null
  sideB: string | null
  /** true cuando un lado está vacío (bye) y el otro avanza automáticamente sin jugar */
  isBye: boolean
}

/**
 * Arma las rondas de un cuadro de eliminación simple a partir de los inscritos, en el orden
 * recibido (ya debe venir ordenado por seed/antigüedad de inscripción). Si no es potencia de 2,
 * rellena con "bye": ese inscrito avanza directo a la siguiente ronda sin jugar.
 * Devuelve un arreglo de rondas; cada ronda es un arreglo de fixtures con round/slot ya listos
 * para enlazar con la ronda siguiente (slot = posición dentro de la ronda).
 */
export function buildSingleEliminationRounds(entryIds: string[]): FixtureSpec[][] {
  const n = entryIds.length
  if (n < 2) throw new Error('NOT_ENOUGH_ENTRIES')

  let size = 1
  while (size < n) size *= 2
  const slots: (string | null)[] = Array.from({ length: size }, (_, i) => (i < n ? entryIds[i] : null))

  const rounds: FixtureSpec[][] = []
  let current = slots
  let round = 1
  while (current.length >= 2) {
    const roundFixtures: FixtureSpec[] = []
    for (let i = 0; i < current.length; i += 2) {
      const sideA = current[i]
      const sideB = current[i + 1]
      const isBye = Boolean(sideA) !== Boolean(sideB) // exactamente uno de los dos es null
      roundFixtures.push({ round, slot: i / 2, sideA, sideB, isBye })
    }
    rounds.push(roundFixtures)
    current = roundFixtures.map((f) => {
      if (f.isBye) return f.sideA ?? f.sideB
      return null // se decide cuando se juegue el partido
    })
    round += 1
  }
  return rounds
}

export type RoundRobinPair = { round: number; sideA: string; sideB: string }

/**
 * Arma el calendario de un round robin (todos contra todos) con el método del círculo:
 * cada inscrito juega contra todos los demás una vez, repartido en la menor cantidad de rondas
 * posible. Con cantidad impar de inscritos, uno descansa cada ronda (no genera fixture ese turno).
 */
export function buildRoundRobinPairs(entryIds: string[]): RoundRobinPair[] {
  const n0 = entryIds.length
  if (n0 < 2) throw new Error('NOT_ENOUGH_ENTRIES')

  const ids: (string | null)[] = n0 % 2 !== 0 ? [...entryIds, null] : [...entryIds]
  const n = ids.length
  const totalRounds = n - 1
  const half = n / 2

  const pairs: RoundRobinPair[] = []
  let arr = ids.slice()
  for (let r = 0; r < totalRounds; r++) {
    for (let i = 0; i < half; i++) {
      const a = arr[i]
      const b = arr[n - 1 - i]
      if (a && b) pairs.push({ round: r + 1, sideA: a, sideB: b })
    }
    const fixed = arr[0]
    const rest = arr.slice(1)
    const last = rest.pop()
    if (last !== undefined) rest.unshift(last)
    arr = [fixed, ...rest]
  }
  return pairs
}

/**
 * Reparte los inscritos en grupos para la fase de "grupos + eliminación", intercalando por
 * posición (como una baraja) para que los mejores puestos (seed) queden repartidos entre los
 * grupos en vez de amontonados en uno solo. Descarta cualquier grupo que quede con menos de 2.
 */
export function splitIntoGroups(entryIds: string[], groupSize: number): string[][] {
  if (entryIds.length < 2) throw new Error('NOT_ENOUGH_ENTRIES')
  if (groupSize < 2) throw new Error('INVALID_GROUP_SIZE')
  const groupCount = Math.max(1, Math.round(entryIds.length / groupSize))
  const groups: string[][] = Array.from({ length: groupCount }, () => [])
  entryIds.forEach((id, i) => groups[i % groupCount].push(id))
  return groups.filter((g) => g.length >= 2)
}

/**
 * De los que clasificaron (ya ordenados grupo por grupo, 1er puesto de cada grupo primero, luego
 * los 2dos puestos, etc.) arma el orden de entrada al cuadro de eliminación, intercalando los
 * grupos para que dos clasificados del mismo grupo no se encuentren en la primera ronda cuando
 * eso se puede evitar.
 */
export function seedKnockoutFromGroups(qualifiersByGroup: string[][]): string[] {
  const seeded: string[] = []
  const maxRank = Math.max(...qualifiersByGroup.map((g) => g.length))
  for (let rank = 0; rank < maxRank; rank++) {
    for (const group of qualifiersByGroup) {
      if (group[rank]) seeded.push(group[rank])
    }
  }
  return seeded
}

/**
 * King of the Court / "escalera de canchas": a diferencia de los otros formatos, las rondas
 * NO se arman todas de una vez — cada ronda depende de quién ganó/perdió en la anterior, así que
 * se arma una por una (ver generateNextLadderRound en tournamentBracketActions.ts). Total de
 * rondas de una "noche" de escalera; se puede ajustar más adelante si hace falta por torneo.
 */
export const LADDER_TOTAL_ROUNDS = 4

/**
 * Ronda 1: reparte los inscritos (ya ordenados por seed/antigüedad) de a 2 por cancha —
 * cancha 1 es la "mejor" (arriba del todo). Si la cantidad es impar, la última cancha de la
 * ronda queda con un solo inscrito (bye): no juega, pero para el cálculo de la ronda siguiente
 * se trata como si hubiera perdido (no sube de cancha sin jugar).
 */
export function buildLadderInitialRound(entryIds: string[]): FixtureSpec[] {
  if (entryIds.length < 2) throw new Error('NOT_ENOUGH_ENTRIES')
  const fixtures: FixtureSpec[] = []
  let court = 1
  for (let i = 0; i < entryIds.length; i += 2) {
    const sideA: string | null = entryIds[i]
    const sideB: string | null = entryIds[i + 1] ?? null
    fixtures.push({ round: 1, slot: court, sideA, sideB, isBye: !sideB })
    court += 1
  }
  return fixtures
}

export type LadderCourtResult = {
  /** Número de cancha (1 = la mejor) en la ronda que ya se jugó. */
  court: number
  winnerEntryId: string
  /** null cuando esa cancha fue un bye (nadie para enfrentar). */
  loserEntryId: string | null
}

/**
 * Ronda siguiente: el ganador de cada cancha sube una cancha (cancha - 1; el de la cancha 1 se
 * queda), el perdedor baja una cancha (cancha + 1; el de la última cancha se queda). Como cada
 * cancha intermedia manda a alguien hacia arriba y hacia abajo, y recibe exactamente uno de cada
 * lado, las canchas siempre quedan con 2 inscritos — sin que sobre ni falte nadie.
 */
export function buildLadderNextRound(roundNumber: number, previousResults: LadderCourtResult[]): FixtureSpec[] {
  if (previousResults.length === 0) throw new Error('NOT_ENOUGH_ENTRIES')
  const maxCourt = Math.max(...previousResults.map((r) => r.court))

  const byNewCourt = new Map<number, string[]>()
  const place = (courtNumber: number, entryId: string) => {
    const list = byNewCourt.get(courtNumber) ?? []
    list.push(entryId)
    byNewCourt.set(courtNumber, list)
  }

  for (const r of previousResults) {
    const upCourt = r.court === 1 ? 1 : r.court - 1
    place(upCourt, r.winnerEntryId)
    if (r.loserEntryId) {
      const downCourt = r.court === maxCourt ? maxCourt : r.court + 1
      place(downCourt, r.loserEntryId)
    }
  }

  const fixtures: FixtureSpec[] = []
  const sortedCourts = Array.from(byNewCourt.keys()).sort((a, b) => a - b)
  for (const court of sortedCourts) {
    const occupants = byNewCourt.get(court) ?? []
    const sideA: string | null = occupants[0] ?? null
    const sideB: string | null = occupants[1] ?? null
    fixtures.push({ round: roundNumber, slot: court, sideA, sideB, isBye: !sideA || !sideB })
  }
  return fixtures
}
