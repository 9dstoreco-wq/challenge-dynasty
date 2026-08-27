import Sidebar from '@/components/Sidebar'
import MarketplaceClient from '@/components/MarketplaceClient'
import { Search, ShieldCheck, ShoppingBag, PackageCheck } from 'lucide-react'
import { createClient } from '@/lib/supabase/server'

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
}

export default async function MarketplacePage() {
  const supabase = createClient()
  const { data = [] } = await supabase
    .from('marketplace_listings')
    .select('id,title,description,city,price,currency_code,listing_type,is_featured,published_at,seller_id')
    .eq('status', 'published')
    .order('is_featured', { ascending: false })
    .order('published_at', { ascending: false })
    .limit(24)

  const listings = data as Listing[]

  return (
    <main className="min-h-screen bg-[#0B0F19] text-white grid-bg">
      <Sidebar />
      <section className="lg:pl-64 p-6 lg:p-12 max-w-[1500px] mx-auto">
        <div className="flex flex-col lg:flex-row lg:items-end lg:justify-between gap-6 mb-10">
          <div>
            <div className="text-[#00F0FF] text-xs font-black tracking-[.28em] uppercase">Comunidad · Compra · Venta</div>
            <h1 className="text-4xl md:text-6xl font-black tracking-tight mt-2">Marketplace</h1>
            <p className="text-white/50 mt-3 max-w-2xl">El mercado deportivo de CHALLENGE DYNASTY. Descubre productos, publica lo que ya no usas y conecta con compradores de la comunidad.</p>
          </div>
          <div className="flex gap-3">
            <a href="/marketplace/orders" className="rounded-2xl border border-white/10 bg-white/[.04] font-black px-5 py-3 inline-flex items-center justify-center gap-2">Mis órdenes</a><a href="/marketplace/seller" className="rounded-2xl border border-white/10 bg-white/[.04] font-black px-5 py-3 inline-flex items-center justify-center gap-2">Vender</a>
            <a href="/shop" className="rounded-2xl bg-[#00F0FF] text-black font-black px-6 py-3 inline-flex items-center justify-center gap-2"><ShoppingBag size={18}/> IR A DYNASTY SHOP</a>
          </div>
        </div>

        <div className="rounded-2xl border border-white/10 bg-[#141B2D]/80 p-4 flex items-center gap-3 mb-8"><Search className="text-white/40" size={20}/><span className="text-white/40">Buscar productos, palas, ropa, accesorios...</span></div>

        {listings.length === 0 ? (
          <div className="rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-10 text-center"><PackageCheck className="mx-auto text-[#00F0FF] mb-3"/><h2 className="font-black text-xl">Todavía no hay publicaciones activas</h2><p className="text-white/45 mt-2 max-w-2xl mx-auto">La estructura de sellers, listings, inventario, órdenes y pagos ya existe. Cuando haya publicaciones reales, aquí podrán reservarse sin abrir directamente las tablas financieras al cliente.</p></div>
        ) : (
          <MarketplaceClient listings={listings} />
        )}

        <div className="mt-8 rounded-3xl border border-white/10 bg-white/[.02] p-6 flex items-start gap-4"><ShieldCheck className="text-[#00F0FF] mt-1"/><div><h2 className="font-black">Marketplace protegido</h2><p className="text-white/45 text-sm mt-1">Las órdenes, pagos, devoluciones y settlements se procesan mediante RPCs controlados; los datos financieros no se exponen directamente al cliente.</p></div></div>
      </section>
    </main>
  )
}
