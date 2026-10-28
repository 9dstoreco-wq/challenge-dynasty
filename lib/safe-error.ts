// lib/safe-error.ts
//
// WHY THIS EXISTS: server actions and client components across this app
// relayed `error.message` from Supabase (Postgres/PostgREST) straight to
// the UI — e.g. `if (error) throw new Error(error.message)` or
// `setMessage(error.message)`. That message can be raw Postgres internals:
// "new row for relation \"player_sports\" violates check constraint
// \"player_sports_relationship_check\"", a table/column name, or a raw
// SQL syntax error. That leaks schema details to end users and reads as a
// broken product. This module is the single choke point that decides what
// error text is safe to show a user; every call site that used to do
// `error.message` should go through `toSafeMessage()` instead.
//
// Rules:
// - The full raw error always goes to server/browser console logs (for
//   debugging) — it never reaches the client differently than before in
//   terms of observability, it just no longer reaches the *rendered UI*.
// - Anything that looks like a Postgres/PostgREST internal (mentions a
//   relation/column/constraint name, "violates", "syntax error", a `pg_*`
//   error code, etc.) is replaced with a generic, safe fallback message.
// - A short SCREAMING_SNAKE_CASE code raised intentionally by one of our
//   own RPCs (e.g. `AUTH_REQUIRED`, `PRODUCT_NOT_AVAILABLE`) is not a raw
//   internal — it's an application-level signal — but it isn't friendly
//   copy either, so it's humanized ("Product not available.") rather than
//   shown as-is.
// - Anything else (a plain sentence our own code or RPC already wrote for
//   humans, e.g. "Debes iniciar sesión") is passed through unchanged.

const SQL_INTERNAL_PATTERN =
  /relation "|column "|constraint "|violates|syntax error|permission denied for|duplicate key value|invalid input syntax|null value in column|does not exist|pg_|P0001|42501|23505|23503|23502|22P02/i

const SCREAMING_CASE_PATTERN = /^[A-Z][A-Z0-9_]*$/
// Codigo lower_snake_case de una sola palabra sin espacios (p.ej. "forbidden",
// "tournament_not_found") que una RPC nuestra lanzo a proposito pero que no quedo en el
// diccionario de arriba. Red de seguridad: mejor humanizarlo igual que un SCREAMING_CASE que
// dejarlo pasar crudo en ingles/snake_case a la UI.
const LOWER_SNAKE_CASE_PATTERN = /^[a-z][a-z0-9_]*$/

export const DEFAULT_SAFE_FALLBACK = 'No se pudo completar la acción. Intenta de nuevo.'

const KNOWN_RPC_MESSAGES: Record<string, string> = {
  'Not authorized': 'No tienes permiso para hacer esto.',
  'Invitation not found': 'No encontramos esa invitación.',
  'Invitation is not pending': 'Esta invitación ya fue respondida.',
  'Challenge not found': 'No encontramos ese reto.',
  'Challenge is not open': 'El reto ya no está abierto.',
  'Challenge match not found': 'No encontramos el partido de este reto.',
  'Not an accepted challenge participant': 'Solo los participantes del reto pueden hacer esto.',
  'Winner must be a participant': 'El ganador debe ser uno de los participantes del reto.',
  'Match is not active': 'El partido ya no está activo.',
  'Result not found': 'No encontramos ese resultado.',
  'Result is not pending': 'Este resultado ya fue revisado.',
  'Result already confirmed': 'El resultado ya fue confirmado.',
  'Submitter cannot review own result': 'No puedes confirmar tu propio resultado: debe hacerlo tu rival.',
  'Existing result was submitted by you': 'Ya enviaste un resultado. Espera a que tu rival lo revise.',
  // BUG ENCONTRADO EN PRUEBAS QA (2026-10-26): register_tournament_entry lanza estos dos mensajes
  // en ingles cuando el torneo todavia no fue publicado / no abrio inscripciones; como no estaban
  // en este diccionario, el jugador veia el texto crudo en ingles en medio de una app en espanol.
  'Registrations are not open': 'Las inscripciones de este torneo todavía no están abiertas.',
  'Registration has not opened': 'Las inscripciones de este torneo todavía no están abiertas.',
  // Codigos lower_snake_case que lanza transition_tournament_status (ver TournamentStatusPanel.tsx).
  // Antes TournamentStatusPanel traducia estos a mano con un switch local que leia
  // rpcError.message directamente -- eso duplicaba este diccionario y además lo saltaba, así que
  // lo centralizamos aquí (el check-error-sanitization del repo exige que todo pase por
  // toSafeMessage, no por un switch aparte).
  not_authenticated: 'Debes iniciar sesión.',
  tournament_not_found: 'No encontramos ese torneo.',
  forbidden: 'No tienes permiso para hacer esto.',
  invalid_tournament_status: 'Ese estado no es válido.',
  // Codigos de reschedule_tournament_fixture / notify_category_fixture_schedule (ver
  // TournamentScheduleEditor.tsx).
  category_not_found: 'No encontramos esa categoría.',
  fixture_not_found: 'No encontramos ese partido.',
  fixture_already_finalized: 'Ese partido ya terminó, no se puede cambiar su hora.',
  scheduled_at_required: 'Elige una fecha y hora para el partido.',
  // BUG ENCONTRADO EN AUDITORIA DE NAV (2026-10-28): create_atomic_booking / cancel_booking
  // lanzan estos mensajes/codigos en ingles (algunos SCREAMING_CASE, otros frases con espacios
  // que no calzan en SCREAMING_CASE_PATTERN ni LOWER_SNAKE_CASE_PATTERN, asi que pasaban crudos
  // en ingles hasta el usuario en BookingControlCenter.tsx). Se agregan aqui explicitamente.
  'Booking not found': 'No encontramos esa reserva.',
  'Not authorized to cancel this booking': 'No tienes permiso para cancelar esta reserva.',
  'Booking cannot be cancelled in its current state': 'Esta reserva no se puede cancelar en su estado actual.',
  'Cancellation deadline has passed': 'Ya pasó el plazo para cancelar esta reserva.',
  AUTH_REQUIRED: 'Debes iniciar sesión.',
  BOOKING_ACTOR_MISMATCH: 'No puedes reservar en nombre de otra persona.',
  INVALID_BOOKING_RANGE: 'El horario de la reserva no es válido.',
  BOOKING_ITEMS_INVALID: 'Los datos de la reserva no son válidos.',
  BOOKABLE_ID_REQUIRED: 'Falta elegir qué vas a reservar.',
  INVALID_BOOKING_QUANTITY: 'La cantidad de la reserva no es válida.',
  BOOKABLE_NOT_AVAILABLE: 'Eso ya no está disponible para reservar.',
  INVALID_BOOKABLE_PRICE: 'El precio de eso no está configurado correctamente.',
  BOOKABLE_CURRENCY_REQUIRED: 'Falta configurar la moneda de eso.',
  MIXED_CURRENCY_BOOKING_NOT_ALLOWED: 'No puedes reservar varias cosas con monedas distintas en la misma reserva.',
}

// Mismo caso que invalid_status_transition: % -> % (transition_tournament_status interpola el
// estado actual y el pedido en el propio mensaje, así que no puede ser una llave exacta del
// diccionario de arriba).
const LOWER_SNAKE_PREFIX_MESSAGES: Array<{ prefix: string; message: string }> = [
  { prefix: 'invalid_status_transition', message: 'Ese cambio de estado no está permitido desde el estado actual.' },
]

/**
 * Converts a Supabase/Postgres error (or any thrown value) into a message
 * that is safe to render to an end user: no table/column/constraint names,
 * no raw SQL, no internal error codes shown verbatim.
 *
 * @param error   The caught error / Supabase `{ error }` value.
 * @param context A short tag for server-side logs (e.g. "profile.updateProfile").
 * @param fallback What to show when the message must be suppressed.
 */
export function toSafeMessage(
  error: unknown,
  context: string,
  fallback: string = DEFAULT_SAFE_FALLBACK
): string {
  const raw =
    error instanceof Error
      ? error.message
      : typeof error === 'string'
        ? error
        : typeof (error as { message?: unknown })?.message === 'string'
          ? ((error as { message: string }).message)
          : ''

  if (raw) {
    // Full detail stays in logs only — this is the one place allowed to see it.
    console.error(`[safe-error:${context}]`, raw)
  }

  if (!raw) return fallback
  if (SQL_INTERNAL_PATTERN.test(raw)) return fallback

  // Mensajes en ingles que lanzan las funciones de la base de datos: se muestran en espanol.
  const trimmed = raw.trim()
  const known = KNOWN_RPC_MESSAGES[trimmed]
  if (known) return known

  for (const { prefix, message } of LOWER_SNAKE_PREFIX_MESSAGES) {
    if (trimmed.startsWith(prefix)) return message
  }

  if (SCREAMING_CASE_PATTERN.test(raw) || LOWER_SNAKE_CASE_PATTERN.test(trimmed)) {
    return raw.replace(/_/g, ' ').toLowerCase().replace(/^./, (c) => c.toUpperCase()) + '.'
  }

  // Already a human sentence written intentionally by our own code/RPCs.
  return raw
}
