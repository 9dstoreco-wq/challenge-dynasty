'use client'

import Link from 'next/link'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'
import { useTranslations } from 'next-intl'

export default function ForgotPasswordPage() {
  const t = useTranslations('ForgotPassword')
  const [email, setEmail] = useState('')
  const [sent, setSent] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)
    const supabase = createClient()
    const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), {
      redirectTo: `${window.location.origin}/reset-password`,
    })
    // Siempre mostramos el mismo mensaje de exito: asi nadie puede averiguar que correos tienen cuenta.
    if (error) setError(toSafeMessage(error, 'auth.resetPassword'))
    else setSent(true)
    setLoading(false)
  }

  return (
    <main className="min-h-screen arena-bg text-white grid place-items-center p-6">
      <form onSubmit={submit} className="hud-corners shine reveal w-full max-w-md border border-[#D4AF37]/30 bg-gradient-to-br from-[#221F0F] via-[#141416] to-[#0A0A0C] p-8 relative overflow-hidden [clip-path:polygon(24px_0,100%_0,100%_calc(100%-24px),calc(100%-24px)_100%,0_100%,0_24px)] shadow-[0_0_80px_rgba(212,175,55,.12)]">
        <div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">CHALLENGE DYNASTY</div>
        <h1 className="text-4xl font-display font-black tracking-wide mt-2">{t('title')}</h1>
        <p className="text-white/50 text-sm mt-3">{t('subtitle')}</p>
        {sent ? (
          <p className="mt-6 border border-[#D4AF37]/30 bg-[#D4AF37]/5 p-4 text-sm text-white/80">{t('sent')}</p>
        ) : (
          <>
            <input
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              type="email"
              required
              placeholder={t('emailPlaceholder')}
              className="mt-6 w-full bg-white/5 border border-white/10 px-4 py-3 outline-none transition focus:border-[#D4AF37] focus:bg-[#D4AF37]/5"
            />
            {error && <p className="text-red-300 text-sm mt-3">{error}</p>}
            <button disabled={loading} className="btn-gold w-full mt-5 py-3 disabled:opacity-60">
              {loading ? t('sending') : t('submitBtn')}
            </button>
          </>
        )}
        <p className="text-sm text-white/45 mt-5">
          <Link href="/login" className="text-[#D4AF37] font-bold">{t('backToLogin')}</Link>
        </p>
      </form>
    </main>
  )
}
