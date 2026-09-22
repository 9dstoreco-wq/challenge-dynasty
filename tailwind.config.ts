import type { Config } from 'tailwindcss'
const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        challenge: { bg: '#0A0A0C', card: '#161616', cyan: '#D4AF37', fire: '#FF3D00', gold: '#D4AF37', success: '#00E676' },
        gold: {
          50: '#FBF3D9', 100: '#F6E6B3', 200: '#EDCE73', 300: '#E3B93E',
          400: '#D4AF37', 500: '#C49A2C', 600: '#A67C1F', 700: '#8A6418',
          800: '#6E4F13', 900: '#54390E',
        },
      },
      fontFamily: {
        display: ['var(--font-display)', 'ui-sans-serif', 'system-ui'],
      },
    },
  },
  plugins: [],
}
export default config
