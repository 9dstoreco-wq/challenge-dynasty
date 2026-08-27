export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'

export default async function Business(){
  const supabase = createClient()
  const { data: plans = [] } = await supabase
    .from('billing_plans')
    .select('id,code,name,audience_type,description,billing_interval,price,currency_code,is_active')
    .eq('is_active', true)
    .order('price', { ascending: true })

  return <div className="min-h-screen bg-[#0B0F19] text-white grid-bg"><Sidebar/><main className="lg:pl-64 pb-20"><div className="max-w-6xl mx-auto px-4 md:px-6 py-8">
    <div className="text-xs tracking-[.3em] text-[#00F0FF] font-black">DYNASTY BUSINESS ENGINE</div>
    <h1 className="text-4xl md:text-6xl font-black mt-2">Herramientas que generan valor.</h1>
    <p className="text-white/55 mt-3 max-w-3xl">DYNASTY cobra por sus planes, software, visibilidad y productos propios. Las reservas, inscripciones y servicios siguen siendo ingresos del club, organizador o coach.</p>

    <div className="mt-8 rounded-3xl border border-white/10 bg-[#141B2D] p-6">
      <div className="flex items-center justify-between gap-4"><div><div className="text-xs text-[#00F0FF] font-black tracking-widest">PLANES EN SUPABASE</div><h2 className="text-2xl font-black mt-1">Catálogo comercial real</h2></div><span className="rounded-full border border-white/10 px-3 py-1 text-xs font-black">{plans.length} activos</span></div>
      {plans.length === 0 ? <div className="mt-5 rounded-2xl border border-dashed border-white/15 p-6 text-white/50">El catálogo todavía está vacío. La infraestructura de billing ya existe; falta definir y cargar los planes definitivos.</div> : <div className="grid md:grid-cols-2 xl:grid-cols-3 gap-4 mt-5">{plans.map((p:any)=><div key={p.id} className="rounded-2xl border border-white/10 bg-black/10 p-5"><div className="text-xs text-[#FFD700] font-black uppercase tracking-widest">{p.audience_type}</div><h3 className="text-xl font-black mt-2">{p.name}</h3><p className="text-white/45 text-sm mt-2 min-h-10">{p.description || 'Plan DYNASTY'}</p><div className="mt-4 text-2xl font-black">{Number(p.price).toLocaleString('es-CO')} {p.currency_code}</div><div className="text-xs text-white/40 mt-1">{p.billing_interval}</div></div>)}</div>}
    </div>

    <section className="mt-8 rounded-3xl border border-[#00F0FF]/20 bg-[#00F0FF]/5 p-6"><h2 className="text-2xl font-black">Ciclo de acceso protegido</h2><div className="flex flex-wrap gap-2 mt-4 text-sm font-black">{['ACTIVO','VENCIDO','GRACIA','RESTRINGIDO','SUSPENDIDO'].map(x=><span key={x} className="rounded-full border border-white/10 bg-black/20 px-4 py-2">{x}</span>)}</div><p className="text-white/50 text-sm mt-4">La plataforma debe restringir herramientas por entitlements sin borrar la actividad histórica del club, coach u organizador.</p></section>
  </div></main><BottomNav/></div>
}
