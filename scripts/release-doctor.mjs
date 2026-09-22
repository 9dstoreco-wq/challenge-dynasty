import { existsSync, readFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'

const fail = (message) => {
  console.error(`RELEASE DOCTOR: FAIL — ${message}`)
  process.exit(1)
}
const pass = (message) => console.log(`RELEASE DOCTOR: PASS — ${message}`)

const pkg = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'))
const major = Number(process.versions.node.split('.')[0])
if (major < 20) fail(`Node 20+ required; detected ${process.versions.node}`)
pass(`Node ${process.versions.node} (CI pins Node 20)`)

let npmVersion = 'unknown'
try { npmVersion = execFileSync(process.platform === 'win32' ? 'npm.cmd' : 'npm', ['--version'], { encoding: 'utf8', shell: true }).trim() } catch { fail('npm is not available') }
pass(`npm ${npmVersion}`)

for (const envName of ['NEXT_PUBLIC_SUPABASE_URL', 'NEXT_PUBLIC_SUPABASE_ANON_KEY']) {
  if (!process.env[envName]) fail(`missing ${envName}`)
}
pass('required public Supabase environment variables present')

for (const script of ['check-routes','check-sql','check-sql-contracts','check-rpc-status-literals','check-error-sanitization','check-core-flow','check-production','check-hardening','typecheck','build']) {
  if (!pkg.scripts?.[script]) fail(`package.json missing script: ${script}`)
}
pass('all release scripts present')

if (!existsSync(new URL('../.github/workflows/production-gate.yml', import.meta.url))) {
  fail('Production Gate workflow missing')
}
pass('Production Gate workflow present')

if (!existsSync(new URL('../node_modules', import.meta.url))) {
  if (!existsSync(new URL('../package-lock.json', import.meta.url))) {
    fail('dependencies are not installed and package-lock.json is missing; run npm install once in a networked environment, then commit package-lock.json')
  }
  fail('dependencies are not installed; run npm ci')
}
pass('node_modules present')

const run = (script) => {
  console.log(`\n>>> npm run ${script}`)
  execFileSync(process.platform === 'win32' ? 'npm.cmd' : 'npm', ['run', script], { stdio: 'inherit', env: process.env, shell: true })
}
for (const script of ['check-routes','check-sql','check-sql-contracts','check-rpc-status-literals','check-error-sanitization','check-core-flow','check-production','check-hardening','typecheck','build']) run(script)
pass('FULL RELEASE GATE')
