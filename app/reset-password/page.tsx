'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { toSafeMessage } from '@/lib/safe-error'
import { useTranslations } from 'next-intl'

export default function ResetPasswordPage() {
  const t = useTranslations('ResetPassword')
  const [status, setStatus] = useState<'checking' | 'ready' | 'invalid' | 'done'>('checking')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    const supabase = createClient()
    let cancelled = false
    async function init() {
      const code = new URLSearchParams(window.location.search).get('code')
      let { data } = await supabase.auth.getSession()
      if (!data.session && code) {
        await supabase.auth.exchangeCodeForSession(code)
        ;({ data } = await supabase.auth.getSession())
      }
      if (!cancelled) setStatus(data.session ? 'ready' : 'invalid')
    }
    init()
    return () => {
      cancelled = true
    }
  }, [])

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    if (password.length < 8) { setError(t('tooShort')); return }
    if (password !== confirm) { setError(t('mismatch')); return }
    setLoading(true)
    const supabase = createClient()
    const { error } = await supabase.auth.updateUser({ password })
    if (error) setError(toSafeMessage(error, 'auth.updatePassword'))
    else setStatus('done')
    setLoading(false)
  }

  const inputCls = 'w-full bg-white/5 border border-white/10 px-4 py-3 outline-none transition focus:border-[#D4AF37] focus:bg-[#D4AF37]/5'

  return (
    <main className="min-h-screen arena-bg text-white grid place-items-center p-6">
      <form onSubmit={submit} className="hud-corners shine reveal w-full max-w-md border border-[#D4AF37]/30 bg-gradient-to-br from-[#221F0F] via-[#141416] to-[#0A0A0C] p-8 relative overflow-hidden [clip-path:polygon(24px_0,100%_0,100%_calc(100%-24px),calc(100%-24px)_100%,0_100%,0_24px)] shadow-[0_0_80px_rgba(212,175,55,.12)]">
        <div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">CHALLENGE DYNASTY</div>
        <h1 className="text-4xl font-display font-black tracking-wide mt-2">{t('title')}</h1>
        {status === 'checking' && <p className="mt-6 text-white/50 text-sm">{t('checking')}</p>}
        {status === 'invalid' && (
          <div className="mt-6">
            <p className="border border-red-300/30 bg-red-300/5 p-4 text-sm text-red-200">{t('invalid')}</p>
            <Link href="/forgot-password" className="inline-block mt-4 text-[#D4AF37] font-bold text-sm">{t('requestNew')}</Link>
          </div>
        )}
        {status === 'ready' && (
          <>
            <div className="space-y-3 mt-6">
              <input value={password} onChange={(e) => setPassword(e.target.value)} type="password" required minLength={8} placeholder={t('passwordPlaceholder')} className={inputCls} />
              <input value={confirm} onChange={(e) => setConfirm(e.target.value)} type="password" required minLength={8} placeholder={t('confirmPlaceholder')} className={inputCls} />
            </div>
            {error && <p className="text-red-300 text-sm mt-3">{error}</p>}
            <button disabled={loading} className="btn-gold w-full mt-5 py-3 disabled:opacity-60">{loading ? t('saving') : t('submitBtn')}</button>
          </>
        )}
        {status === 'done' && (
          <div className="mt-6">
            <p className="border border-[#D4AF37]/30 bg-[#D4AF37]/5 p-4 text-sm text-white/80">{t('done')}</p>
            <Link href="/onboarding" className="btn-gold inline-block mt-5 py-3 px-6 text-center">{t('continue')}</Link>
          </div>
        )}
      </form>
    </main>
  )
}
