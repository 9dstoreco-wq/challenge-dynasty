import { getTranslations } from 'next-intl/server'
import { createClient } from '@/lib/supabase/server'
import { ArrowDownLeft, CalendarCheck, Clock3, TrendingUp } from 'lucide-react'
import type { ReactNode } from 'react'

type PaymentRow = {
  id: string
  booking_id: string
  amount_due: number | string
  amount_paid: number | string
  currency_code: string
  payment_status: string
  paid_at: string | null
  created_at: string
}

// Ingresos del club. Lee booking_payment_records del propio club: la RLS ("bpr read") ya limita
// las filas a las organizaciones cuyo owner_id es el usuario, asi que un tercero nunca ve datos ajenos.
export default async function ClubIncomePanel({ organizationId }: { organizationId: string }) {
  const t = await getTranslations('ClubIncome')
  const supabase = await createClient()

  const { data, error } = await supabase
    .from('booking_payment_records')
    .select('id,booking_id,amount_due,amount_paid,currency_code,payment_status,paid_at,created_at')
    .eq('organization_id', organizationId)
    .order('created_at', { ascending: false })
    .limit(200)

  const rows: PaymentRow[] = error ? [] : ((data ?? []) as PaymentRow[])

  const monthStart = new Date()
  monthStart.setDate(1)
  monthStart.setHours(0, 0, 0, 0)

  const collected = rows.reduce((n, r) => n + Number(r.amount_paid || 0), 0)
  const pending = rows
    .filter((r) => r.payment_status !== 'refunded' && r.payment_status !== 'waived')
    .reduce((n, r) => n + Math.max(0, Number(r.amount_due || 0) - Number(r.amount_paid || 0)), 0)
  const thisMonth = rows
    .filter((r) => r.paid_at && new Date(r.paid_at) >= monthStart)
    .reduce((n, r) => n + Number(r.amount_paid || 0), 0)
  const paidBookings = rows.filter((r) => r.payment_status === 'paid').length
  const currency = rows[0]?.currency_code ?? 'COP'
  const fmt = (n: number) => `${n.toLocaleString('es-CO')} ${currency}`
  const recent = rows.filter((r) => Number(r.amount_paid || 0) > 0).slice(0, 8)

  const statusLabel = (s: string) => {
    const known = ['unpaid', 'deposit_paid', 'partially_paid', 'paid', 'refunded', 'waived']
    return known.includes(s) ? t(`status.${s}`) : s
  }

  return (
    <section className="rounded-2xl border border-white/10 bg-[#141416] p-6">
      <div className="text-xs tracking-[.3em] text-[#3B6EA5] font-black">{t('tag')}</div>
      <h2 className="text-2xl font-black mt-1">{t('title')}</h2>
      <p className="text-white/45 text-sm mt-1">{t('subtitle')}</p>

      <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4 mt-5">
        <Metric icon={<ArrowDownLeft size={20} />} label={t('collected')} value={fmt(collected)} />
        <Metric icon={<TrendingUp size={20} />} label={t('thisMonth')} value={fmt(thisMonth)} />
        <Metric icon={<Clock3 size={20} />} label={t('pending')} value={fmt(pending)} />
        <Metric icon={<CalendarCheck size={20} />} label={t('paidBookings')} value={String(paidBookings)} />
      </div>

      <h3 className="text-xs tracking-widest text-white/40 font-black uppercase mt-7">{t('recentTitle')}</h3>
      {recent.length === 0 ? (
        <div className="mt-3 rounded-2xl border border-dashed border-white/10 p-6 text-white/45 text-sm">{t('empty')}</div>
      ) : (
        <div className="mt-3 divide-y divide-white/5">
          {recent.map((r) => (
            <div key={r.id} className="py-3 flex items-center justify-between gap-3">
              <div>
                <div className="font-black">{statusLabel(r.payment_status)}</div>
                <div className="text-xs text-white/40 mt-0.5">
                  {r.paid_at ? new Date(r.paid_at).toLocaleString('es-CO') : new Date(r.created_at).toLocaleString('es-CO')}
                </div>
              </div>
              <div className="font-black text-right">{Number(r.amount_paid).toLocaleString('es-CO')} {r.currency_code}</div>
            </div>
          ))}
        </div>
      )}
    </section>
  )
}

function Metric({ icon, label, value }: { icon: ReactNode; label: string; value: string }) {
  return (
    <div className="rounded-2xl border border-white/10 bg-black/20 p-4">
      <div className="text-[#3B6EA5]">{icon}</div>
      <div className="text-[11px] text-white/40 uppercase tracking-widest mt-3">{label}</div>
      <div className="text-xl font-black mt-1">{value}</div>
    </div>
  )
}
