import Link from 'next/link'
import Sidebar from '@/components/Sidebar'
import { createClient } from '@/lib/supabase/server'

export const dynamic = 'force-dynamic'

type SellerOrder = { id: string; order_id: string | null; order_status: string | null; status: string | null; sku: string | null; quantity: number | null; line_total: number | null; total_amount: number | null; currency_code: string | null; seller_fee: number | null }

export default async function MarketplaceSellerPage() {
  const supabase = await createClient()
  const { data: userData } = await supabase.auth.getUser()
  const user = userData.user
  const { data: orders = [], error } = user
    ? await supabase.rpc('get_my_marketplace_seller_orders')
    : { data: [], error: null }

  return (
    <main className="min-h-screen bg-[#0A0A0C] text-white grid-bg">
      <Sidebar />
      <section className="lg:pl-64 p-6 lg:p-12 max-w-[1250px] mx-auto">
        <div className="flex flex-wrap items-end justify-between gap-5 mb-8">
          <div><div className="text-[#D4AF37] text-xs font-black tracking-[.28em] uppercase">Marketplace · Seller OS</div><h1 className="text-4xl md:text-5xl font-display font-black tracking-wide mt-2">Centro del vendedor</h1><p className="text-white/45 mt-2">Pedidos que involucran tus publicaciones y estado comercial.</p></div>
          <Link href="/marketplace" className="rounded-2xl border border-white/10 px-5 py-3 font-black">Volver al Marketplace</Link>
        </div>
        {!user ? <div className="rounded-3xl border border-white/10 bg-white/[.03] p-8">Inicia sesión para acceder al centro del vendedor.</div> : error ? <div className="rounded-3xl border border-red-400/20 bg-red-400/10 p-8">No se pudieron cargar tus pedidos como vendedor.</div> : !orders?.length ? <div className="rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-8">Todavía no tienes pedidos de tus publicaciones.</div> : <div className="space-y-4">{orders.map((o:SellerOrder)=><article key={o.id} className="rounded-3xl border border-white/10 bg-[#161616] p-6"><div className="flex flex-wrap items-start justify-between gap-4"><div><div className="text-xs text-[#D4AF37] uppercase tracking-widest font-black">{o.order_status || o.status || 'orden'}</div><h2 className="font-black text-xl mt-1">Orden {String(o.order_id || o.id).slice(0,8)}…</h2><div className="text-sm text-white/40 mt-2">SKU: {o.sku || '—'} · Cantidad: {o.quantity ?? '—'}</div></div><div className="text-right"><div className="font-black">{Number(o.line_total || o.total_amount || 0).toLocaleString('es-CO')} {o.currency_code || 'COP'}</div><div className="text-xs text-white/35 mt-1">Fee: {Number(o.seller_fee || 0).toLocaleString('es-CO')}</div></div></div></article>)}</div>}
      </section>
    </main>
  )
}
