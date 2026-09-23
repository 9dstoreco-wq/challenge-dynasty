// Countries prioritized by padel community size / Challenge Dynasty's target markets.
// code: ISO 3166-1 alpha-2. Used across Marketplace listings and seller profiles.
export type Country = { code: string; name: string; nameEn: string; flag: string }

export const COUNTRIES: Country[] = [
  { code: 'CO', name: 'Colombia', nameEn: 'Colombia', flag: '🇨🇴' },
  { code: 'ES', name: 'España', nameEn: 'Spain', flag: '🇪🇸' },
  { code: 'AR', name: 'Argentina', nameEn: 'Argentina', flag: '🇦🇷' },
  { code: 'MX', name: 'México', nameEn: 'Mexico', flag: '🇲🇽' },
  { code: 'US', name: 'Estados Unidos', nameEn: 'United States', flag: '🇺🇸' },
  { code: 'BR', name: 'Brasil', nameEn: 'Brazil', flag: '🇧🇷' },
  { code: 'PT', name: 'Portugal', nameEn: 'Portugal', flag: '🇵🇹' },
  { code: 'IT', name: 'Italia', nameEn: 'Italy', flag: '🇮🇹' },
  { code: 'FR', name: 'Francia', nameEn: 'France', flag: '🇫🇷' },
  { code: 'SE', name: 'Suecia', nameEn: 'Sweden', flag: '🇸🇪' },
  { code: 'AE', name: 'Emiratos Árabes Unidos', nameEn: 'United Arab Emirates', flag: '🇦🇪' },
  { code: 'QA', name: 'Qatar', nameEn: 'Qatar', flag: '🇶🇦' },
  { code: 'PE', name: 'Perú', nameEn: 'Peru', flag: '🇵🇪' },
  { code: 'EC', name: 'Ecuador', nameEn: 'Ecuador', flag: '🇪🇨' },
  { code: 'CL', name: 'Chile', nameEn: 'Chile', flag: '🇨🇱' },
  { code: 'PY', name: 'Paraguay', nameEn: 'Paraguay', flag: '🇵🇾' },
  { code: 'BO', name: 'Bolivia', nameEn: 'Bolivia', flag: '🇧🇴' },
  { code: 'PA', name: 'Panamá', nameEn: 'Panama', flag: '🇵🇦' },
  { code: 'CR', name: 'Costa Rica', nameEn: 'Costa Rica', flag: '🇨🇷' },
  { code: 'DO', name: 'República Dominicana', nameEn: 'Dominican Republic', flag: '🇩🇴' },
  { code: 'VE', name: 'Venezuela', nameEn: 'Venezuela', flag: '🇻🇪' },
  { code: 'UY', name: 'Uruguay', nameEn: 'Uruguay', flag: '🇺🇾' },
  { code: 'GB', name: 'Reino Unido', nameEn: 'United Kingdom', flag: '🇬🇧' },
  { code: 'EG', name: 'Egipto', nameEn: 'Egypt', flag: '🇪🇬' },
  { code: 'MA', name: 'Marruecos', nameEn: 'Morocco', flag: '🇲🇦' },
  { code: 'BE', name: 'Bélgica', nameEn: 'Belgium', flag: '🇧🇪' },
  { code: 'NL', name: 'Países Bajos', nameEn: 'Netherlands', flag: '🇳🇱' },
]

export function countryByCode(code: string | null | undefined): Country | undefined {
  if (!code) return undefined
  return COUNTRIES.find((c) => c.code === code.toUpperCase())
}

export function countryName(code: string | null | undefined, locale: string = 'es'): string {
  const c = countryByCode(code)
  if (!c) return ''
  return locale === 'en' ? c.nameEn : c.name
}

export function countryLabel(code: string | null | undefined, locale: string = 'es', fallback: string = 'Sin país'): string {
  const c = countryByCode(code)
  return c ? `${c.flag} ${locale === 'en' ? c.nameEn : c.name}` : fallback
}
