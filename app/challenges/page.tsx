export const dynamic = 'force-dynamic'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import PageHero from '@/components/PageHero'
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
    return <div className="min-h-screen arena-bg text-white"><Sidebar /><main className="lg:pl-64 pb-20 lg:pb-0 p-6 md:p-10"><div className="max-w-3xl rounded-2xl border border-white/10 bg-[#161616] p-6 text-white/55">{t('loginRequired')} <Link href="/login" className="text-[#D4AF37] font-bold">{t('login')}</Link></div></main><BottomNav /></div>
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

  const renderCard = (c: Row, highlight?: boolean) => (
    <Link key={c.id} href={`/challenge/${c.id}`}
    className={`block rounded-2xl border p-4 ${highlight ? 'border-[#D4AF37]/40 bg-[#D4AF37]/5' : 'border-white/10 bg-[#161616]'}`}>
      <div className="flex items-center justify-between gap-3">
        <div className="font-black truncate">{t('vs', { name: rivalOf(c) })}</div>
        <span className="text-[10px] font-black tracking-wider text-[#D4AF37] shrink-0">{statusLabel(c.status)}</span>
      </div>
      <div className="mt-1 text-sm text-white/50">{sportMap.get(c.sport_id) ?? ''} · {fmt(c.scheduled_at)}</div>
    </Link>
  )

  const renderSection = (title: string, items: Row[], highlight?: boolean) => items.length === 0 ? null : (
    <section className="mt-8"><h2 className="font-display text-2xl tracking-wide mb-3">{title}</h2><div className="space-y-3">{items.map((c) => renderCard(c, highlight))}</div></section>
  )

  return <div className="min-h-screen arena-bg text-white"><Sidebar /><main className="lg:pl-64 pb-24 lg:pb-0 p-6 md:p-10"><div className="max-w-3xl">
    <PageHero wide badge={false} className="p-6 md:p-8"><div className="flex items-center justify-between gap-4"><div><h1 className="text-3xl font-display font-black tracking-wide">{t('title')}</h1><p className="text-white/45 mt-2">{t('subtitle')}</p></div><Link href="/challenge/new" className="btn-gold px-4 py-2.5 text-sm shrink-0">{t('newBtn')}</Link></div></PageHero>
    {renderSection(t('toAnswer'), toAnswer, true)}
    {renderSection(t('playing'), playing)}
    {renderSection(t('closed'), closed)}
    {all.length === 0 && <div className="mt-8 rounded-2xl border border-white/10 bg-[#161616] p-6 text-white/45">{t('empty')}</div>}
  </div></main><BottomNav /></div>
}
