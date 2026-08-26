import fs from 'node:fs'
import path from 'node:path'

const root = process.cwd()
const required = [
  'app/actions/challenges.ts',
  'app/challenge/[id]/page.tsx',
  'components/ChallengeActions.tsx',
  'components/MatchResultForm.tsx',
  'supabase/schema_master.sql',
]
for (const file of required) {
  if (!fs.existsSync(path.join(root, file))) throw new Error(`MISSING ${file}`)
}
const action = fs.readFileSync(path.join(root, 'app/actions/challenges.ts'), 'utf8')
const page = fs.readFileSync(path.join(root, 'app/challenge/[id]/page.tsx'), 'utf8')
const actionsUi = fs.readFileSync(path.join(root, 'components/ChallengeActions.tsx'), 'utf8')
const form = fs.readFileSync(path.join(root, 'components/MatchResultForm.tsx'), 'utf8')
for (const name of ['createChallenge','respondToChallenge','submitMatchResult','confirmMatch']) {
  if (!action.includes(`export async function ${name}`)) throw new Error(`MISSING ACTION ${name}`)
}
for (const marker of ["from('challenge_participants')", "from('challenge_invitations')", "from('matches')", "from('match_results')", 'MatchResultForm']) {
  if (!page.includes(marker)) throw new Error(`MISSING LIVE FLOW ${marker}`)
}
for (const marker of ['respondToChallenge','ACEPTAR RETO']) {
  if (!actionsUi.includes(marker)) throw new Error(`MISSING CHALLENGE UI ${marker}`)
}
for (const marker of ['submitMatchResult','confirmMatch','RESULTADO PENDIENTE','CONFIRMAR RESULTADO']) {
  if (!form.includes(marker)) throw new Error(`MISSING RESULT UI ${marker}`)
}
console.log('CORE FLOW: PASS')
