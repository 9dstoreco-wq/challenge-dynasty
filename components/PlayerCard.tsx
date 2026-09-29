'use client'
import { useState } from 'react'
import { Download, Share2 } from 'lucide-react'
import { useTranslations } from 'next-intl'

export default function PlayerCard({
  profileId,
  playerName,
  result,
  opponent,
}: {
  profileId: string
  playerName?: string
  result?: 'win' | 'loss'
  opponent?: string
}) {
  const t = useTranslations('PlayerCard')
  const [busy, setBusy] = useState(false)

  const params = new URLSearchParams()
  if (result) params.set('result', result)
  if (opponent) params.set('opponent', opponent)
  const query = params.toString()
  const imgSrc = `/api/cards/${profileId}${query ? `?${query}` : ''}`

  async function fetchCardBlob() {
    const res = await fetch(imgSrc)
    if (!res.ok) throw new Error('card fetch failed')
    return res.blob()
  }

  async function handleDownload() {
    setBusy(true)
    try {
      const blob = await fetchCardBlob()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `dynasty-carta-${playerName ?? profileId}.png`
      document.body.appendChild(a)
      a.click()
      a.remove()
      URL.revokeObjectURL(url)
    } catch {
      // no-op, button stays available to retry
    } finally {
      setBusy(false)
    }
  }

  async function handleShare() {
    setBusy(true)
    try {
      const blob = await fetchCardBlob()
      const file = new File([blob], 'dynasty-carta.png', { type: 'image/png' })
      if (navigator.share && navigator.canShare?.({ files: [file] })) {
        await navigator.share({
          files: [file],
          title: 'Challenge Dynasty',
          text: t('shareText', { name: playerName ?? '' }),
        })
      } else {
        await handleDownload()
      }
    } catch {
      // user cancelled share sheet or share unsupported — no-op
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-5">
      <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black mb-3">{t('title')}</div>
      <div className="rounded-2xl overflow-hidden border border-white/10">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={imgSrc} alt={t('title')} className="w-full h-auto block" />
      </div>
      <div className="mt-4 flex gap-2">
        <button
          onClick={handleShare}
          disabled={busy}
          className="flex-1 rounded-xl bg-[#D4AF37] text-black py-2.5 text-sm font-black flex items-center justify-center gap-2 disabled:opacity-50"
        >
          <Share2 size={15} /> {t('shareBtn')}
        </button>
        <button
          onClick={handleDownload}
          disabled={busy}
          className="rounded-xl border border-white/10 px-4 py-2.5 text-sm font-bold flex items-center gap-2 hover:bg-white/5 disabled:opacity-50"
        >
          <Download size={15} /> {t('downloadBtn')}
        </button>
      </div>
    </div>
  )
}
