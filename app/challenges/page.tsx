export const dynamic = 'force-dynamic'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { relatedRow } from '@/app/arena/related-row'
import { getTranslations, getLocale } from 'next-intl/server'

type Row = { id: string; title: string | null; status: string; scheduled_at: string | null; sport_id: string; creator_id: string }

// "Mis retos": todos los retos del usuario (por responder, en juego y cerrados).
export default async function MyChallengesPage() {
  const supabase = await createClient()
  const t = await getTranslations('MyChallenges')
  const locale = await getLocale()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    return (
      <div className="min-h-screen arena-bg overflow-x-clip text-white"><Sidebar /><main className="lg:pl-64 pb-24 lg:pb-0"><div className="mx-auto max-w-5xl px-4 py-8 md:px-6">
        <h1 className="font-display font-normal leading-[.84] tracking-tight text-[clamp(80px,13vw,180px)]"><span className="block">{t('heroLine1')}</span><span className="lando-outline block pl-[8%]">{t('heroLine2')}</span></h1>
        <div className="mt-8 border border-white/10 bg-[#161616] p-6 text-white/70">{t('loginRequired')} <Link href="/login" className="font-bold text-[#D4AF37]">{t('login')}</Link></div>
      </div></main><BottomNav /></div>
    )
  }

  const [{ data: parts }, { data: invites }] = await Promise.all([
    supabase.from('challenge_participants').select('status,challenge:challenges(id,title,status,scheduled_at,sport_id,creator_id)').eq('profile_id', user.id).in('status', ['accepted']).limit(100),
    supabase.from('challenge_invitations').select('id,challenge:challenges(id,title,status,scheduled_at,sport_id,creator_id)').eq('invitee_id', user.id).eq('status', 'pending').limit(50),
  ])

  const mine = new Map<string, Row>()
  for (const p of (parts ?? []) as unknown as { challenge: Row | Row[] | null }[]) { const c = relatedRow(p.challenge); if (c) mine.set(c.id, c) }
  const toAnswer: Row[] = []
  for (const i of (invites ?? []) as unknown as { challenge: Row | Row[] | null }[]) { const c = relatedRow(i.challenge); if (c && c.status === 'open' && !mine.has(c.id)) toAnswer.push(c) }

  const all = [...mine.values(), ...toAnswer]
  const ids = all.map((c) => c.id)
  const sportIds = [...new Set(all.map((c) => c.sport_id))]
  const [{ data: others }, { data: sports }] = await Promise.all([
    ids.length ? supabase.from('challenge_participants').select('challenge_id,profile_id,status,profile:profiles!challenge_participants_profile_id_fkey(display_name,username)').in('challenge_id', ids) : Promise.resolve({ data: [] }),
    sportIds.length ? supabase.from('sports').select('id,name,icon').in('id', sportIds) : Promise.resolve({ data: [] }),
  ])
  const sportMap = new Map((sports ?? []).map((s) => [s.id as string, `${s.icon ?? ''} ${s.name}`.trim()]))
  const rivalOf = (c: Row) => {
    const p = ((others ?? []) as unknown as { challenge_id: string; profile_id: string; status: string; profile: { display_name: string | null; username: string } | { display_name: string | null; username: string }[] | null }[])
      .find((x) => x.challenge_id === c.id && x.profile_id !== user.id && x.status !== 'declined')
    const pr = relatedRow(p?.profile)
    return pr?.display_name || pr?.username || t('rivalTBD')
  }

  const mineList = [...mine.values()].sort((a, b) => (b.scheduled_at ?? '').localeCompare(a.scheduled_at ?? ''))
  const playing = mineList.filter((c) => ['open', 'accepted', 'scheduled', 'active'].includes(c.status))
  const closed = mineList.filter((c) => !['open', 'accepted', 'scheduled', 'active'].includes(c.status))
  const fmt = (d: string | null) => d ? new Date(d).toLocaleString(locale === 'en' ? 'en-US' : 'es-CO', { dateStyle: 'medium', timeStyle: 'short' }) : t('dateTBD')
  const statusLabel = (s: string) => (['open', 'accepted', 'scheduled', 'active', 'completed', 'cancelled'].includes(s) ? t(`status.${s}`) : s)

  const renderCard = (c: Row, i: number, highlight?: boolean) => (
    <Link key={c.id} href={`/challenge/${c.id}`}
      className={`vs-card reveal group relative block overflow-hidden rounded-[22px] border p-5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#D4AF37] ${highlight ? 'border-[#D4AF37]/50 bg-[#D4AF37]/[.07]' : 'border-white/10 bg-[#121214]'}`}
      style={{ ['--i' as string]: Math.min(i, 10) }}>
      <span aria-hidden="true" className="vs-glow" />
      <div className="relative flex items-center justify-between gap-3 text-xs">
        <span className="inline-flex items-center gap-2 font-black uppercase tracking-[.18em] text-[#D4AF37]">
          {['active', 'accepted', 'scheduled', 'open'].includes(c.status) && <span className="live-dot" aria-hidden="true" />}
          {statusLabel(c.status)}
        </span>
        <span className="truncate font-bold uppercase tracking-widest text-white/60">{sportMap.get(c.sport_id) ?? ''}</span>
      </div>
      <div className="relative mt-4 flex items-baseline gap-3">
        <span className="vs-bolt font-display text-3xl leading-none">VS</span>
        <span className="truncate font-display text-3xl leading-none tracking-wide md:text-4xl">{rivalOf(c)}</span>
      </div>
      <div className="relative mt-4 flex items-center justify-between gap-3 border-t border-white/10 pt-3 text-sm">
        <span className="truncate text-white/65">{fmt(c.scheduled_at)}</span>
        <span className="vs-arrow shrink-0 font-black uppercase tracking-widest text-[#D4AF37]">→</span>
      </div>
    </Link>
  )

  const renderSection = (title: string, items: Row[], highlight?: boolean) => items.length === 0 ? null : (
    <section className="mt-12">
      <div className="mb-5 flex items-end justify-between gap-4">
        <h2 className="font-display text-4xl leading-none tracking-wide md:text-6xl">{title}</h2>
        <span className="font-display text-4xl leading-none tabular-nums text-white/25 md:text-6xl">{String(items.length).padStart(2, '0')}</span>
      </div>
      <div className="grid gap-4 md:grid-cols-2">{items.map((c, i) => renderCard(c, i, highlight))}</div>
    </section>
  )

  const stats: [string, number][] = [[t('toAnswer'), toAnswer.length], [t('playing'), playing.length], [t('closed'), closed.length]]

  return (
    <div className="min-h-screen arena-bg overflow-x-clip text-white"><Sidebar /><main className="lg:pl-64 pb-24 lg:pb-0"><div className="mx-auto max-w-5xl px-4 py-8 md:px-6">
      <section className="relative isolate">
        <div className="reveal text-xs font-black tracking-[.3em] text-[#D4AF37]">{t('kicker')}</div>
        <h1 className="mt-3 font-display font-normal leading-[.84] tracking-tight text-[clamp(80px,13vw,180px)]">
          <span className="reveal block" style={{ ['--i' as string]: 1 }}>{t('heroLine1')}</span>
          <span className="reveal lando-outline block pl-[8%]" style={{ ['--i' as string]: 2 }}>{t('heroLine2')}</span>
        </h1>
        <div className="reveal mt-5 flex flex-wrap items-center justify-between gap-5" style={{ ['--i' as string]: 3 }}>
          <p className="max-w-md text-base leading-relaxed text-white/70">{t('subtitle')}</p>
          <Link href="/challenge/new" className="btn-gold shine">{t('newBtn')}</Link>
        </div>
        <dl className="reveal mt-10 grid grid-cols-3 border-t border-white/10" style={{ ['--i' as string]: 4 }}>
          {stats.map(([label, n]) => (
            <div key={label} className="py-5 pr-3">
              <dt className="min-h-[2.6em] text-[11px] font-black uppercase leading-tight tracking-[.18em] text-white/50 md:min-h-0">{label}</dt>
              <dd className="mt-1 font-display text-5xl leading-none tabular-nums md:text-7xl">{n}</dd>
            </div>
          ))}
        </dl>
      </section>
      {renderSection(t('toAnswer'), toAnswer, true)}
      {renderSection(t('playing'), playing)}
      {renderSection(t('closed'), closed)}
      {all.length === 0 && (
        <div className="mt-10 grid gap-5 rounded-[28px] border border-dashed border-white/15 bg-white/[.02] p-8 text-center md:p-14">
          <div className="font-display text-5xl leading-none md:text-7xl">{t('emptyTitle')}</div>
          <p className="mx-auto max-w-md text-white/60">{t('empty')}</p>
          <div><Link href="/challenge/new" className="btn-gold shine">{t('newBtn')}</Link></div>
        </div>
      )}
    </div></main><BottomNav /></div>
  )
}
