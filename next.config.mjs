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
  // connect-src, frame-src) y Supabase (connect-src, img-src) -- no hay CDNs externos, iframes, ni
  // fuentes externas (las fuentes van empaquetadas via @fontsource, por eso ya no se permite
  // fonts.googleapis.com/fonts.gstatic.com: no se usan y solo ampliaban la superficie sin razon).
  // La analitica de Vercel (@vercel/analytics) no necesita ninguna entrada aqui: su script y sus
  // solicitudes salen de /_vercel/insights/... en el mismo dominio, ya cubierto por 'self'.
  //
  // img-src restringido a Supabase Storage (igual que next.config images.remotePatterns abajo) en
  // vez del "https:" que dejaba cargar una <img> de cualquier host HTTPS. Hoy la app no renderiza
  // ninguna imagen con URL de usuario (revisado: profiles.avatar_url existe en la base pero nada en
  // el codigo la pinta todavia), asi que esto no cambia nada visible, pero cierra el hueco por
  // adelantado para cuando se agregue una funcion de foto de perfil o de club.
  //
  // Pendiente (no resuelto en esta pasada, documentado aqui para no perderlo): script-src y
  // style-src siguen con 'unsafe-inline'. style-src lo necesita el propio JSX de la app (atributos
  // style={{...}} inline en varios componentes) -- quitarlo implicaria sacar esos estilos a clases.
  // script-src lo necesita el propio Next.js App Router (inyecta <script> inline para el payload de
  // hidratacion/RSC) -- quitarlo requiere armar un esquema de nonce por request (middleware generando
  // un nonce, layout.tsx leyendolo y Next propagandolo a sus scripts), que es un cambio mas grande y
  // se deja para una pasada aparte en vez de arriesgar romper la hidratacion de toda la app sin poder
  // probarlo visualmente en este entorno.
  {
    key: 'Content-Security-Policy',
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' https://checkout.epayco.co https://*.epayco.co",
      "style-src 'self' 'unsafe-inline'",
      "font-src 'self' data:",
      "img-src 'self' data: blob: https://*.supabase.co",
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
