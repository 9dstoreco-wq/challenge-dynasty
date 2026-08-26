import type { Config } from 'tailwindcss'
const config: Config = { content: ['./app/**/*.{ts,tsx}','./components/**/*.{ts,tsx}'], theme: { extend: { colors: { challenge: { bg:'#0B0F19', card:'#141B2D', cyan:'#00F0FF', fire:'#FF3D00', gold:'#FFD700', success:'#00E676' }}}}, plugins:[] }
export default config
