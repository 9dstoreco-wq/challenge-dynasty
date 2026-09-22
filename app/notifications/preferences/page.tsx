export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'

export default async function NotificationPreferences(){
 const supabase=await createClient(); const {data:{user}}=await supabase.auth.getUser()
 const {data:prefs}=user?await supabase.from('notification_preferences').select('*').eq('profile_id',user.id).maybeSingle():{data:null}
 return <div className="min-h-screen bg-[#0B0F19] text-white"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-3xl mx-auto px-4 md:px-6 py-8"><div className="text-xs tracking-[.3em] text-[#00F0FF] font-black">NOTIFICATIONS</div><h1 className="text-4xl md:text-5xl font-black mt-2">Preferencias</h1><p className="text-white/50 mt-2">Controla cómo Dynasty debe avisarte de tu actividad.</p>{!user?<div className="mt-7 rounded-3xl border border-white/10 bg-[#141B2D] p-7 text-white/50">Inicia sesión para configurar tus preferencias.</div>:<div className="mt-7 rounded-3xl border border-white/10 bg-[#141B2D] p-6 space-y-5"><div><div className="font-black text-lg">Estado actual</div><div className="text-sm text-white/45 mt-1">{prefs?'Ya existe una configuración guardada para tu cuenta.':'Todavía no tienes preferencias guardadas; se aplicarán los valores por defecto del sistema.'}</div></div><div className="grid md:grid-cols-2 gap-3">{['Reto recibido','Respuesta de reto','Partner','Resultado','Torneo','Marketplace'].map((label)=><div key={label} className="rounded-2xl bg-white/5 border border-white/10 px-4 py-4"><div className="font-bold">{label}</div><div className="text-xs text-white/35 mt-1">Gestionado por tu configuración de notificaciones.</div></div>)}</div><p className="text-xs text-white/30">La gestión avanzada por canal (in-app, email, push) queda preparada para la configuración específica del proveedor.</p></div>}</div></main><BottomNav/></div>
}
