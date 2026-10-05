'use client'
import { useState } from 'react'
import { Check, Copy, Download, Share2 } from 'lucide-react'
import { useTranslations } from 'next-intl'

export default function PlayerCard({
  profileId,
  playerName,
  username,
  result,
  opponent,
}: {
  profileId: string
  playerName?: string
  username?: string
  result?: 'win' | 'loss'
  opponent?: string
}) {
  const t = useTranslations('PlayerCard')
  const [busy, setBusy] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)
  const [copied, setCopied] = useState(false)

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

  // Enlace publico que se comparte: el perfil del jugador (se ve sin sesion). Sin username, la pagina actual.
  function getShareUrl() {
    if (typeof window === 'undefined') return ''
    return username ? `${window.location.origin}/u/${username}` : window.location.href
  }

  function getShareText() {
    return t('shareText', { name: playerName ?? '' })
  }

  function openNetwork(kind: 'whatsapp' | 'facebook' | 'x' | 'telegram') {
    const url = encodeURIComponent(getShareUrl())
    const text = encodeURIComponent(getShareText())
    const href =
      kind === 'whatsapp' ? `https://wa.me/?text=${text}%20${url}`
      : kind === 'facebook' ? `https://www.facebook.com/sharer/sharer.php?u=${url}`
      : kind === 'x' ? `https://twitter.com/intent/tweet?text=${text}&url=${url}`
      : `https://t.me/share/url?url=${url}&text=${text}`
    window.open(href, '_blank', 'noopener,noreferrer')
  }

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(getShareUrl())
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      // clipboard not available
    }
  }

  async function nativeShare() {
    setBusy(true)
    try {
      const blob = await fetchCardBlob()
      const file = new File([blob], 'dynasty-carta.png', { type: 'image/png' })
      if (navigator.share && navigator.canShare?.({ files: [file] })) {
        await navigator.share({ files: [file], title: 'Challenge Dynasty', text: getShareText(), url: getShareUrl() })
        return true
      }
      return false
    } catch {
      // user cancelled the share sheet
      return true
    } finally {
      setBusy(false)
    }
  }

  async function handleShare() {
    // En celular se usa la hoja nativa (Instagram, TikTok, WhatsApp... con la imagen). En computador, el menu de redes.
    const isMobile = typeof navigator !== 'undefined' && /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)
    if (isMobile) {
      const done = await nativeShare()
      if (done) return
    }
    setMenuOpen((v) => !v)
  }

  return (
    <div className="rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-5">
      <div className="text-xs tracking-[.2em] text-[#D4AF37] font-black mb-3">{t('title')}</div>
      <div className="rounded-2xl overflow-hidden border border-white/10">
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
      {menuOpen && (
        <div className="mt-3 rounded-2xl border border-white/10 bg-black/30 p-3">
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            <button onClick={() => openNetwork('whatsapp')} className="rounded-xl border border-white/10 py-2 text-sm font-bold hover:bg-white/5">WhatsApp</button>
            <button onClick={() => openNetwork('facebook')} className="rounded-xl border border-white/10 py-2 text-sm font-bold hover:bg-white/5">Facebook</button>
            <button onClick={() => openNetwork('x')} className="rounded-xl border border-white/10 py-2 text-sm font-bold hover:bg-white/5">X</button>
            <button onClick={() => openNetwork('telegram')} className="rounded-xl border border-white/10 py-2 text-sm font-bold hover:bg-white/5">Telegram</button>
          </div>
          <button onClick={copyLink} className="mt-2 w-full rounded-xl border border-white/10 py-2 text-sm font-bold flex items-center justify-center gap-2 hover:bg-white/5">
            {copied ? <Check size={15} /> : <Copy size={15} />} {copied ? t('linkCopied') : t('copyLink')}
          </button>
          <p className="mt-2 text-xs text-white/40">{t('imageHint')}</p>
        </div>
      )}
    </div>
  )
}
