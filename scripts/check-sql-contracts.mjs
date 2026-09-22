// check-sql-contracts.mjs
//
// WHY THIS SCRIPT EXISTS (2026-09-21 incident):
// `app/onboarding/page.tsx` and `app/actions/profile.ts` wrote
// relationship:'player' into `player_sports`, a value that has never been
// allowed by the live `player_sports_relationship_check` constraint
// (active|primary|secondary|learning|following|discover). `verify:release`
// passed anyway because nothing in the release gate ever compared the
// literal values the app writes against the actual Supabase CHECK
// constraints — typecheck and build only prove the code compiles, not that
// it satisfies the database contract.
//
// This script closes that gap statically (no live DB call, so it stays
// fast and works offline/in CI): it loads a committed snapshot of every
// `col = ANY (ARRAY[...])` CHECK constraint in the public schema
// (scripts/contracts/sql-check-constraints.json, regenerated from the live
// project — see "Refreshing the snapshot" below), scans app/lib/components
// for `supabase.from('table').insert/update/upsert({...})` calls, and fails
// the build if any literal string assigned to a constrained column is not
// in that column's allowed set.
//
// Refreshing the snapshot (run after any migration that touches a CHECK
// constraint on an enum-like text column):
//   select conrelid::regclass as table_name, conname, pg_get_constraintdef(oid) as definition
//   from pg_constraint where contype='c' and connamespace='public'::regnamespace;
// then regenerate scripts/contracts/sql-check-constraints.json from rows
// shaped like `col = ANY (ARRAY['a','b'])`.
//
// Known limitation: this only checks literal string values written directly
// from the Next.js app. Values written inside Postgres SECURITY DEFINER
// RPC functions are not visible to this static scan (they live in the
// database, not this repo) — those must be reviewed manually or with a
// live-DB smoke test whenever an RPC is added or changed.

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(SCRIPT_DIR, '..')

const contract = JSON.parse(fs.readFileSync(path.join(SCRIPT_DIR, 'contracts', 'sql-check-constraints.json'), 'utf8'))

const dirs = ['app', 'components', 'lib', 'activation']
const files = []
function walk(dir) {
  if (!fs.existsSync(dir)) return
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (['node_modules', '.next'].includes(ent.name)) continue
    const p = `${dir}/${ent.name}`
    if (ent.isDirectory()) walk(p)
    else if (/\.(tsx|ts)$/.test(ent.name)) files.push(p)
  }
}
for (const d of dirs) walk(path.join(root, d))

// Matches: .from('table') ... .insert({ ... }) / .update({ ... }) / .upsert({ ... })
// The object body is captured non-greedily up to the first top-level `}`,
// which is sufficient for this codebase's flat (non-nested) write payloads.
const WRITE_RE = /\.from\((['"])([a-z_]+)\1\)[\s\S]{0,80}?\.(insert|update|upsert)\(\s*\{([^}]*)\}/g
// Matches: field_name: 'literal' / field_name:"literal" (any number per field, e.g. ternaries)
const FIELD_RE = /(\w+)\s*:\s*([^,}]+)/g
const STRING_LITERAL_RE = /'([^'\\]*(?:\\.[^'\\]*)*)'|"([^"\\]*(?:\\.[^"\\]*)*)"/g

let violations = []
let checkedWrites = 0

for (const file of files) {
  const src = fs.readFileSync(file, 'utf8')
  let m
  WRITE_RE.lastIndex = 0
  while ((m = WRITE_RE.exec(src))) {
    const table = m[2]
    const body = m[4]
    checkedWrites++
    let fm
    FIELD_RE.lastIndex = 0
    while ((fm = FIELD_RE.exec(body))) {
      const column = fm[1]
      const expr = fm[2]
      const key = `${table}.${column}`
      const allowed = contract[key]
      if (!allowed) continue // column not under an enum-like CHECK constraint we know about
      let lm
      STRING_LITERAL_RE.lastIndex = 0
      while ((lm = STRING_LITERAL_RE.exec(expr))) {
        const value = lm[1] !== undefined ? lm[1] : lm[2]
        if (!allowed.includes(value)) {
          const line = src.slice(0, m.index + fm.index).split('\n').length
          violations.push(
            `${path.relative(root, file)}:${line} writes ${key} = '${value}', but the live CHECK constraint only allows: ${allowed.join(', ')}`
          )
        }
      }
    }
  }
}

if (violations.length) {
  console.error('SQL contract check: FAIL')
  for (const v of violations) console.error(`  - ${v}`)
  throw new Error(`${violations.length} write(s) use a value the live Supabase CHECK constraint does not allow. Fix the app code (do not weaken the constraint) unless the constraint itself is proven wrong.`)
}

console.log(`SQL contract check: PASS (${checkedWrites} insert/update/upsert call(s) scanned against ${Object.keys(contract).length} known CHECK-constrained columns)`)
