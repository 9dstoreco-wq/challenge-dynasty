import Link from 'next/link'
import Sidebar from '@/components/Sidebar'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'

export const dynamic = 'force-dynamic'

type Order = { id: string; status: string; total_amount: number | null; currency_code: string | null; created_at: string | null }

export default async function MarketplaceOrdersPage() {
  const supabase = await createClient()
  const t = await getTranslations('MarketplaceOrders')
  const { data: userData } = await supabase.auth.getUser()
  const user = userData.user
  const { data: orders = [], error } = user
    ? await supabase.rpc('get_my_marketplace_orders')
    : { data: [], error: null }

  return (
    <main className="min-h-screen bg-[#0A0A0C] text-white grid-bg">
      <Sidebar />
      <section className="lg:pl-64 p-6 lg:p-12 max-w-[1200px] mx-auto">
        <div className="mb-8"><PageHero><div className="text-[#D4AF37] text-xs font-black tracking-[.28em] uppercase">{t('tag')}</div><h1 className="text-4xl md:text-5xl font-display font-black tracking-wide mt-2">{t('myOrdersTitle')}</h1><p className="text-white/45 mt-2">{t('myOrdersSubtitle')}</p></PageHero></div>
        {!user ? <div className="rounded-3xl border border-white/10 bg-white/[.03] p-8">{t('loginPrompt')}</div> : error ? <div className="rounded-3xl border border-red-400/20 bg-red-400/10 p-8">{t('loadError')}</div> : !orders?.length ? <div className="rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-8">{t('empty')}</div> : <div className="space-y-4">{orders.map((o:Order)=><article key={o.id} className="rounded-3xl border border-white/10 bg-[#161616] p-6"><div className="flex flex-wrap justify-between gap-3"><div><div className="text-xs text-white/40 uppercase tracking-widest">{o.status}</div><Link href={`/marketplace/orders/${o.id}`} className="font-black text-xl mt-1 inline-block hover:text-[#D4AF37]">{t('orderLabel',{id:String(o.id).slice(0,8)})}</Link></div><div className="font-black">{Number(o.total_amount || 0).toLocaleString('es-CO')} {o.currency_code || 'COP'}</div></div><div className="text-sm text-white/40 mt-3">{t('createdLabel',{date:o.created_at ? new Date(o.created_at).toLocaleString('es-CO') : '—'})}</div></article>)}</div>}
      </section>
    </main>
  )
}
