import Sidebar from '@/components/Sidebar'
import BookingControlCenter from '@/components/BookingControlCenter'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'
export const dynamic='force-dynamic'
export default async function BookingsPage(){
 const supabase=await createClient(); const t=await getTranslations('Bookings'); const {data:userData}=await supabase.auth.getUser(); const user=userData.user
 const {data:bookables=[]}=await supabase.from('bookable_entities').select('id,title,activity_name,duration_minutes,price,currency_code,capacity,booking_mode,location_id').eq('status','active').order('title').limit(80)
 const {data:bookings=[]}=user?await supabase.from('bookings').select('id,bookable_id,starts_at,ends_at,status,payment_status,amount,currency_code,quantity').eq('booked_by',user.id).order('starts_at',{ascending:false}).limit(30):{data:[]}
 return <main className="min-h-screen bg-[#0A0A0C] text-white grid-bg"><Sidebar/><section className="lg:pl-64 p-6 lg:p-12 max-w-[1400px] mx-auto"><div className="mb-8"><PageHero><div className="text-[#D4AF37] text-xs font-black tracking-[.28em] uppercase">Dynasty Booking OS</div><h1 className="text-4xl md:text-6xl font-display font-black tracking-wide tracking-tight mt-2">{t('title')}</h1><p className="text-white/50 mt-3 max-w-3xl">{t('subtitle')}</p></PageHero></div><BookingControlCenter bookables={bookables ?? []} bookings={bookings ?? []}/></section></main>
}
