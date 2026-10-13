// Pruebas de lib/dynasty/wompi.ts: el formato de referencia que arma buildWompiReference
// debe seguir siendo el mismo contrato de 4 partes (dyn:<domain>:<rowId>:<nonce>) que
// supabase/functions/wompi-webhook/index.ts espera al parsear. El webhook corre en Deno y no
// se puede importar aqui, asi que este archivo replica su logica de parseo (parseAsWebhookWould,
// abajo) a mano -- si alguno de los dos lados cambia el formato sin el otro, este test no lo
// detecta automaticamente, pero sí fija por escrito, de forma ejecutable, cual es el contrato
// que ambos deben respetar (ver F01, Auditoria_Challenge_Dynasty_2026-10-12.md).
//
// Se corren con: npm test   (Node 22 ejecuta TypeScript directamente)
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { buildWompiReference } from '../lib/dynasty/wompi.ts'

// Copia deliberada, en JS plano, del parseo real de supabase/functions/wompi-webhook/index.ts
// (la seccion que lee `refParts = reference.split(":")`). Mantener en sync a mano si ese
// archivo cambia el formato.
function parseAsWebhookWould(reference) {
  const refParts = reference.split(':')
  if (refParts.length !== 4 || refParts[0] !== 'dyn') return null
  return { domain: refParts[1], rowId: refParts[2], nonce: refParts[3] }
}

test('buildWompiReference produce el formato de 4 partes que el webhook espera', () => {
  const ref = buildWompiReference('booking', 'b-123')
  const parsed = parseAsWebhookWould(ref)
  assert.ok(parsed, `referencia no reconocida por el parser del webhook: ${ref}`)
  assert.equal(parsed.domain, 'booking')
  assert.equal(parsed.rowId, 'b-123')
  assert.ok(parsed.nonce.length > 0, 'el nonce no debe quedar vacio')
})

test('el dominio y el rowId se preservan exactamente para cada dominio soportado', () => {
  for (const domain of ['booking', 'tournament', 'marketplace', 'billing']) {
    const ref = buildWompiReference(domain, 'row-xyz')
    const parsed = parseAsWebhookWould(ref)
    assert.ok(parsed, `referencia no reconocida: ${ref}`)
    assert.equal(parsed.domain, domain)
    assert.equal(parsed.rowId, 'row-xyz')
  }
})

test('dos llamadas seguidas sobre la misma fila producen referencias distintas (nonce)', () => {
  // Regresion F01 / docs.wompi.co: "once a reference is used for a payment on your account,
  // it will not be possible to use it again" -- antes de este fix, dos intentos de pago
  // sobre la misma reserva (ej. tarjeta rechazada y reintento) generaban exactamente la misma
  // referencia, lo que Wompi rechaza en el segundo intento.
  const refs = new Set()
  for (let i = 0; i < 20; i++) {
    refs.add(buildWompiReference('booking', 'misma-fila'))
  }
  assert.equal(refs.size, 20, 'cada llamada debe producir una referencia unica')
})

test('la vieja referencia de 3 partes (sin nonce) ya no pasa el parseo del webhook', () => {
  // Documenta por que el formato viejo (dyn:<domain>:<rowId>, sin nonce) rompia: el webhook
  // desplegado antes de este fix exigia 4 partes con otro separador, y la version del repo sin
  // reconciliar exigia exactamente 3 -- ninguna de las dos coincidia con la otra mitad del
  // flujo. El contrato reconciliado es: siempre 4 partes, separadas por ":".
  const sinNonce = 'dyn:booking:b-123'
  assert.equal(parseAsWebhookWould(sinNonce), null)
})
