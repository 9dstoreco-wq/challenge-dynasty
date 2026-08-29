import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(SCRIPT_DIR, '..');
process.chdir(root);

const required = [
  'app/layout.tsx','app/loading.tsx','app/error.tsx','app/not-found.tsx',
  'app/robots.ts','app/sitemap.ts','public/manifest.webmanifest','public/icon.svg',
  'supabase/schema_master.sql','package.json'
];
const missing = required.filter(f => !fs.existsSync(f));
if (missing.length) { console.error('Missing production files:', missing); process.exit(1); }

const textFiles = ['app','components','lib','supabase','scripts'];
const stack=[];
function walk(dir){ for(const ent of fs.readdirSync(dir,{withFileTypes:true})){ const full=path.join(dir,ent.name); if(ent.name==='node_modules' || ent.name==='.next') continue; if(ent.isDirectory()) walk(full); else stack.push(full); } }
for(const d of textFiles) if(fs.existsSync(d)) walk(d);
const risky=[];
for(const f of stack){
  const ext=path.extname(f);
  if(!['.ts','.tsx','.js','.mjs','.sql','.json','.css','.md'].includes(ext)) continue;
  const s=fs.readFileSync(f,'utf8');
  if(/(?:service_role_key\s*[:=]|SUPABASE_SERVICE_ROLE_KEY\s*[:=]|sk_live_[A-Za-z0-9]+)/.test(s)) risky.push(f);
}
if(risky.length){ console.error('Potential secret references:', risky); process.exit(1); }

const forbiddenRuntimeSecrets = [];
for(const f of stack){
  if(!/^((app|components|lib)\/)/.test(f)) continue;
  const ext=path.extname(f);
  if(!['.ts','.tsx','.js','.mjs','.json','.md'].includes(ext)) continue;
  const s=fs.readFileSync(f,'utf8');
  if(/(?:PRIVATE_KEY|SERVICE_ROLE|SECRET_KEY|sk_live_)/i.test(s)) forbiddenRuntimeSecrets.push(f);
}
if(forbiddenRuntimeSecrets.length){ console.error('Forbidden runtime secret patterns:', forbiddenRuntimeSecrets); process.exit(1); }

const disabledContracts = [];
const liveContracts = [
  ['app/actions/skills.ts','create_skill_challenge'],
  ['app/actions/partners.ts','request_partner'],
  ['app/tricks/new/page.tsx','CreateSkillChallengeForm']
];
for(const [f, marker] of liveContracts){
  const s=fs.readFileSync(f,'utf8');
  if(!s.includes(marker)) { console.error(`Live contract missing: ${f}`); process.exit(1); }
}
for(const [f, marker] of disabledContracts){
  const s=fs.readFileSync(f,'utf8');
  if(!s.toLowerCase().includes(marker)) { console.error(`Disabled contract is not explicit: ${f}`); process.exit(1); }
}
const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));
for(const key of ['build','start','typecheck','verify:release']) if(!pkg.scripts?.[key]){ console.error(`Missing npm script: ${key}`); process.exit(1); }
if(!pkg.dependencies?.next || !/^15\./.test(pkg.dependencies.next)) { console.error('Unsupported Next.js major for this release'); process.exit(1); }
const manifest=JSON.parse(fs.readFileSync('public/manifest.webmanifest','utf8'));
if(manifest.start_url!=='/' || manifest.display!=='standalone') { console.error('Invalid web manifest'); process.exit(1); }
console.log('Production structure check: PASS');
