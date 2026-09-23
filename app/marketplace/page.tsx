import Link from 'next/link'
import Sidebar from '@/components/Sidebar'
import MarketplaceClient from '@/components/MarketplaceClient'
import { Search, ShieldCheck, ShoppingBag, PackageCheck } from 'lucide-react'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'

export const dynamic = 'force-dynamic'

type Listing = {
  id: string
  title: string
  description: string | null
  city: string | null
  price: number | null
  currency_code: string | null
  listing_type: string
  is_featured: boolean | null
  published_at: string | null
  seller_id: string | null
  country_code: string | null
}

export default async function MarketplacePage() {
  const supabase = await createClient()
  const t = await getTranslations('Marketplace')
  const { data = [] } = await supabase
    .from('marketplace_listings')
    .select('id,title,description,city,price,currency_code,listing_type,is_featured,published_at,seller_id,country_code')
    .eq('status', 'published')
    .order('is_featured', { ascending: false })
    .order('published_at', { ascending: false })
    .limit(24)

  const listings = (data ?? []) as Listing[]

  return (
    <main className="min-h-screen bg-[#0A0A0C] text-white grid-bg">
      <Sidebar />
      <section className="lg:pl-64 p-6 lg:p-12 max-w-[1500px] mx-auto">
        <div className="flex flex-col lg:flex-row lg:items-end lg:justify-between gap-6 mb-10">
          <div>
            <PageHero><div className="text-[#D4AF37] text-xs font-black tracking-[.28em] uppercase">{t('kicker')}</div>
            <h1 className="text-4xl md:text-6xl font-display font-black tracking-wide tracking-tight mt-2">Marketplace</h1>
            <p className="text-white/50 mt-3 max-w-2xl">{t('subtitle')}</p></PageHero>
          </div>
          <div className="flex gap-3">
            <Link href="/marketplace/orders" className="rounded-2xl border border-white/10 bg-white/[.04] font-black px-5 py-3 inline-flex items-center justify-center gap-2">{t('misOrdenes')}</Link><Link href="/marketplace/seller" className="rounded-2xl border border-white/10 bg-white/[.04] font-black px-5 py-3 inline-flex items-center justify-center gap-2">{t('vender')}</Link>
            <Link href="/shop" className="rounded-2xl bg-[#D4AF37] text-black font-black px-6 py-3 inline-flex items-center justify-center gap-2"><ShoppingBag size={18}/> {t('irATienda')}</Link>
          </div>
        </div>

        <div className="rounded-2xl border border-white/10 bg-[#161616]/80 p-4 flex items-center gap-3 mb-8"><Search className="text-white/40" size={20}/><span className="text-white/40">{t('buscarPlaceholder')}</span></div>

        {listings.length === 0 ? (
          <div className="rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-10 text-center"><PackageCheck className="mx-auto text-[#D4AF37] mb-3"/><h2 className="font-black text-xl">{t('emptyTitle')}</h2><p className="text-white/45 mt-2 max-w-2xl mx-auto">{t('emptyBody')}</p></div>
        ) : (
          <MarketplaceClient listings={listings} />
        )}

        <div className="mt-8 rounded-3xl border border-white/10 bg-white/[.02] p-6 flex items-start gap-4"><ShieldCheck className="text-[#D4AF37] mt-1"/><div><h2 className="font-black">{t('protectedTitle')}</h2><p className="text-white/45 text-sm mt-1">{t('protectedBody')}</p></div></div>
      </section>
    </main>
  )
}
