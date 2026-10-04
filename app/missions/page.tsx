export const dynamic = 'force-dynamic'
import Link from 'next/link'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import PageHero from '@/components/PageHero'
import { Target, CheckCircle2 } from 'lucide-react'
import { createClient } from '@/lib/supabase/server'
import { getTranslations } from 'next-intl/server'

type MissionTarget = { metric?: string; target?: number }

export default async function Missions() {
  const t = await getTranslations('Missions')
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data: missions } = await supabase
    .from('missions')
    .select('id,code,title,description,mission_type,target,xp_reward')
    .eq('is_active', true)
    .order('xp_reward', { ascending: true })

  const { data: userMissions } = user
    ? await supabase.from('user_missions').select('mission_id,progress,status,completed_at').eq('profile_id', user.id)
    : { data: [] }

  const progressMap = new Map((userMissions ?? []).map((um) => [um.mission_id, um]))

  const rows = (missions ?? []).map((m) => {
    const um = progressMap.get(m.id)
    const target = (m.target as MissionTarget | null)?.target ?? null
    const progress = um?.progress ?? 0
    const completed = um?.status === 'completed'
    const pct = target ? Math.min(100, Math.round((Number(progress) / target) * 100)) : 0
    return { ...m, progress, completed, target, pct }
  })

  if (!user) {
    return (
      <div className="min-h-screen arena-bg text-white ">
        <Sidebar />
        <main className="lg:pl-64 pb-20 lg:pb-0">
          <div className="max-w-5xl mx-auto px-4 md:px-8 py-8">
            <PageHero>
              <div className="flex items-center gap-2 text-xs tracking-[.3em] text-[#D4AF37] font-black"><Target size={15} /> DAILY + SEASONAL</div>
              <h1 className="text-4xl md:text-5xl font-display font-black tracking-wide mt-2">{t('title')}</h1>
              <p className="text-white/45 mt-2">{t('subtitle')}</p>
            </PageHero>
            <div className="card-fut-plain border border-white/10 bg-[#141416] p-8 text-center mt-7">
              <p className="text-white/45">{t('loginNotice')}</p>
              <Link href="/login" className="text-[#D4AF37] mt-3 inline-block font-bold">{t('loginLink')}</Link>
            </div>
          </div>
        </main>
        <BottomNav />
      </div>
    )
  }

  return (
    <div className="min-h-screen arena-bg text-white ">
      <Sidebar />
      <main className="lg:pl-64 pb-20 lg:pb-0">
        <div className="max-w-5xl mx-auto px-4 md:px-8 py-8">
          <PageHero>
            <div className="flex items-center gap-2 text-xs tracking-[.3em] text-[#D4AF37] font-black"><Target size={15} /> DAILY + SEASONAL</div>
            <h1 className="text-4xl md:text-5xl font-display font-black tracking-wide mt-2">{t('title')}</h1>
            <p className="text-white/45 mt-2">{t('subtitle')}</p>
          </PageHero>

          <div className="grid sm:grid-cols-2 gap-4 mt-7">
            {rows.map((m) => (
              <div key={m.id} className={`rounded-3xl border p-6 ${m.completed ? 'border-[#D4AF37]/40 bg-[#D4AF37]/5' : 'border-white/10 bg-[#161616]'}`}>
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <h2 className="font-black text-lg">{m.title}</h2>
                    <p className="text-sm text-white/45 mt-1">{m.description}</p>
                  </div>
                  {m.completed && <CheckCircle2 className="text-[#D4AF37] shrink-0" size={22} />}
                </div>
                <div className="mt-4">
                  <div className="h-2 rounded-full bg-white/10 overflow-hidden">
                    <div className="h-full bg-[#D4AF37] rounded-full transition-all" style={{ width: `${m.completed ? 100 : m.pct}%` }} />
                  </div>
                  <div className="flex items-center justify-between mt-2 text-xs text-white/40">
                    <span>{m.target ? `${Math.min(Number(m.progress), m.target)} / ${m.target}` : t('inProgress')}</span>
                    <span className="font-black text-[#D4AF37]">+{m.xp_reward} XP</span>
                  </div>
                </div>
              </div>
            ))}
            {rows.length === 0 && (
              <div className="sm:col-span-2 card-fut-plain border border-white/10 bg-[#141416] p-8 text-center text-white/45">{t('empty')}</div>
            )}
          </div>
        </div>
      </main>
      <BottomNav />
    </div>
  )
}
