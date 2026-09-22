export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import { createClient } from '@/lib/supabase/server'

type InventoryRow = { location_type: string; available_quantity: number | null; product_title: string | null; variant_title: string | null }
type SalesRow = { gross_sales: number | null }

export default async function ShopAdminPage(){
  const supabase = await createClient()
  const { data: snapshot } = await supabase.rpc('get_my_shop_admin_snapshot')
  const inventory: InventoryRow[] = Array.isArray(snapshot?.inventory) ? snapshot.inventory : []
  const sales: SalesRow[] = Array.isArray(snapshot?.sales) ? snapshot.sales : []
  const alerts: InventoryRow[] = Array.isArray(snapshot?.alerts) ? snapshot.alerts : []
  const online = inventory.filter((x)=>x.location_type==='online').reduce((a:number,x)=>a+Number(x.available_quantity||0),0)
  const physical = inventory.filter((x)=>x.location_type==='physical').reduce((a:number,x)=>a+Number(x.available_quantity||0),0)
  const revenue = sales.reduce((a:number,x)=>a+Number(x.gross_sales||0),0)
  return <main className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><section className="lg:pl-64 p-6 lg:p-12 max-w-[1500px] mx-auto">
    <div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">DYNASTY SHOP · ADMIN</div><h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">CONTROL COMERCIAL</h1>
    <div className="grid md:grid-cols-4 gap-4 mt-8">{[['ONLINE',online],['FÍSICO',physical],['VENTAS',revenue.toLocaleString('es-CO')],['ALERTAS',alerts.length]].map(([k,v])=><div key={k} className="rounded-3xl border border-white/10 bg-[#161616] p-6"><div className="text-xs text-white/40 tracking-widest">{k}</div><div className="text-3xl font-display font-black tracking-wide mt-2">{v}</div></div>)}</div>
    <div className="grid lg:grid-cols-2 gap-5 mt-6"><div className="rounded-3xl border border-white/10 bg-[#161616] p-6"><h2 className="font-black text-xl">Inventario</h2><p className="text-sm text-white/40 mt-1">Físico y online, por ubicación y variante.</p><div className="mt-5 space-y-2 max-h-96 overflow-auto">{inventory.slice(0,30).map((x,i:number)=><div key={i} className="flex justify-between rounded-xl bg-white/[.03] p-3"><span className="truncate pr-3">{x.product_title || x.variant_title || 'Producto'}</span><b>{x.available_quantity ?? 0}</b></div>)}</div></div>
    <div className="rounded-3xl border border-white/10 bg-[#161616] p-6"><h2 className="font-black text-xl">Alertas</h2><p className="text-sm text-white/40 mt-1">Reposición y stock bajo.</p><div className="mt-5 space-y-2">{alerts.slice(0,20).map((x,i:number)=><div key={i} className="rounded-xl bg-white/[.03] p-3 text-sm">{x.product_title || x.variant_title || 'Producto'} · <b>{x.available_quantity ?? 0}</b></div>)}{alerts.length===0&&<div className="text-white/40">Sin alertas activas.</div>}</div></div></div>
  </section></main>
}
