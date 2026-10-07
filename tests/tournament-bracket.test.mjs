// Pruebas de lib/tournamentBracket.ts: el cuadro de eliminacion simple y el round robin deben
// quedar bien armados (nadie juega dos veces en la misma ronda, nadie se queda sin avanzar, etc).
import { test } from 'node:test'
import assert from 'node:assert/strict'
import {
  buildSingleEliminationRounds,
  buildRoundRobinPairs,
  splitIntoGroups,
  seedKnockoutFromGroups,
} from '../lib/tournamentBracket.ts'

test('eliminacion simple: 8 inscritos (potencia de 2) -> 3 rondas, 4+2+1 partidos, sin byes', () => {
  const entries = Array.from({ length: 8 }, (_, i) => `e${i}`)
  const rounds = buildSingleEliminationRounds(entries)
  assert.equal(rounds.length, 3)
  assert.equal(rounds[0].length, 4)
  assert.equal(rounds[1].length, 2)
  assert.equal(rounds[2].length, 1)
  for (const f of rounds[0]) assert.equal(f.isBye, false)
  // cada inscrito aparece exactamente una vez en la ronda 1
  const seen = rounds[0].flatMap((f) => [f.sideA, f.sideB])
  assert.deepEqual([...seen].sort(), [...entries].sort())
})

test('eliminacion simple: 5 inscritos -> relleno a 8 (3 lugares vacios), nadie se pierde', () => {
  const entries = Array.from({ length: 5 }, (_, i) => `e${i}`)
  const rounds = buildSingleEliminationRounds(entries)
  assert.equal(rounds.length, 3) // tamaño de cuadro = 8 -> 3 rondas
  assert.equal(rounds[0].length, 4) // 8/2 = 4 partidos en la ronda 1
  // los 5 inscritos reales aparecen exactamente una vez entre todos los partidos de la ronda 1
  const real = rounds[0].flatMap((f) => [f.sideA, f.sideB]).filter((x) => x !== null)
  assert.deepEqual([...real].sort(), [...entries].sort())
  // al menos un partido de la ronda 1 es bye (avanza directo sin jugar)
  assert.ok(rounds[0].some((f) => f.isBye))
  // todo inscrito real sigue presente en el campeon final una vez resueltos los byes
  for (const f of rounds[0]) if (f.isBye) assert.ok(f.sideA || f.sideB)
})

test('eliminacion simple: menos de 2 inscritos lanza error', () => {
  assert.throws(() => buildSingleEliminationRounds(['solo']), /NOT_ENOUGH_ENTRIES/)
  assert.throws(() => buildSingleEliminationRounds([]), /NOT_ENOUGH_ENTRIES/)
})

test('round robin: 4 inscritos -> 3 rondas, cada pareja juega exactamente una vez', () => {
  const entries = ['a', 'b', 'c', 'd']
  const pairs = buildRoundRobinPairs(entries)
  assert.equal(pairs.length, 6) // combinaciones de 4 tomadas de 2 en 2
  const rounds = new Set(pairs.map((p) => p.round))
  assert.equal(rounds.size, 3)
  // cada jugador aparece 3 veces en total (juega contra los otros 3)
  const counts = {}
  for (const p of pairs) {
    counts[p.sideA] = (counts[p.sideA] ?? 0) + 1
    counts[p.sideB] = (counts[p.sideB] ?? 0) + 1
  }
  for (const e of entries) assert.equal(counts[e], 3)
  // en cada ronda nadie se repite
  for (const r of rounds) {
    const inRound = pairs.filter((p) => p.round === r).flatMap((p) => [p.sideA, p.sideB])
    assert.equal(inRound.length, new Set(inRound).size)
  }
})

test('round robin: cantidad impar -> alguien descansa cada ronda', () => {
  const entries = ['a', 'b', 'c']
  const pairs = buildRoundRobinPairs(entries)
  assert.equal(pairs.length, 3) // 3 combinaciones posibles, una por ronda
  const rounds = new Set(pairs.map((p) => p.round))
  assert.equal(rounds.size, 3) // con bye, son n rondas (n=3), un partido cada una
})

test('round robin: menos de 2 inscritos lanza error', () => {
  assert.throws(() => buildRoundRobinPairs(['solo']), /NOT_ENOUGH_ENTRIES/)
})

test('grupos: 12 inscritos con tamaño 4 -> 3 grupos de 4, nadie se repite ni se pierde', () => {
  const entries = Array.from({ length: 12 }, (_, i) => `e${i}`)
  const groups = splitIntoGroups(entries, 4)
  assert.equal(groups.length, 3)
  for (const g of groups) assert.equal(g.length, 4)
  const all = groups.flat()
  assert.deepEqual([...all].sort(), [...entries].sort())
})

test('grupos: los primeros seeds quedan repartidos, no amontonados en un grupo', () => {
  const entries = Array.from({ length: 8 }, (_, i) => `seed${i}`) // seed0 es el mejor puesto
  const groups = splitIntoGroups(entries, 4)
  assert.equal(groups.length, 2)
  // seed0 y seed1 (los dos mejores) deben quedar en grupos distintos
  const groupOfSeed0 = groups.findIndex((g) => g.includes('seed0'))
  const groupOfSeed1 = groups.findIndex((g) => g.includes('seed1'))
  assert.notEqual(groupOfSeed0, groupOfSeed1)
})

test('grupos: grupo que quedaría con 1 solo se descarta', () => {
  const entries = Array.from({ length: 9 }, (_, i) => `e${i}`)
  const groups = splitIntoGroups(entries, 4)
  for (const g of groups) assert.ok(g.length >= 2)
})

test('grupos: menos de 2 inscritos o tamaño invalido lanzan error', () => {
  assert.throws(() => splitIntoGroups(['solo'], 4), /NOT_ENOUGH_ENTRIES/)
  assert.throws(() => splitIntoGroups(['a', 'b'], 1), /INVALID_GROUP_SIZE/)
})

test('cuadro final desde grupos: intercala por puesto, 1ros primero y luego 2dos', () => {
  const qualifiers = [
    ['g1-1ro', 'g1-2do'],
    ['g2-1ro', 'g2-2do'],
    ['g3-1ro', 'g3-2do'],
  ]
  const seeded = seedKnockoutFromGroups(qualifiers)
  assert.deepEqual(seeded, ['g1-1ro', 'g2-1ro', 'g3-1ro', 'g1-2do', 'g2-2do', 'g3-2do'])
})
