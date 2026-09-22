'use client'
import { useState } from 'react'
import { Heart, MessageCircle, Share2, UserRound, Swords } from 'lucide-react'
import { addComment, toggleLike, toggleFollow } from '@/app/actions/social'

type Comment = {id:string;content:string;user_name?:string|null}
type Post = {id:string;user_id:string;username:string;full_name:string;created_at:string;type:string;title?:string|null;content:string|null;liked_by_me?:boolean;likes_count?:number;following_by_me?:boolean;comments?:Comment[];match?:{winner_name:string;loser_name:string;challenge_id:string;score_set1?:string|null;score_set2?:string|null;score_set3?:string|null}|null}

export default function SocialPostCard({ post, currentUserId }: { post:Post; currentUserId?:string|null }) {
  const [liked, setLiked] = useState(Boolean(post.liked_by_me))
  const [likes, setLikes] = useState(Number(post.likes_count || 0))
  const [comment, setComment] = useState('')
  const [comments, setComments] = useState<Comment[]>(post.comments || [])
  const [following, setFollowing] = useState(Boolean(post.following_by_me))
  const [busy, setBusy] = useState(false)
  async function like(){ if(!currentUserId) return; setBusy(true); try { const next=await toggleLike(post.id); setLiked(next); setLikes(v=>v+(next?1:-1)) } finally { setBusy(false) } }
  async function commentSubmit(e:React.FormEvent){ e.preventDefault(); if(!currentUserId || !comment.trim()) return; setBusy(true); try { await addComment(post.id,comment.trim()); setComments(v=>[...v,{id:crypto.randomUUID(),content:comment.trim(),user_name:'Tú'}]); setComment('') } finally { setBusy(false) } }
  async function follow(){ if(!currentUserId || !post.user_id) return; setBusy(true); try { setFollowing(await toggleFollow(post.user_id)) } finally { setBusy(false) } }
  const match = post.match
  return <article className="rounded-3xl border border-white/10 bg-[#161616] overflow-hidden">
    <div className="p-5 flex items-start justify-between"><div className="flex items-center gap-3"><div className="h-10 w-10 rounded-full bg-gradient-to-br from-gold-300 to-gold-600"/><div><a href={`/u/${post.username}`} className="font-bold hover:text-[#D4AF37]">{post.full_name}</a><div className="text-xs text-white/40">{new Date(post.created_at).toLocaleString('es-CO')}</div></div></div>{currentUserId && post.user_id!==currentUserId && <button onClick={follow} disabled={busy} className="text-xs rounded-full border border-white/10 px-3 py-1.5 text-white/60">{following?'Siguiendo':'Seguir'}</button>}</div>
    <div className="px-5 pb-5"><div className="text-xs tracking-[.2em] text-[#D4AF37]">{post.type==='AUTO_MATCH_RESULT'?'🏆 RESULTADO OFICIAL':'POST'}</div>{post.title && <h3 className="text-xl font-black mt-2">{post.title}</h3>}<p className="mt-3 text-white/80 whitespace-pre-wrap">{post.content}</p>
      {match && <div className="mt-4 rounded-2xl bg-white/5 p-4"><div className="text-xs text-white/40">RESULTADO</div><div className="text-lg font-black mt-1">{match.winner_name} {match.score_set1 && `· ${match.score_set1}`} {match.score_set2 && `· ${match.score_set2}`} {match.score_set3 && `· ${match.score_set3}`} <span className="text-white/30">vs</span> {match.loser_name}</div><a href={`/challenge/${match.challenge_id}`} className="inline-flex mt-3 rounded-xl bg-[#D4AF37] text-black px-3 py-2 text-xs font-black"><Swords size={14}/> REVANCHA</a></div>}
      <div className="flex items-center gap-5 pt-4 mt-4 border-t border-white/10"><button disabled={busy||!currentUserId} onClick={like} className={`flex items-center gap-2 text-sm ${liked?'text-pink-400':'text-white/55'}`}><Heart size={17} fill={liked?'currentColor':'none'}/>{likes}</button><span className="flex items-center gap-2 text-sm text-white/45"><MessageCircle size={17}/>{comments.length}</span><button className="text-white/45 ml-auto"><Share2 size={17}/></button></div>
      {currentUserId && <form onSubmit={commentSubmit} className="mt-4 flex gap-2"><input value={comment} onChange={e=>setComment(e.target.value)} placeholder="Comenta..." className="flex-1 rounded-xl bg-white/5 border border-white/10 px-3 py-2 text-sm"/><button disabled={busy||!comment.trim()} className="rounded-xl bg-white/10 px-4 text-sm font-black">Enviar</button></form>}
      {comments.slice(-3).map(c=><div key={c.id} className="mt-3 text-sm"><span className="font-bold">{c.user_name||'Jugador'}:</span> <span className="text-white/65">{c.content}</span></div>)}
    </div>
  </article>
}
