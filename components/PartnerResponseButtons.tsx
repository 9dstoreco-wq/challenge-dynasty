'use client'
import { useState } from 'react'
import { respondToPartnerRequest } from '@/app/actions/social'
import { useTranslations } from 'next-intl'

export default function PartnerResponseButtons({ id }: { id: string }) {
  const t = useTranslations('Social')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState('')
  async function act(r: 'ACCEPTED' | 'REJECTED') {
    if (busy) return
    setBusy(true); setErr('')
    try {
      const res = await respondToPartnerRequest(id, r)
      if (!res.ok) { setErr(res.error); setBusy(false); return }
      window.location.reload()
    } catch { setErr(t('errGeneric')); setBusy(false) }
  }
  return <div><div className="flex gap-2"><button disabled={busy} onClick={() => act('ACCEPTED')} className="rounded-xl bg-[#00E676] text-black px-3 py-2 text-xs font-black">ACEPTAR</button><button disabled={busy} onClick={() => act('REJECTED')} className="rounded-xl bg-white/5 px-3 py-2 text-xs font-black">RECHAZAR</button></div>{err && <p className="mt-2 text-xs text-red-300">{err}</p>}</div>
}
