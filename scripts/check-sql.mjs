import fs from 'node:fs'
const root=process.cwd()
const dirs=['app','components','lib']
const scan=[]
function walk(dir){for(const ent of fs.readdirSync(dir,{withFileTypes:true})){if(['node_modules','.next'].includes(ent.name)) continue; const p=`${dir}/${ent.name}`; if(ent.isDirectory()) walk(p); else if(/\.(tsx|ts)$/.test(ent.name)) scan.push(p)}}
for(const d of dirs) walk(`${root}/${d}`)
const src=scan.map(p=>fs.readFileSync(p,'utf8')).join('\n').toLowerCase()
const forbidden=['profile_sports','blocked_profiles','partner_requests','submit_match_result','confirm_match','cancel_challenge','respond_to_challenge(']
for(const token of forbidden){if(src.includes(token)) throw new Error(`Legacy contract detected in app sources: ${token}`)}
for(const token of ['create_challenge','respond_to_challenge_invitation','submit_challenge_result','review_challenge_result']) if(!src.includes(token)) throw new Error(`Expected live challenge contract missing: ${token}`)
console.log('SQL/source contract check: PASS')
