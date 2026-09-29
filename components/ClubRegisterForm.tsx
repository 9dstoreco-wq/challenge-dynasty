'use client'
import { useState, type FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslations } from 'next-intl'
import { createClient } from '@/lib/supabase/client'

export default function ClubRegisterForm() {
  const t = useTranslations('ClubRegister')
  const router = useRouter()
  const supabase = createClient()

  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [city, setCity] = useState('')
  const [countryCode, setCountryCode] = useState('CO')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!name.trim()) { setError(t('errNameRequired')); return }

    setBusy(true)
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { setBusy(false); setError(t('errAuthRequired')); return }

    const { data, error: insertError } = await supabase
      .from('organizations')
      .insert({
        owner_id: user.id,
        organization_type: 'club',
        name: name.trim(),
        description: description.trim() || null,
        city: city.trim() || null,
        country_code: countryCode.trim().toUpperCase() || null,
        status: 'active',
      })
      .select('id')
      .single()

    setBusy(false)
    if (insertError || !data) {
      setError(insertError?.message || t('errCreateFailed'))
      return
    }
    router.push(`/clubs/manage/${data.id}`)
  }

  return (
    <form onSubmit={handleSubmit} className="rounded-3xl border border-[#D4AF37]/20 bg-[#161616] p-6 md:p-8 space-y-5">
      <div>
        <label className="text-xs font-bold text-white/40">{t('nameLabel')}</label>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder={t('namePlaceholder')}
          className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-3 text-white placeholder:text-white/25 focus:border-[#D4AF37]/50 outline-none"
        />
      </div>
      <div>
        <label className="text-xs font-bold text-white/40">{t('descLabel')}</label>
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder={t('descPlaceholder')}
          rows={3}
          className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-3 text-white placeholder:text-white/25 focus:border-[#D4AF37]/50 outline-none resize-none"
        />
      </div>
      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="text-xs font-bold text-white/40">{t('cityLabel')}</label>
          <input
            value={city}
            onChange={(e) => setCity(e.target.value)}
            placeholder={t('cityPlaceholder')}
            className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-3 text-white placeholder:text-white/25 focus:border-[#D4AF37]/50 outline-none"
          />
        </div>
        <div>
          <label className="text-xs font-bold text-white/40">{t('countryLabel')}</label>
          <input
            value={countryCode}
            onChange={(e) => setCountryCode(e.target.value)}
            placeholder={t('countryPlaceholder')}
            maxLength={2}
            className="w-full mt-1 rounded-xl bg-white/5 border border-white/10 px-4 py-3 text-white placeholder:text-white/25 focus:border-[#D4AF37]/50 outline-none uppercase"
          />
        </div>
      </div>
      {error && <div className="text-sm text-red-400">{error}</div>}
      <button
        type="submit"
        disabled={busy}
        className="w-full rounded-xl bg-[#D4AF37] text-black font-black py-3.5 disabled:opacity-50"
      >
        {busy ? t('submitting') : t('submitBtn')}
      </button>
    </form>
  )
}
