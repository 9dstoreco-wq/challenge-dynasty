'use client'
import { useState } from 'react'
import { toggleFollow } from '@/app/actions/social'
import { useTranslations } from 'next-intl'
export default function FollowButton({targetId,initialFollowing}:{targetId:string;initialFollowing:boolean}){const t=useTranslations('Profile');const [following,setFollowing]=useState(initialFollowing); const [busy,setBusy]=useState(false); const [err,setErr]=useState(''); async function go(){if(busy)return;setBusy(true);setErr('');try{const r=await toggleFollow(targetId);if(!r.ok){setErr(r.error);return}setFollowing(r.data)}catch{setErr(t('errGeneric'))}finally{setBusy(false)}} return <span className="inline-flex flex-col items-start"><button disabled={busy} onClick={go} className="rounded-xl border border-white/10 px-4 py-2 font-bold">{following?t('following'):t('follow')}</button>{err&&<span className="mt-1 text-xs text-red-300">{err}</span>}</span>}
