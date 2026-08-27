import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(SCRIPT_DIR, '..')
const app=path.join(root,'app')
const routes=[]
function walk(dir, parts=[]){
  for(const entry of fs.readdirSync(dir,{withFileTypes:true})){
    const full=path.join(dir,entry.name)
    if(entry.isDirectory()) walk(full,[...parts,entry.name])
    else if(entry.name==='page.tsx') routes.push('/'+parts.join('/'))
  }
}
walk(app)
const routeSet=new Set(routes)
const refs=new Set()
for(const dir of ['app','components']){
  const base=path.join(root,dir)
  if(!fs.existsSync(base)) continue
  const files=[]
  function walk2(d){for(const e of fs.readdirSync(d,{withFileTypes:true})){const f=path.join(d,e.name);if(e.isDirectory())walk2(f);else if(/\.(tsx|ts)$/.test(e.name))files.push(f)}}
  walk2(base)
  for(const f of files){
    const s=fs.readFileSync(f,'utf8')
    for(const m of s.matchAll(/href=["'](\/[A-Za-z0-9_\[\]\/\-\.]+)["']/g)) refs.add(m[1])
  }
}
const unresolved=[...refs].filter(r=>r!=='/' && !routeSet.has(r) && !routeSet.has(r.replace(/\/[^/]+$/,'/[id]')) && !routeSet.has(r.replace(/\/u\/[^/]+$/,'/u/[username]')))
console.log('Routes found:', routes.sort())
console.log('Static hrefs:', [...refs].sort())
if(unresolved.length){console.error('UNRESOLVED ROUTES:', unresolved);process.exit(1)}
console.log('Route check: PASS')
