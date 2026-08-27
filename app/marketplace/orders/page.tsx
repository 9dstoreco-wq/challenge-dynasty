import Sidebar from '@/components/Sidebar'
import { createClient } from '@/lib/supabase/server'

export const dynamic = 'force-dynamic'

export default async function MarketplaceOrdersPage() {
  const supabase = createClient()
  const { data: userData } = await supabase.auth.getUser()
  const user = userData.user
  const { data: orders = [], error } = user
    ? await supabase.rpc('get_my_marketplace_orders')
    : { data: [], error: null }

  return (
    <main className="min-h-screen bg-[#0B0F19] text-white grid-bg">
      <Sidebar />
      <section className="lg:pl-64 p-6 lg:p-12 max-w-[1200px] mx-auto">
        <div className="mb-8"><div className="text-[#00F0FF] text-xs font-black tracking-[.28em] uppercase">Marketplace</div><h1 className="text-4xl md:text-5xl font-black mt-2">Mis órdenes</h1><p className="text-white/45 mt-2">Historial seguro de tus compras y reservas.</p></div>
        {!user ? <div className="rounded-3xl border border-white/10 bg-white/[.03] p-8">Inicia sesión para consultar tus órdenes.</div> : error ? <div className="rounded-3xl border border-red-400/20 bg-red-400/10 p-8">No se pudieron cargar las órdenes.</div> : !orders?.length ? <div className="rounded-3xl border border-dashed border-white/15 bg-white/[.02] p-8">Todavía no tienes órdenes.</div> : <div className="space-y-4">{orders.map((o:any)=><article key={o.id} className="rounded-3xl border border-white/10 bg-[#141B2D] p-6"><div className="flex flex-wrap justify-between gap-3"><div><div className="text-xs text-white/40 uppercase tracking-widest">{o.status}</div><a href={`/marketplace/orders/${o.id}`} className="font-black text-xl mt-1 inline-block hover:text-[#00F0FF]">Orden {String(o.id).slice(0,8)}…</a></div><div className="font-black">{Number(o.total_amount || 0).toLocaleString('es-CO')} {o.currency_code || 'COP'}</div></div><div className="text-sm text-white/40 mt-3">Creada: {o.created_at ? new Date(o.created_at).toLocaleString('es-CO') : '—'}</div></article>)}</div>}
      </section>
    </main>
  )
}
