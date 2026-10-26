// Generador de cuadros de torneo (puro, sin red ni base de datos — fácil de probar).
// Hoy soporta: eliminación simple, round robin (todos contra todos), grupos+eliminación
// (round robin por grupo + un cuadro de eliminación armado después, con los que clasifican),
// King of the Court / escalera de canchas (buildLadderInitialRound + buildLadderNextRound),
// Americano (buildAmericanoRounds) y Mexicano (buildMexicanoInitialRound + buildMexicanoNextRound).
// A diferencia de los demás formatos, Americano y Mexicano no usan tournament_fixtures (esa tabla
// asume pareja FIJA por lado) — usan tournament_rotation_matches, porque la pareja cambia cada
// ronda y el puntaje es por JUGADOR, no por pareja (ver record_rotation_match_result y
// generateNextMexicanoRound/generateBracket en tournamentBracketActions.ts).
// Formatos pendientes: doble eliminación, cuadro de consolación y sistema suizo.

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

export type RotationFixtureSpec = {
  round: number
  court: number
  sideA: [string, string]
  sideB: [string, string]
}

// Dentro de una cancha de 4 jugadores (p0..p3), estas son las 3 rondas que cubren TODAS las
// combinaciones posibles de pareja/rival sin repetir: cada jugador es pareja de cada uno de los
// otros 3 exactamente una vez a lo largo del torneo.
const AMERICANO_COURT_ROTATIONS: ReadonlyArray<readonly [readonly [number, number], readonly [number, number]]> = [
  [[0, 1], [2, 3]],
  [[0, 2], [1, 3]],
  [[0, 3], [1, 2]],
]

/**
 * Americano: cancha FIJA de 4 jugadores durante todo el torneo (si hay más de 4 inscritos se
 * reparten en varias canchas, por seed, igual que splitIntoGroups) — dentro de cada cancha la
 * pareja rota las 3 rondas según AMERICANO_COURT_ROTATIONS. No hace falta esperar resultados
 * entre ronda y ronda (a diferencia de King of the Court): las 3 rondas se arman de una vez.
 * El puntaje es INDIVIDUAL — ver lib/tournamentRotationActions.ts (tournament_rotation_matches /
 * tournament_rotation_standings), porque tournament_fixtures asume pareja fija por lado.
 */
export function buildAmericanoRounds(entryIds: string[]): RotationFixtureSpec[] {
  if (entryIds.length < 4 || entryIds.length % 4 !== 0) throw new Error('AMERICANO_REQUIRES_MULTIPLE_OF_4')
  const courts = splitIntoGroups(entryIds, 4)
  const fixtures: RotationFixtureSpec[] = []
  courts.forEach((court, courtIdx) => {
    AMERICANO_COURT_ROTATIONS.forEach((pairing, roundIdx) => {
      fixtures.push({
        round: roundIdx + 1,
        court: courtIdx + 1,
        sideA: [court[pairing[0][0]], court[pairing[0][1]]],
        sideB: [court[pairing[1][0]], court[pairing[1][1]]],
      })
    })
  })
  return fixtures
}

/**
 * Mexicano, cantidad fija de rondas de una "noche" (se puede ajustar más adelante si hace falta
 * por torneo, igual que LADDER_TOTAL_ROUNDS).
 */
export const MEXICANO_TOTAL_ROUNDS = 5

/** Reparte en bloques seguidos (1-4, 5-8, ...) — a diferencia de splitIntoGroups, que reparte
 * intercalado (como una baraja); para Mexicano hace falta lo contiguo: los 4 mejores juntos en
 * la cancha 1, los siguientes 4 en la cancha 2, etc. */
function chunkContiguous(ids: string[], size: number): string[][] {
  const chunks: string[][] = []
  for (let i = 0; i < ids.length; i += size) chunks.push(ids.slice(i, i + size))
  return chunks
}

/**
 * Dentro de una cancha de 4 ya ordenados de mejor (0) a peor (3) por nivel/puntaje, la pareja es
 * 1ro+4to contra 2do+3ro — así el más fuerte de la cancha compensa un poco al más débil, en vez
 * de que el 1ro y el 2do (los dos mejores) siempre queden del mismo lado.
 */
function pairCourtByRank(court: string[]): { sideA: [string, string]; sideB: [string, string] } {
  return { sideA: [court[0], court[3]], sideB: [court[1], court[2]] }
}

/**
 * Mexicano, ronda 1: todavía no hay puntaje, así que se usa el orden de siembra/inscripción
 * (mismo criterio — seed, luego antigüedad — que ya usan los demás formatos) como el "nivel"
 * inicial para armar las canchas.
 */
export function buildMexicanoInitialRound(entryIds: string[]): RotationFixtureSpec[] {
  if (entryIds.length < 4 || entryIds.length % 4 !== 0) throw new Error('MEXICANO_REQUIRES_MULTIPLE_OF_4')
  const courts = chunkContiguous(entryIds, 4)
  return courts.map((court, idx) => {
    const { sideA, sideB } = pairCourtByRank(court)
    return { round: 1, court: idx + 1, sideA, sideB }
  })
}

export type MexicanoStandingInput = { entryId: string; totalPoints: number }

/**
 * Mexicano, ronda 2 en adelante: a diferencia de Americano (pareja fija toda la noche), acá se
 * reordenan TODOS los inscritos de la categoría por su puntaje acumulado hasta el momento (mejor
 * primero; en empate se respeta el orden recibido, para no reacomodar sin necesidad) y se vuelven
 * a repartir en canchas nuevas de 4 — el nivel se empareja solo, ronda a ronda. Quien va ganando
 * se va encontrando con gente de su nivel, no con una pareja/rival fija de antemano.
 */
export function buildMexicanoNextRound(roundNumber: number, standings: MexicanoStandingInput[]): RotationFixtureSpec[] {
  if (standings.length < 4 || standings.length % 4 !== 0) throw new Error('MEXICANO_REQUIRES_MULTIPLE_OF_4')
  const ranked = standings
    .map((s, i) => ({ ...s, i }))
    .sort((a, b) => b.totalPoints - a.totalPoints || a.i - b.i)
    .map((s) => s.entryId)
  const courts = chunkContiguous(ranked, 4)
  return courts.map((court, idx) => {
    const { sideA, sideB } = pairCourtByRank(court)
    return { round: roundNumber, court: idx + 1, sideA, sideB }
  })
}
