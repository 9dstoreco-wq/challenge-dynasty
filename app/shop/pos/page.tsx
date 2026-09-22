export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import { createClient } from '@/lib/supabase/server'
import ShopPosTerminal from '@/components/ShopPosTerminal'

export default async function ShopPosPage(){
  const supabase=await createClient()
  const [{data:products=[]},{data:locations=[]},{data:registers=[]}]=await Promise.all([
    supabase.from('shop_products').select('id,title,base_price,featured,status').eq('status','published').limit(200),
    supabase.from('shop_locations').select('id,name,code').eq('location_type','physical').eq('status','active').order('name'),
    supabase.from('shop_pos_registers').select('id,name,code,location_id,status,opening_float').order('name'),
  ])
  const productIds=(products ?? []).map((p)=>p.id)
  const {data:variants=[]}=productIds.length?await supabase.from('shop_product_variants').select('id,product_id,sku,title,price,is_active').in('product_id',productIds).eq('is_active',true).limit(500):{data:[]}
  const grouped=(products ?? []).map((p)=>({...p,variants:(variants ?? []).filter((v)=>v.product_id===p.id)}))
  return <main className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><section className="lg:pl-64 p-6 lg:p-12 max-w-[1700px] mx-auto"><div className="mb-8"><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">DYNASTY SHOP · POS</div><h1 className="text-4xl md:text-6xl font-display font-black tracking-wide mt-2">CAJA FÍSICA</h1><p className="text-white/50 mt-3 max-w-3xl">Terminal operativa conectada al catálogo, clientes, cajas e inventario físico de Dynasty. Las ventas se registran como órdenes reales y descuentan inventario en una transacción.</p></div><ShopPosTerminal products={grouped} locations={locations ?? []} registers={registers ?? []}/></section></main>
}
