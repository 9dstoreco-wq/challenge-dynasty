'use client'
import { useState } from 'react'
import { voteSkillSubmission } from '@/app/actions/skills'
export default function VoteSkillButton({submissionId}:{submissionId:string}){const [busy,setBusy]=useState(false);const [done,setDone]=useState(false);return <button disabled={busy||done} onClick={async()=>{setBusy(true);try{await voteSkillSubmission(submissionId,5);setDone(true)}finally{setBusy(false)}}} className="rounded-xl bg-[#00F0FF] text-black px-4 py-2 text-xs font-black">{done?'VOTADO':'VOTAR 5'}</button>}
