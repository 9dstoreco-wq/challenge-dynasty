// Pruebas de lib/safe-error.ts: ningun texto tecnico de la base de datos debe llegar al usuario.
// Se corren con: npm test   (Node 22 ejecuta TypeScript directamente)
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { toSafeMessage, DEFAULT_SAFE_FALLBACK } from '../lib/safe-error.ts'

// toSafeMessage escribe el error completo en la consola del servidor; aqui lo silenciamos.
const originalError = console.error
test.before(() => { console.error = () => {} })
test.after(() => { console.error = originalError })

test('errores internos de Postgres se reemplazan por el mensaje generico', () => {
  const internos = [
    'new row for relation "player_sports" violates check constraint "player_sports_relationship_check"',
    'duplicate key value violates unique constraint "challenges_pkey"',
    'null value in column "creator_id" of relation "challenges"',
    'permission denied for table platform_admins',
    'invalid input syntax for type uuid: "abc"',
    'column "foo" does not exist',
    'syntax error at or near "select"',
    'P0001: algo interno',
  ]
  for (const raw of internos) {
    assert.equal(toSafeMessage(new Error(raw), 'test'), DEFAULT_SAFE_FALLBACK, raw)
  }
})

test('los mensajes en ingles de las funciones de retos se muestran en espanol', () => {
  const esperados = {
    'Not authorized': 'No tienes permiso para hacer esto.',
    'Challenge is not open': 'El reto ya no está abierto.',
    'Submitter cannot review own result': 'No puedes confirmar tu propio resultado: debe hacerlo tu rival.',
    'Existing result was submitted by you': 'Ya enviaste un resultado. Espera a que tu rival lo revise.',
    'Result already confirmed': 'El resultado ya fue confirmado.',
    'Winner must be a participant': 'El ganador debe ser uno de los participantes del reto.',
    'Not an accepted challenge participant': 'Solo los participantes del reto pueden hacer esto.',
  }
  for (const [raw, es] of Object.entries(esperados)) {
    assert.equal(toSafeMessage(new Error(raw), 'test'), es)
  }
})

test('las frases en espanol escritas por nuestras funciones pasan sin cambios', () => {
  for (const frase of ['Rival inválido', 'La fecha del reto debe ser futura', 'Los puntos deben estar entre 1 y 5000', 'No autorizado', 'Ya enviaste este reto']) {
    assert.equal(toSafeMessage(new Error(frase), 'test'), frase)
  }
})

test('los mensajes/codigos en ingles de las reservas se muestran en espanol', () => {
  const esperados = {
    'Booking not found': 'No encontramos esa reserva.',
    'Not authorized to cancel this booking': 'No tienes permiso para cancelar esta reserva.',
    'Booking cannot be cancelled in its current state': 'Esta reserva no se puede cancelar en su estado actual.',
    'Cancellation deadline has passed': 'Ya pasó el plazo para cancelar esta reserva.',
    AUTH_REQUIRED: 'Debes iniciar sesión.',
    BOOKABLE_NOT_AVAILABLE: 'Eso ya no está disponible para reservar.',
    MIXED_CURRENCY_BOOKING_NOT_ALLOWED: 'No puedes reservar varias cosas con monedas distintas en la misma reserva.',
  }
  for (const [raw, es] of Object.entries(esperados)) {
    assert.equal(toSafeMessage(new Error(raw), 'test'), es)
  }
})

test('los codigos EN_MAYUSCULAS se vuelven una frase legible', () => {
  assert.equal(toSafeMessage('PRODUCT_NOT_AVAILABLE', 'test'), 'Product not available.')
  assert.equal(toSafeMessage('SELLER_NOT_OWNED', 'test'), 'Seller not owned.')
})

test('acepta strings, objetos con message y valores vacios', () => {
  assert.equal(toSafeMessage('Debes iniciar sesión', 'test'), 'Debes iniciar sesión')
  assert.equal(toSafeMessage({ message: 'Debes iniciar sesión' }, 'test'), 'Debes iniciar sesión')
  assert.equal(toSafeMessage(undefined, 'test'), DEFAULT_SAFE_FALLBACK)
  assert.equal(toSafeMessage(null, 'test'), DEFAULT_SAFE_FALLBACK)
  assert.equal(toSafeMessage({}, 'test'), DEFAULT_SAFE_FALLBACK)
})

test('usa el texto de respaldo propio cuando se pasa uno', () => {
  assert.equal(toSafeMessage(new Error('violates something'), 'test', 'Intenta más tarde'), 'Intenta más tarde')
})
