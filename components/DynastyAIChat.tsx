'use client'
import { FormEvent, useState } from 'react'
import { useTranslations } from 'next-intl'

type Message = { role: 'user' | 'assistant'; content: string }
type DynastyAiMode = 'coach' | 'fitness' | 'club' | 'coach_business' | 'tournament' | 'commerce'

export default function DynastyAIChat({ mode, placeholder }: { mode: DynastyAiMode; placeholder?: string }) {
  const t = useTranslations('Intelligence')
  const ERROR_COPY: Record<string, string> = {
    AUTH_REQUIRED: t('errAuthRequired'),
    RATE_LIMITED: t('errRateLimited'),
    MESSAGE_REQUIRED: t('errMessageRequired'),
    MESSAGE_TOO_LONG: t('errMessageTooLong'),
    PAYLOAD_TOO_LARGE: t('errMessageTooLong'),
    INVALID_MODE: t('errInvalidMode'),
    AI_FUNCTION_ERROR: t('errAiFunctionError'),
  }
  function copyFor(code: string | undefined, fallback: string) {
    if (!code) return fallback
    return ERROR_COPY[code] ?? fallback
  }
  const [message, setMessage] = useState('')
  const [messages, setMessages] = useState<Message[]>([])
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [needsAuth, setNeedsAuth] = useState(false)

  async function send(e: FormEvent) {
    e.preventDefault()
    const text = message.trim()
    if (!text || busy) return
    setBusy(true)
    setError('')
    setMessages((m) => [...m, { role: 'user', content: text }])
    setMessage('')
    try {
      const res = await fetch('/api/dynasty-ai/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: text, mode }),
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) {
        if (res.status === 401) setNeedsAuth(true)
        const msg = copyFor(data?.error, t('chatConnectionError'))
        setError(msg)
        setMessages((m) => [...m, { role: 'assistant', content: msg }])
        return
      }
      if (data?.response) {
        setMessages((m) => [...m, { role: 'assistant', content: data.response }])
      } else {
        throw new Error('AI_PROVIDER_NOT_CONFIGURED')
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : t('chatConnectionError')
      setError(msg)
      setMessages((m) => [...m, { role: 'assistant', content: msg }])
    } finally {
      setBusy(false)
    }
  }

  if (needsAuth) {
    return (
      <div className="mt-8 rounded-3xl border border-white/10 bg-white/5 p-6">
        <div className="font-black">{t('chatTitle')}</div>
        <p className="mt-2 text-sm opacity-60">{t('chatLoginPrompt')}</p>
        <a href="/login" className="mt-4 inline-block rounded-full bg-[#D4AF37] text-black px-5 py-2.5 text-sm font-black">
          {t('chatLoginBtn')}
        </a>
      </div>
    )
  }

  return (
    <div className="mt-8 rounded-3xl border border-white/10 bg-white/5 p-4 md:p-6">
      {error && (
        <div className="mb-4 rounded-2xl border border-red-400/20 bg-red-400/5 p-4 text-sm text-red-200">{error}</div>
      )}
      <div className="space-y-3 max-h-[420px] overflow-y-auto">
        {messages.length === 0 && (
          <div className="rounded-2xl border border-white/10 bg-white/5 p-4 text-sm opacity-60">
            {t('chatEmptyState')}
          </div>
        )}
        {messages.map((m, i) => (
          <div
            key={`${m.role}-${i}`}
            className={`rounded-2xl border border-white/10 p-4 ${m.role === 'user' ? 'bg-white/10' : 'bg-white/5'}`}
          >
            <div className="text-xs font-black uppercase opacity-50">{m.role === 'user' ? t('chatYou') : t('chatAI')}</div>
            <div className="mt-1 whitespace-pre-wrap text-sm">{m.content}</div>
          </div>
        ))}
      </div>
      <form onSubmit={send} className="mt-4 space-y-3">
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder={placeholder ?? t('chatDefaultPlaceholder')}
          className="min-h-24 w-full rounded-3xl border border-white/10 bg-white/5 p-4 text-sm outline-none"
        />
        <button
          type="submit"
          disabled={busy || !message.trim()}
          className="rounded-full bg-[#D4AF37] text-black px-6 py-3 font-black disabled:opacity-40"
        >
          {busy ? t('chatThinking') : t('chatSend')}
        </button>
      </form>
    </div>
  )
}
