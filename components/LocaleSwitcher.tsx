'use client'
import { useTransition } from 'react'
import { useTranslations, useLocale } from 'next-intl'
import { Globe } from 'lucide-react'

const LOCALES: { code: string; label: string }[] = [
  { code: 'es', label: 'ES' },
  { code: 'en', label: 'EN' },
]

export default function LocaleSwitcher() {
  const t = useTranslations('LocaleSwitcher')
  const locale = useLocale()
  const [pending, startTransition] = useTransition()

  function switchLocale(next: string) {
    if (next === locale) return
    startTransition(() => {
      document.cookie = `locale=${next}; path=/; max-age=31536000`
      window.location.reload()
    })
  }

  return (
    <div className="flex items-center gap-1.5 text-[11px] text-white/40">
      <Globe size={13} />
      <span className="sr-only">{t('label')}</span>
      {LOCALES.map((l) => (
        <button
          key={l.code}
          onClick={() => switchLocale(l.code)}
          disabled={pending}
          className={`px-1.5 py-0.5 rounded-md font-bold ${locale === l.code ? 'bg-white/10 text-white' : 'hover:text-white/70'}`}
        >
          {l.label}
        </button>
      ))}
    </div>
  )
}
