import Sidebar from '@/components/Sidebar'
import BookingControlCenter from '@/components/BookingControlCenter'
import { createClient } from '@/lib/supabase/server'
export const dynamic='force-dynamic'
export default async function BookingsPage(){
 const supabase=await createClient(); const {data:userData}=await supabase.auth.getUser(); const user=userData.user
 const {data:bookables=[]}=await supabase.from('bookable_entities').select('id,title,activity_name,duration_minutes,price,currency_code,capacity,booking_mode,location_id').eq('status','active').order('title').limit(80)
 const {data:bookings=[]}=user?await supabase.from('bookings').select('id,bookable_id,starts_at,ends_at,status,payment_status,amount,currency_code,quantity').eq('booked_by',user.id).order('starts_at',{ascending:false}).limit(30):{data:[]}
 return <main className="min-h-screen bg-[#0B0F19] text-white grid-bg"><Sidebar/><section className="lg:pl-64 p-6 lg:p-12 max-w-[1400px] mx-auto"><div className="mb-8"><div className="text-[#00F0FF] text-xs font-black tracking-[.28em] uppercase">Dynasty Booking OS</div><h1 className="text-4xl md:text-6xl font-black tracking-tight mt-2">Reservas avanzadas</h1><p className="text-white/50 mt-3 max-w-3xl">Reserva recursos, servicios y actividades con validación atómica, capacidad y control de conflictos.</p></div><BookingControlCenter bookables={bookables ?? []} bookings={bookings ?? []}/></section></main>
}
