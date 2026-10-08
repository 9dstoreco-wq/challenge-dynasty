// Pruebas de lib/sport-scoring.ts: el ganador que se declara debe coincidir con lo que diga el
// marcador, y cada deporte debe caer en el modo correcto (sets / puntos / solo-ganador).
// Se corren con: npm test   (Node 22 ejecuta TypeScript directamente)
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { modeForSlug, computeWinnerSide, parseScore } from '../lib/sport-scoring.ts'

test('modeForSlug: deportes de hoy en produccion caen en el modo correcto', () => {
  assert.equal(modeForSlug('football'), 'points')
  assert.equal(modeForSlug('basketball'), 'points')
  assert.equal(modeForSlug('padel'), 'sets')
  assert.equal(modeForSlug('tennis'), 'sets')
  assert.equal(modeForSlug('running'), 'winner')
})

test('modeForSlug: deportes de sets que no son padel/tenis tambien caen en "sets"', () => {
  assert.equal(modeForSlug('volleyball'), 'sets')
  assert.equal(modeForSlug('table-tennis'), 'sets')
})

test('modeForSlug: slug vacio o desconocido no revienta (sets por defecto si falta, winner si no se reconoce)', () => {
  assert.equal(modeForSlug(null), 'sets')
  assert.equal(modeForSlug(undefined), 'sets')
  assert.equal(modeForSlug('boxing'), 'winner')
})

test('parseScore: solo acepta "numero-numero" o "numero:numero"', () => {
  assert.deepEqual(parseScore('6-4'), [6, 4])
  assert.deepEqual(parseScore('10:8'), [10, 8])
  assert.equal(parseScore('abc'), null)
  assert.equal(parseScore(''), null)
})

test('computeWinnerSide: modo "winner" nunca contradice (no hay marcador que revisar)', () => {
  assert.equal(computeWinnerSide('winner', '', '', ''), null)
})

test('computeWinnerSide: modo "points" calcula el lado ganador por el marcador unico', () => {
  assert.equal(computeWinnerSide('points', '3-1'), 0)
  assert.equal(computeWinnerSide('points', '1-3'), 1)
  assert.equal(computeWinnerSide('points', '2-2'), null) // empate: no hay forma de decidir
  assert.equal(computeWinnerSide('points', 'no-valido'), null)
})

test('computeWinnerSide: modo "sets" cuenta sets ganados, mejor de 3', () => {
  assert.equal(computeWinnerSide('sets', '6-4', '6-3'), 0) // 2-0 para el creador
  assert.equal(computeWinnerSide('sets', '4-6', '3-6'), 1) // 2-0 para el rival
  assert.equal(computeWinnerSide('sets', '6-4', '3-6', '6-2'), 0) // 2-1 para el creador
  assert.equal(computeWinnerSide('sets', '6-4', '4-6'), null) // 1-1: no alcanza, falta decidir
})

test('computeWinnerSide: el caso que antes se podia fabricar -- marcador y ganador contradictorios', () => {
  // Alguien perdio 0-6 y 0-6 pero intenta declararse ganador: el marcador dice lado 1, no lado 0.
  assert.equal(computeWinnerSide('sets', '0-6', '0-6'), 1)
  assert.notEqual(computeWinnerSide('sets', '0-6', '0-6'), 0)
})
