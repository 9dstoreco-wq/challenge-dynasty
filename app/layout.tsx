import '@fontsource/inter/400.css'
import '@fontsource/inter/500.css'
import '@fontsource/inter/700.css'
import '@fontsource/inter/900.css'
import '@fontsource/bebas-neue/400.css'
import './globals.css'
import type { Metadata, Viewport } from 'next'
import { NextIntlClientProvider } from 'next-intl'
import { getLocale, getMessages } from 'next-intl/server'

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || 'https://challenge-dynasty.com'),
  title: { default: 'CHALLENGE DYNASTY', template: '%s · CHALLENGE DYNASTY' },
  description: 'Reta, compite, gana y construye tu reputación deportiva.',
  applicationName: 'Challenge Dynasty',
  category: 'sports',
  manifest: '/manifest.webmanifest',
  icons: { icon: [{ url: '/favicon-32.png', sizes: '32x32', type: 'image/png' }, { url: '/icon-512.png', sizes: '512x512', type: 'image/png' }], apple: '/apple-icon.png' },
  openGraph: { title: 'CHALLENGE DYNASTY', description: 'La red competitiva para todos tus deportes.', siteName: 'Challenge Dynasty', type: 'website' },
  twitter: { card: 'summary', title: 'CHALLENGE DYNASTY', description: 'Reta, compite y construye tu reputación deportiva.' },
}

export const viewport: Viewport = { themeColor: '#0A0A0C', colorScheme: 'dark' }

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const locale = await getLocale()
  const messages = await getMessages()
  return <html lang={locale}><body>
    <NextIntlClientProvider locale={locale} messages={messages}>{children}</NextIntlClientProvider>
  </body></html>
}
