// Countries prioritized by padel community size / Challenge Dynasty's target markets.
// code: ISO 3166-1 alpha-2. Used across Marketplace listings and seller profiles.
export type Country = { code: string; name: string; flag: string }

export const COUNTRIES: Country[] = [
  { code: 'CO', name: 'Colombia', flag: '🇨🇴' },
  { code: 'ES', name: 'España', flag: '🇪🇸' },
  { code: 'AR', name: 'Argentina', flag: '🇦🇷' },
  { code: 'MX', name: 'México', flag: '🇲🇽' },
  { code: 'US', name: 'Estados Unidos', flag: '🇺🇸' },
  { code: 'BR', name: 'Brasil', flag: '🇧🇷' },
  { code: 'PT', name: 'Portugal', flag: '🇵🇹' },
  { code: 'IT', name: 'Italia', flag: '🇮🇹' },
  { code: 'FR', name: 'Francia', flag: '🇫🇷' },
  { code: 'SE', name: 'Suecia', flag: '🇸🇪' },
  { code: 'AE', name: 'Emiratos Árabes Unidos', flag: '🇦🇪' },
  { code: 'QA', name: 'Qatar', flag: '🇶🇦' },
  { code: 'PE', name: 'Perú', flag: '🇵🇪' },
  { code: 'EC', name: 'Ecuador', flag: '🇪🇨' },
  { code: 'CL', name: 'Chile', flag: '🇨🇱' },
  { code: 'PY', name: 'Paraguay', flag: '🇵🇾' },
  { code: 'BO', name: 'Bolivia', flag: '🇧🇴' },
  { code: 'PA', name: 'Panamá', flag: '🇵🇦' },
  { code: 'CR', name: 'Costa Rica', flag: '🇨🇷' },
  { code: 'DO', name: 'República Dominicana', flag: '🇩🇴' },
  { code: 'VE', name: 'Venezuela', flag: '🇻🇪' },
  { code: 'UY', name: 'Uruguay', flag: '🇺🇾' },
  { code: 'GB', name: 'Reino Unido', flag: '🇬🇧' },
  { code: 'EG', name: 'Egipto', flag: '🇪🇬' },
  { code: 'MA', name: 'Marruecos', flag: '🇲🇦' },
  { code: 'BE', name: 'Bélgica', flag: '🇧🇪' },
  { code: 'NL', name: 'Países Bajos', flag: '🇳🇱' },
]

export function countryByCode(code: string | null | undefined): Country | undefined {
  if (!code) return undefined
  return COUNTRIES.find((c) => c.code === code.toUpperCase())
}

export function countryLabel(code: string | null | undefined): string {
  const c = countryByCode(code)
  return c ? `${c.flag} ${c.name}` : 'Sin país'
}
