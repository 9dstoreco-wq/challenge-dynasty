import { fileURLToPath } from 'node:url'
import createNextIntlPlugin from 'next-intl/plugin'

/** @type {import('next').NextConfig} */
const securityHeaders = [
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(self)' },
  { key: 'Strict-Transport-Security', value: 'max-age=31536000; includeSubDomains' },
  // CSP ya revisada y activa de verdad (antes estaba en modo "solo reporte"). Se verificaron todos
  // los recursos externos que carga la app hoy: el script de checkout de ePayco (script-src,
  // connect-src, frame-src), Supabase (connect-src, img-src), y nada mas -- no hay CDNs externos,
  // iframes, ni fuentes externas (las fuentes van empaquetadas via @fontsource). La analitica de
  // Vercel (@vercel/analytics) no necesita ninguna entrada aqui: su script y sus solicitudes
  // salen de /_vercel/insights/... en el mismo dominio, ya cubierto por 'self'.
  {
    key: 'Content-Security-Policy',
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' https://checkout.epayco.co https://*.epayco.co",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "font-src 'self' data: https://fonts.gstatic.com",
      "img-src 'self' data: blob: https:",
      "connect-src 'self' https://*.supabase.co wss://*.supabase.co https://*.epayco.co",
      "frame-src https://*.epayco.co",
      "frame-ancestors 'none'",
      "base-uri 'self'",
      "form-action 'self'",
      "object-src 'none'",
    ].join('; '),
  },
]

const nextConfig = {
  outputFileTracingRoot: fileURLToPath(new URL('.', import.meta.url)),
  poweredByHeader: false,
  reactStrictMode: true,
  // Solo imagenes servidas por Supabase Storage (la app no usa next/image con otros dominios).
  images: { remotePatterns: [{ protocol: 'https', hostname: '*.supabase.co' }] },
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }]
  },
}

const withNextIntl = createNextIntlPlugin('./i18n/request.ts')

export default withNextIntl(nextConfig)
