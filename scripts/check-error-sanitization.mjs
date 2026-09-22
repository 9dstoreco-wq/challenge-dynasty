// check-error-sanitization.mjs
//
// WHY THIS SCRIPT EXISTS (2026-09-21 error-sanitization audit):
// Server actions and client components across this app used to relay
// `error.message` from Supabase (Postgres/PostgREST) straight into UI state
// or an API JSON response -- e.g. `setMessage(error.message)` or
// `throw new Error(error.message)`. That string can be raw Postgres
// internals: a relation/column/constraint name, "violates check
// constraint...", a raw SQL syntax error, a pg_* error code. lib/safe-error.ts
// (`toSafeMessage`) is now the single choke point every one of those sites
// must go through; the full raw error still reaches server/console logs via
// that function, it just no longer reaches the rendered UI or an API
// response body.
//
// This script is the regression gate for that fix: it fails the build if a
// NEW raw `error.message` / `e.message` read on a Supabase `{ error }`
// result reaches a UI sink (setState, JSON response, thrown Error) without
// going through toSafeMessage(...) first, anywhere under app/, components/,
// or lib/ -- excluding two categories that are safe by construction and
// listed explicitly below so the reason is auditable, not just silenced:
//
//   1. lib/safe-error.ts itself (the sanitizer's own implementation reads
//      `error.message` -- that is its job).
//   2. app/actions/**/*.ts (server actions): these are the sanctioned
//      sanitization boundary. Every Supabase error in that directory is
//      already wrapped as `throw new Error(toSafeMessage(error, ...))`
//      (verified by this same script's SANCTIONED_BOUNDARY pass below, which
//      fails if a new raw `error.message` throw shows up there instead).
//
// A known, audited consequence of (2): a handful of client components catch
// the Error thrown BY those server actions and read `e.message` --
// ChallengeActions.tsx, CreateSkillChallengeForm.tsx, MatchResultForm.tsx,
// NewChallengeForm.tsx, PartnerInviteButton.tsx, ProfileSettingsForm.tsx,
// SkillSubmissionForm.tsx. That `e.message` is already the sanitized string
// (toSafeMessage ran inside the action before the throw left the server), so
// it is not a leak -- it is listed in KNOWN_SAFE_PASSTHROUGH below with the
// server action it consumes, so the exemption is explicit and reviewable
// rather than a silent gap in this gate. Adding a NEW file to that list
// requires confirming the try block calls only already-sanitized
// app/actions/* functions and never a direct supabase.from/.rpc call.
//
// Known limitation (same category as check-sql-contracts.mjs): this is a
// regex heuristic, not a type-aware analyzer. It cannot prove a given `e` is
// an Error thrown by a sanctioned action vs. some other raw error; that
// judgment is made once, by a human, when a file is added to
// KNOWN_SAFE_PASSTHROUGH, and is re-checked by this script only insofar as
// it confirms the file still contains no direct supabase.from/.rpc call.

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(SCRIPT_DIR, '..')

// Files allowed to read `e.message` / `error.message` because they only ever
// catch the already-sanitized Error thrown by the named app/actions/*.ts
// function(s) -- never a direct supabase.from/.rpc call of their own.
const KNOWN_SAFE_PASSTHROUGH = {
  'components/ChallengeActions.tsx': ['app/actions/challenges.ts'],
  'components/CreateSkillChallengeForm.tsx': ['app/actions/skills.ts'],
  'components/MatchResultForm.tsx': ['app/actions/challenges.ts'],
  'components/NewChallengeForm.tsx': ['app/actions/challenges.ts'],
  'components/PartnerInviteButton.tsx': ['app/actions/partners.ts'],
  'components/ProfileSettingsForm.tsx': ['app/actions/profile.ts'],
  'components/SkillSubmissionForm.tsx': ['app/actions/skills.ts'],
}

const EXCLUDED_FILES = new Set(['lib/safe-error.ts'])

const dirs = ['app', 'components', 'lib']
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

// Matches `error.message`, `error?.message`, `e.message`, `e?.message` that
// is NOT immediately preceded by `toSafeMessage(` on the same statement.
// (i.e. not already wrapped: `toSafeMessage(error, ...)` never itself
// contains the literal substring `error.message`.)
const RAW_MESSAGE_RE = /\b(error|e|rpcError)\??\.message\b/g

const violations = []
let scanned = 0

for (const file of files) {
  const rel = path.relative(root, file).replace(/\\/g, '/')
  if (EXCLUDED_FILES.has(rel)) continue
  const src = fs.readFileSync(file, 'utf8')
  scanned++

  const isSanctionedAction = rel.startsWith('app/actions/')
  const safePassthroughSources = KNOWN_SAFE_PASSTHROUGH[rel]

  if (safePassthroughSources) {
    // Confirm the exemption still holds: no direct Supabase call of its own.
    if (/supabase\.(from|rpc)\(/.test(src)) {
      violations.push(
        `${rel} is listed in KNOWN_SAFE_PASSTHROUGH (assumed to only consume already-sanitized errors from ${safePassthroughSources.join(', ')}) but now calls supabase.from/.rpc directly -- re-review and sanitize with toSafeMessage(...) if it handles a new raw error.`
      )
    }
    continue
  }

  let m
  RAW_MESSAGE_RE.lastIndex = 0
  while ((m = RAW_MESSAGE_RE.exec(src))) {
    const idx = m.index
    // Look at a small window before the match: if it's immediately inside a
    // toSafeMessage(...) call, it's the sanitizer's own well-known signature
    // being referenced in this scanner's regex, not a raw passthrough. The
    // real sanitized call sites look like `toSafeMessage(error, 'ctx')` and
    // never spell out `error.message` at all, so this window check is a
    // belt-and-suspenders guard against future refactors, not load-bearing.
    const windowStart = Math.max(0, idx - 200)
    const before = src.slice(windowStart, idx)
    const line = src.slice(0, idx).split('\n').length

    if (isSanctionedAction) {
      // Inside app/actions/**: every raw error read must feed toSafeMessage(...)
      // before it can leave the function (thrown or returned).
      const after = src.slice(idx, idx + 40)
      const wrapped = /toSafeMessage\(\s*(error|e|rpcError)\s*,/.test(before + after) || /toSafeMessage\(/.test(before)
      if (!wrapped) {
        violations.push(`${rel}:${line} reads .message directly inside a server action; wrap with toSafeMessage(error, 'context') before throwing/returning it.`)
      }
      continue
    }

    // Outside actions/lib: any raw `.message` read is a potential leak unless
    // this exact call is wrapped in toSafeMessage(...).
    const openParenBefore = before.lastIndexOf('toSafeMessage(')
    const wrapped = openParenBefore !== -1 && !before.slice(openParenBefore).includes(')')
    if (!wrapped) {
      violations.push(`${rel}:${line} reads .message directly; route it through toSafeMessage(error, 'context') so raw Postgres/Supabase internals never reach the UI.`)
    }
  }
}

if (violations.length) {
  console.error('Error-sanitization check: FAIL')
  for (const v of [...new Set(violations)]) console.error(`  - ${v}`)
  throw new Error(`${new Set(violations).size} raw error-message read(s) found outside the sanctioned toSafeMessage() boundary. See lib/safe-error.ts.`)
}

console.log(`Error-sanitization check: PASS (${scanned} file(s) scanned, ${Object.keys(KNOWN_SAFE_PASSTHROUGH).length} documented safe-passthrough exemption(s))`)
