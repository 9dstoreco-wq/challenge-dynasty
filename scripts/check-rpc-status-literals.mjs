// check-rpc-status-literals.mjs
//
// Despite the filename (kept for history), this checks more than `status`:
// see CHECKED_COLUMNS below, extended in a follow-up pass to stage_type and
// entity_type after that same sweep found generate_round_robin_draw checking
// stage_type against 'groups' (never valid; the real value is singular
// 'group') and complete_provider_booking filtering entity_type against
// 'provider_service' (never valid; the real value is 'service') -- both
// left those RPCs permanently unusable in exactly the same way the original
// status-literal bugs did.
//
// WHY THIS SCRIPT EXISTS (2026-09-21 tournament RPC audit):
// check-sql-contracts.mjs already gates literal values the Next.js app writes
// via `.from(table).insert/update/upsert(...)`, but it explicitly documents a
// known gap: "Values written inside Postgres SECURITY DEFINER RPC functions
// are not visible to this static scan (they live in the database, not this
// repo)". That exact gap is what let 5 tournament RPC functions
// (validate_tournament_schedule, generate_round_robin_draw,
// generate_groups_to_knockout_draw, generate_single_elimination_draw,
// swap_tournament_fixture_entries) ship and stay live for an unknown period
// referencing tournament_stages.status values 'draft'/'ready' and
// tournament_entry_members.status values 'active'/'accepted' -- none of which
// the live CHECK constraints (or the guard_tournament_stage_status trigger)
// have ever allowed. The practical effect: two RPCs unconditionally raised
// STAGE_NOT_EDITABLE (unusable), two had dead "mark stage ready" UPDATEs, and
// validate_tournament_schedule silently returned valid:true / issues:[] for
// every tournament, forever, because its player-overlap filter never matched
// a real row -- the highest-severity finding of the audit.
//
// This script closes that specific gap: it statically scans every RPC
// function body checked into supabase/migrations/**/*.sql (the only place a
// human can review pending SECURITY DEFINER SQL before it is applied to
// production) for status literals compared against known enum-like columns,
// using two heuristics:
//   1. DML: `UPDATE public.<table> SET/WHERE status = '<literal>'` -- table is
//      read directly off the statement, so any table present in the SQL
//      contract snapshot is checked with no extra config.
//   2. PL/pgSQL record/alias field comparisons: `<var>.status = '<literal>'`,
//      `<var>.status IN (...)`, `<var>.status NOT IN (...)` -- resolved via
//      scripts/contracts/rpc-status-variable-map.json, since a bare `.status`
//      cannot otherwise be traced back to a table name.
//
// Known limitation (same category as check-sql-contracts.mjs): this is a
// regex heuristic, not a SQL parser. It only catches the alias/column
// patterns this codebase actually uses (see the variable map) and only
// inspects migration files committed to this repo, not functions already
// live in the database that have no corresponding migration file. A RPC
// touching one of the contracted columns through a new alias must be added
// to rpc-status-variable-map.json for this gate to see it.

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(SCRIPT_DIR, '..')

const contract = JSON.parse(fs.readFileSync(path.join(SCRIPT_DIR, 'contracts', 'sql-check-constraints.json'), 'utf8'))
const varMap = JSON.parse(fs.readFileSync(path.join(SCRIPT_DIR, 'contracts', 'rpc-status-variable-map.json'), 'utf8'))

const migrationsDir = path.join(root, 'supabase', 'migrations')
const files = fs.existsSync(migrationsDir)
  ? fs.readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).map((f) => path.join(migrationsDir, f))
  : []

const violations = []
let checkedStatements = 0
let checkedFieldRefs = 0

function lineOf(src, index) {
  return src.slice(0, index).split('\n').length
}

// Strip SQL line comments (`-- ...`) and block comments (`/* ... */`) before
// scanning so documentation/rationale text (which legitimately quotes the
// bad literals being fixed, e.g. in this file's own header) is never mistaken
// for executable SQL. Comment bodies are blanked out character-by-character
// (newlines preserved) so line numbers stay accurate for real violations.
function stripSqlComments(src) {
  let out = ''
  let i = 0
  const n = src.length
  while (i < n) {
    if (src[i] === '-' && src[i + 1] === '-') {
      while (i < n && src[i] !== '\n') { out += ' '; i++ }
      continue
    }
    if (src[i] === '/' && src[i + 1] === '*') {
      out += '  '
      i += 2
      while (i < n && !(src[i] === '*' && src[i + 1] === '/')) {
        out += src[i] === '\n' ? '\n' : ' '
        i++
      }
      if (i < n) { out += '  '; i += 2 }
      continue
    }
    out += src[i]
    i++
  }
  return out
}

// Columns checked by Pass 1/2 beyond `status` (2026-09-21 follow-up sweep
// widened the audit to every enum-like CHECK-constrained column, not just
// status -- that pass found generate_round_robin_draw checking stage_type
// against the plural 'groups' instead of the real, singular 'group', and
// complete_provider_booking filtering bookable_entities.entity_type on
// 'provider_service', a value that constraint never allows either).
const CHECKED_COLUMNS = ['status', 'stage_type', 'entity_type']

for (const file of files) {
  const rawSrc = fs.readFileSync(file, 'utf8')
  const src = stripSqlComments(rawSrc)
  const rel = path.relative(root, file)

  for (const column of CHECKED_COLUMNS) {
    // Pass 1: UPDATE/SELECT ... FROM/UPDATE public.<table> ... WHERE/SET <column> = 'literal'
    const STMT_RE = new RegExp(`(?:update|from)\\s+public\\.(\\w+)\\b[\\s\\S]{0,400}?;`, 'gi')
    let um
    while ((um = STMT_RE.exec(src))) {
      const table = um[1]
      const stmt = um[0]
      const key = `${table}.${column}`
      const allowed = contract[key]
      if (!allowed) continue
      checkedStatements++
      const LIT_RE = new RegExp(`\\b${column}\\s*(?:=|<>)\\s*'([a-z_0-9]+)'`, 'gi')
      let lm
      while ((lm = LIT_RE.exec(stmt))) {
        const value = lm[1]
        if (!allowed.includes(value)) {
          const line = lineOf(src, um.index + lm.index)
          violations.push(
            `${rel}:${line} statement touching public.${table} compares/sets ${column} = '${value}', but the live CHECK constraint only allows: ${allowed.join(', ')}`
          )
        }
      }
    }
  }

  // Pass 2: <var>.<column> = / <> / IN (...) / NOT IN (...) '<literal>' via the variable map
  for (const [key, cfg] of Object.entries(varMap)) {
    if (key.startsWith('_')) continue
    const allowed = contract[key]
    if (!allowed) continue
    const column = cfg.column || 'status'
    for (const pattern of cfg.variablePatterns) {
      const FIELD_RE = new RegExp(
        `\\b${pattern}\\.${column}\\s+(not\\s+)?in\\s*\\(([^)]*)\\)|\\b${pattern}\\.${column}\\s*(?:=|<>)\\s*'([a-z_0-9]+)'`,
        'gi'
      )
      let fm
      while ((fm = FIELD_RE.exec(src))) {
        checkedFieldRefs++
        const line = lineOf(src, fm.index)
        if (fm[2] !== undefined) {
          const literals = [...fm[2].matchAll(/'([a-z_0-9]+)'/gi)].map((x) => x[1])
          for (const value of literals) {
            if (!allowed.includes(value)) {
              violations.push(
                `${rel}:${line} ${pattern}.${column} IN/NOT IN (...) references '${value}', but the live CHECK constraint for ${key} only allows: ${allowed.join(', ')}`
              )
            }
          }
        } else if (fm[3] !== undefined) {
          const value = fm[3]
          if (!allowed.includes(value)) {
            violations.push(
              `${rel}:${line} ${pattern}.${column} compared to '${value}', but the live CHECK constraint for ${key} only allows: ${allowed.join(', ')}`
            )
          }
        }
      }
    }
  }
}

// Pass 3: known-nonexistent record-field access (2026-09-21 checkout_shop_cart
// crash). shop_cart_items has NO status column (confirmed via live
// information_schema.columns) -- only the separate shop_carts table has one
// (uppercase ACTIVE/CHECKOUT/CONVERTED/ABANDONED). checkout_shop_cart used to
// loop a record built from `ci.*` (shop_cart_items) and then read
// `v_item.status`, which is not a field on that record at all -- plpgsql
// does not catch this until the loop actually runs, so it shipped as a
// guaranteed runtime crash ("record v_item has no field status") on every
// checkout with a non-empty cart. The fix selects `p.status product_status`
// explicitly and compares that instead. This heuristic re-scans every
// `for <var> in select ... <alias>.*, ... from public.shop_cart_items
// <alias> ...` block and fails if the loop body still compares
// `<var>.status` without an explicit `status`-aliased column present in the
// same select list (e.g. `p.status product_status` would not itself trip
// this -- only a bare `status` alias or none at all would leave `.status`
// dangling).
let checkedCartItemLoops = 0
for (const file of files) {
  const src = stripSqlComments(fs.readFileSync(file, 'utf8'))
  const rel = path.relative(root, file)
  const LOOP_RE = /for\s+(\w+)\s+in\s*\n?\s*select\s+([\s\S]{0,600}?)\bfrom\s+public\.shop_cart_items\s+(\w+)\b[\s\S]{0,600}?\bloop\b([\s\S]{0,3000}?)end\s+loop/gi
  let lm
  while ((lm = LOOP_RE.exec(src))) {
    checkedCartItemLoops++
    const [, varName, selectList, , loopBody] = lm
    // A bare `status` alias (not `p.status product_status`-style renamed) would
    // legitimately make `<var>.status` valid; only flag when no such alias
    // exists in the select list but the loop body still reads `<var>.status`.
    const bareStatusAliasRe = /(?:^|,)\s*(?:\w+\.)?status\s*(?:,|$)/i
    const hasBareStatusAlias = bareStatusAliasRe.test(selectList.replace(/\n/g, ' '))
    const readsDotStatus = new RegExp(`\\b${varName}\\.status\\b`).test(loopBody)
    if (readsDotStatus && !hasBareStatusAlias) {
      const line = lineOf(src, lm.index)
      violations.push(
        `${rel}:${line} loop variable '${varName}' is built from a shop_cart_items ('ci.*'-style) select with no bare 'status' column, but the loop body reads ${varName}.status -- shop_cart_items has no status column (confirmed live); this is a guaranteed plpgsql runtime crash. See the 2026-09-21 checkout_shop_cart fix (select p.status product_status explicitly and compare that instead).`
      )
    }
  }
}

if (violations.length) {
  console.error('RPC status-literal check: FAIL')
  for (const v of [...new Set(violations)]) console.error(`  - ${v}`)
  throw new Error(`${new Set(violations).size} status literal(s) inside supabase/migrations/**/*.sql use a value the live Supabase CHECK constraint does not allow. Fix the RPC body (do not weaken the constraint) unless the constraint itself is proven wrong.`)
}

console.log(`RPC status-literal check: PASS (${checkedStatements} UPDATE statement(s), ${checkedFieldRefs} record-field reference(s), ${checkedCartItemLoops} shop_cart_items loop(s) scanned across ${files.length} migration file(s))`)
