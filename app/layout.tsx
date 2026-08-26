import './globals.css'
import type { Metadata, Viewport } from 'next'

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || 'https://challenge-dynasty.com'),
  title: { default: 'CHALLENGE DYNASTY', template: '%s · CHALLENGE DYNASTY' },
  description: 'Reta, compite, gana y construye tu reputación deportiva.',
  applicationName: 'Challenge Dynasty',
  category: 'sports',
  manifest: '/manifest.webmanifest',
  icons: { icon: '/icon.svg', apple: '/icon.svg' },
  openGraph: { title: 'CHALLENGE DYNASTY', description: 'La red competitiva para todos tus deportes.', siteName: 'Challenge Dynasty', type: 'website' },
  twitter: { card: 'summary', title: 'CHALLENGE DYNASTY', description: 'Reta, compite y construye tu reputación deportiva.' },
}

export const viewport: Viewport = { themeColor: '#0B0F19', colorScheme: 'dark' }

export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="es"><body>{children}</body></html>}
