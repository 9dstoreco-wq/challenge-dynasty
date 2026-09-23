import { fileURLToPath } from 'node:url'
import createNextIntlPlugin from 'next-intl/plugin'

/** @type {import('next').NextConfig} */
const securityHeaders = [
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(self)' },
]

const nextConfig = {
  outputFileTracingRoot: fileURLToPath(new URL('.', import.meta.url)),
  poweredByHeader: false,
  reactStrictMode: true,
  images: { remotePatterns: [{ protocol: 'https', hostname: '**' }] },
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }]
  },
}

const withNextIntl = createNextIntlPlugin('./i18n/request.ts')

export default withNextIntl(nextConfig)
