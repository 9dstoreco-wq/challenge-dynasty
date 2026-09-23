import Link from 'next/link'
import Sidebar from '@/components/Sidebar'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import MarketplaceSellerPanel, { MarketplaceCreateSellerProfile, type MyListing } from '@/components/MarketplaceSellerPanel'
import { getTranslations } from 'next-intl/server'

export const dynamic = 'force-dynamic'

type SellerOrder = { id: string; order_id: string | null; order_status: string | null; status: string | null; sku: string | null; quantity: number | null; line_total: number | null; total_amount: number | null; currency_code: string | null; seller_fee: number | null }

export default async function MarketplaceSellerPage() {
  const supabase = await createClient()
  const t = await getTranslations('MarketplaceSeller')
  const { data: userData } = await supabase.auth.getUser()
  const user = userData.user
  const { data: orders = [], error } = user
    ? await supabase.rpc('get_my_marketplace_seller_orders')
    : { data: [], error: null }

  const { data: sellerProfile } = user
    ? await supabase.from('marketplace_seller_profiles').select('id,display_name,seller_type,country_code,city,status').eq('owner_id', user.id).maybeSingle()
    : { data: null }

  const { data: myListings = [] } = user && sellerProfile
    ? await supabase.from('marketplace_listings').select('id,title,listing_type,status,country_code,city,price,currency_code').eq('owner_id', user.id).order('created_at', { ascending: false })
    : { data: [] }

  return (
    <main className="min-h-screen bg-[#0A0A0C] text-white grid-bg">
      <Sidebar />
      <section className="lg:pl-64 p-6 lg:p-12 max-w-[1250px] mx-auto">
        <div className="flex flex-wrap items-end justify-between gap-5 mb-8">
          <div><PageHero><div className="text-[#D4AF37] text-xs font-black tracking-[.28em] uppercase">{t('kicker')}</div><h1 className="text-4xl md:text-5xl font-display font-black tracking-wide mt-2">{t('title')}</h1><p className="text-white/45 mt-2">{t('subtitle')}</p></PageHero></div>
          <Link href="/marketplace" className="rounded-2xl border border-white/10 px-5 py-3 font-black">{t('volver')}</Link>
        </div>
        {!user ? (
          <div className="rounded-3xl border border-white/10 bg-white/[.03] p-8">{t('loginRequired')}</div>
        ) : (
          <>
            {!sellerProfile ? (
              <MarketplaceCreateSellerProfile userId={user.id} />
            ) : (
              <MarketplaceSellerPanel sellerProfile={sellerProfile} myListings={(myListings ?? []) as MyListing[]} />
            )}

            <h2 className="font-black text-xl mt-10 mb-4">{t('pedidosRecibidos')}</h2>
            {error ? <div className="rounded-3xl border border-red-400/20 bg-red-400/10 p-8">{t('errorPedidos')}</div> : !orders?.length ? <div className="rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-8">{t('sinPedidos')}</div> : <div className="space-y-4">{orders.map((o:SellerOrder)=><article key={o.id} className="rounded-3xl border border-white/10 bg-[#161616] p-6"><div className="flex flex-wrap items-start justify-between gap-4"><div><div className="text-xs text-[#D4AF37] uppercase tracking-widest font-black">{o.order_status || o.status || t('orden')}</div><h2 className="font-black text-xl mt-1">{t('ordenLabel')} {String(o.order_id || o.id).slice(0,8)}…</h2><div className="text-sm text-white/40 mt-2">{t('sku')}: {o.sku || '—'} · {t('cantidad')}: {o.quantity ?? '—'}</div></div><div className="text-right"><div className="font-black">{Number(o.line_total || o.total_amount || 0).toLocaleString('es-CO')} {o.currency_code || 'COP'}</div><div className="text-xs text-white/35 mt-1">{t('fee')}: {Number(o.seller_fee || 0).toLocaleString('es-CO')}</div></div></div></article>)}</div>}
          </>
        )}
      </section>
    </main>
  )
}
