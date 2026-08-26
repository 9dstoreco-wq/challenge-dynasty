'use client'
import { useState } from 'react'
import { toggleFollow } from '@/app/actions/social'
export default function FollowButton({targetId,initialFollowing}:{targetId:string;initialFollowing:boolean}){const [following,setFollowing]=useState(initialFollowing); const [busy,setBusy]=useState(false); async function go(){setBusy(true);try{setFollowing(await toggleFollow(targetId))}finally{setBusy(false)}} return <button disabled={busy} onClick={go} className="rounded-xl border border-white/10 px-4 py-2 font-bold">{following?'✓ Siguiendo':'Seguir'}</button>}
