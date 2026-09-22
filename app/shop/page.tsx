import Link from 'next/link'
export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import { Crown, ShoppingBag } from 'lucide-react'
import { createClient } from '@/lib/supabase/server'
import ShopCatalogClient from '@/components/ShopCatalogClient'
export default async function ShopPage(){
 const supabase=await createClient()
 const {data:products=[]}=await supabase.from('shop_products').select('id,slug,title,description,product_type,status,base_price,currency_code,featured,metadata,shop_product_variants(id,product_id,sku,title,price,attributes,is_active)').eq('status','published').order('featured',{ascending:false}).order('created_at',{ascending:false}).limit(48)
 const normalized=(products||[]).map((p)=>({...p,variants:(p.shop_product_variants||[]).filter((v)=>v.is_active)}))
 return <main className="min-h-screen bg-[#0B0F19] text-white grid-bg"><Sidebar/><section className="lg:pl-64 p-6 lg:p-12 max-w-[1600px] mx-auto"><div className="rounded-[2rem] border border-[#FFD700]/20 bg-gradient-to-br from-[#1B1A12] via-[#141B2D] to-[#0B0F19] p-8 md:p-14 overflow-hidden relative"><Crown className="absolute right-8 top-8 text-[#FFD700]/20" size={140}/><div className="relative max-w-4xl"><div className="text-[#FFD700] text-xs font-black tracking-[.3em] uppercase">by Padelito · Official Store</div><h1 className="text-5xl md:text-7xl font-black mt-3">DYNASTY <span className="text-[#FFD700]">SHOP</span></h1><p className="text-white/60 text-lg mt-5">Tienda omnicanal: catálogo, variantes, carrito persistente, checkout y operación física.</p><div className="flex flex-wrap gap-3 mt-8"><Link href="/shop/cart" className="rounded-2xl bg-[#FFD700] text-black font-black px-6 py-3 inline-flex items-center gap-2"><ShoppingBag size={18}/> CARRITO</Link><Link href="/shop/orders" className="rounded-2xl border border-white/15 px-6 py-3 font-bold">MIS PEDIDOS</Link><Link href="/shop/pos" className="rounded-2xl border border-white/15 px-6 py-3 font-bold">POS FÍSICO</Link></div></div></div><div className="mt-10"><div className="text-[#00F0FF] text-xs font-black tracking-[.25em] uppercase">CATÁLOGO REAL</div><h2 className="text-3xl font-black mt-1">Colección Dynasty</h2><ShopCatalogClient products={normalized}/></div></section></main>
}
