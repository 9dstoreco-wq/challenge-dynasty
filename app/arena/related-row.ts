/** Resolve a to-one PostgREST embed while tolerating untyped client array inference. */
export function relatedRow<T>(value: T | T[] | null | undefined): T | undefined {
  return Array.isArray(value) ? value[0] : value ?? undefined
}
