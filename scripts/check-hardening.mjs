import fs from 'node:fs'
import path from 'node:path'
const root=process.cwd()
const requiredFiles=[
  'app/settings/page.tsx','app/search/page.tsx','app/history/page.tsx','app/tricks/new/page.tsx','app/tricks/[id]/page.tsx',
  'app/actions/profile.ts','app/actions/skills.ts','components/ProfileSettingsForm.tsx','components/CreateSkillChallengeForm.tsx',
  'components/SkillSubmissionForm.tsx','components/VoteSkillButton.tsx'
]
for(const f of requiredFiles) if(!fs.existsSync(path.join(root,f))) throw new Error(`MISSING ${f}`)
const sourceFiles=['app/actions/social.ts','app/actions/challenges.ts','app/notifications/page.tsx','app/settings/page.tsx']
const source=sourceFiles.map(f=>fs.readFileSync(path.join(root,f),'utf8')).join('\n')
for(const token of ['profile_sports','blocked_profiles','partner_requests','confirm_match','submit_match_result','cancel_challenge']) if(source.includes(token)) throw new Error(`LEGACY CONTRACT ${token}`)
for(const token of ['social_follows','user_blocks','respond_to_challenge_invitation','submit_challenge_result','review_challenge_result','mark_notification_read']) if(!source.includes(token)) throw new Error(`MISSING LIVE CONTRACT ${token}`)
for(const marker of ["clean.length > 2000","clean.length > 600","No puedes seguirte a ti mismo"]) {
  const s=fs.readFileSync(path.join(root,'app/actions/social.ts'),'utf8'); if(!s.includes(marker)) throw new Error(`MISSING SOCIAL GUARD ${marker}`)
}
console.log('Hardening check: PASS')
