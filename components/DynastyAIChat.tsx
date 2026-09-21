'use client'
import { FormEvent, useState } from 'react'

type Message = { role: 'user' | 'assistant'; content: string }
type DynastyAiMode = 'coach' | 'fitness' | 'club' | 'coach_business' | 'tournament' | 'commerce'

const ERROR_COPY: Record<string, string> = {
  AUTH_REQUIRED: 'Inicia sesión para hablar con Dynasty AI.',
  RATE_LIMITED: 'Demasiados mensajes seguidos. Espera un momento y vuelve a intentar.',
  MESSAGE_REQUIRED: 'Escribe un mensaje antes de enviar.',
  MESSAGE_TOO_LONG: 'Tu mensaje es demasiado largo.',
  PAYLOAD_TOO_LARGE: 'Tu mensaje es demasiado largo.',
  INVALID_MODE: 'Modo de IA inválido.',
  AI_FUNCTION_ERROR: 'Dynasty AI no pudo responder en este momento.',
}

function copyFor(code: string | undefined, fallback: string) {
  if (!code) return fallback
  return ERROR_COPY[code] ?? fallback
}

export default function DynastyAIChat({ mode, placeholder }: { mode: DynastyAiMode; placeholder?: string }) {
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
        const msg = copyFor(data?.error, 'Error de conexión con Dynasty AI.')
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
      const msg = err instanceof Error ? err.message : 'Error de conexión con Dynasty AI.'
      setError(msg)
      setMessages((m) => [...m, { role: 'assistant', content: msg }])
    } finally {
      setBusy(false)
    }
  }

  if (needsAuth) {
    return (
      <div className="mt-8 rounded-3xl border border-white/10 bg-white/5 p-6">
        <div className="font-black">Dynasty AI</div>
        <p className="mt-2 text-sm opacity-60">Inicia sesión para hablar con Dynasty AI.</p>
        <a href="/login" className="mt-4 inline-block rounded-full bg-[#00F0FF] text-black px-5 py-2.5 text-sm font-black">
          Iniciar sesión
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
            Empieza la conversación con Dynasty AI.
          </div>
        )}
        {messages.map((m, i) => (
          <div
            key={`${m.role}-${i}`}
            className={`rounded-2xl border border-white/10 p-4 ${m.role === 'user' ? 'bg-white/10' : 'bg-white/5'}`}
          >
            <div className="text-xs font-black uppercase opacity-50">{m.role === 'user' ? 'Tú' : 'Dynasty AI'}</div>
            <div className="mt-1 whitespace-pre-wrap text-sm">{m.content}</div>
          </div>
        ))}
      </div>
      <form onSubmit={send} className="mt-4 space-y-3">
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder={placeholder ?? '¿En qué te ayudo hoy?'}
          className="min-h-24 w-full rounded-3xl border border-white/10 bg-white/5 p-4 text-sm outline-none"
        />
        <button
          type="submit"
          disabled={busy || !message.trim()}
          className="rounded-full bg-[#00F0FF] text-black px-6 py-3 font-black disabled:opacity-40"
        >
          {busy ? 'Pensando...' : 'Enviar a Dynasty AI'}
        </button>
      </form>
    </div>
  )
}
