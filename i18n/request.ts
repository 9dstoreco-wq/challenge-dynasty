import { cookies } from 'next/headers'
import { getRequestConfig } from 'next-intl/server'

export const SUPPORTED_LOCALES = ['es', 'en'] as const
export type SupportedLocale = (typeof SUPPORTED_LOCALES)[number]
export const DEFAULT_LOCALE: SupportedLocale = 'es'

export default getRequestConfig(async () => {
  const store = await cookies()
  const cookieLocale = store.get('locale')?.value
  const locale: SupportedLocale = SUPPORTED_LOCALES.includes(cookieLocale as SupportedLocale)
    ? (cookieLocale as SupportedLocale)
    : DEFAULT_LOCALE

  return {
    locale,
    messages: (await import(`../messages/${locale}.json`)).default,
  }
})
