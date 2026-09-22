import { notFound } from 'next/navigation'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import SkillSubmissionForm from '@/components/SkillSubmissionForm'
import VoteSkillButton from '@/components/VoteSkillButton'
import { createClient } from '@/lib/supabase/server'

export const dynamic = 'force-dynamic'

export default async function TrickDetail({params}:{params:Promise<{id:string}>}){
  const { id } = await params
  const supabase=await createClient()
  const {data:challenge}=await supabase.from('skill_challenges').select('id,title,description,category,difficulty,points,target_votes,status,expires_at,created_at,creator_id').eq('id',id).maybeSingle()
  if(!challenge) notFound()
  const [{data:creator},{data:submissions}]=await Promise.all([
    supabase.from('profiles').select('id,display_name,username').eq('id',challenge.creator_id).maybeSingle(),
    supabase.from('skill_submissions').select('id,user_id,video_url,caption,votes,skill_points_awarded,created_at').eq('challenge_id',challenge.id).order('votes',{ascending:false}).order('created_at',{ascending:false})
  ])
  const submitterIds=[...new Set((submissions??[]).map((x)=>x.user_id).filter(Boolean))]
  const {data:submitters}=submitterIds.length?await supabase.from('profiles').select('id,display_name,username').in('id',submitterIds):{data:[]}
  const bySubmitter=new Map((submitters??[]).map((x)=>[x.id,x]))
  return <div className="min-h-screen bg-[#0A0A0C] grid-bg text-white"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-5xl mx-auto px-4 md:px-8 py-8 space-y-6"><section className="rounded-3xl border border-[#D4AF37]/20 bg-gradient-to-br from-[#161616] via-[#101827] to-[#0A0A0C] p-6 md:p-10"><div className="flex flex-wrap items-center gap-2 text-xs font-black"><span className="rounded-full bg-[#D4AF37]/10 text-[#D4AF37] px-3 py-1">{challenge.category}</span><span className="rounded-full bg-white/5 px-3 py-1">{challenge.difficulty}</span><span className="rounded-full bg-white/5 px-3 py-1">+{challenge.points} XP</span></div><h1 className="text-4xl md:text-5xl font-display font-black tracking-wide mt-5">{challenge.title}</h1><p className="text-white/55 mt-4 max-w-3xl">{challenge.description??'Demuestra tu habilidad y consigue reconocimiento de la comunidad.'}</p><div className="text-xs text-white/35 mt-5">Creado por {creator?.display_name??creator?.username??'Jugador Dynasty'} · {submissions?.length??0} pruebas</div></section><SkillSubmissionForm challengeId={challenge.id}/><section className="space-y-4"><h2 className="text-2xl font-black">PRUEBAS DE LA COMUNIDAD</h2>{(submissions??[]).map((s)=>{const u=bySubmitter.get(s.user_id);return <article key={s.id} className="rounded-3xl border border-white/10 bg-[#161616] p-5"><div className="flex flex-col md:flex-row md:items-start md:justify-between gap-4"><div><div className="font-black text-lg">{u?.display_name??u?.username??'Jugador'}</div><div className="text-xs text-white/35 mt-1">{new Date(s.created_at).toLocaleString('es-CO')}</div></div><div className="flex items-center gap-2"><span className="text-xs text-white/35">{s.votes} votos</span><span className="text-xs font-black text-[#00E676]">+{s.skill_points_awarded??0} XP</span><VoteSkillButton submissionId={s.id}/></div></div>{s.caption&&<p className="text-white/55 mt-4">{s.caption}</p>}<a href={s.video_url} target="_blank" rel="noreferrer" className="inline-flex mt-4 rounded-xl bg-white/5 border border-white/10 px-4 py-3 text-xs font-black">VER PRUEBA ↗</a></article>})}{(submissions??[]).length===0&&<div className="rounded-3xl border border-white/10 bg-[#161616] p-8 text-center text-white/45">Todavía no hay pruebas. Sube la primera.</div>}</section></div></main><BottomNav/></div>
}
