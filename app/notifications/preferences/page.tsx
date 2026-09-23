export const dynamic = 'force-dynamic'
import Sidebar from '@/components/Sidebar'
import BottomNav from '@/components/BottomNav'
import { createClient } from '@/lib/supabase/server'
import PageHero from '@/components/PageHero'
import { getTranslations } from 'next-intl/server'

export default async function NotificationPreferences(){
 const supabase=await createClient(); const {data:{user}}=await supabase.auth.getUser()
 const t=await getTranslations('NotificationPreferences')
 const {data:prefs}=user?await supabase.from('notification_preferences').select('*').eq('profile_id',user.id).maybeSingle():{data:null}
 const categories=[t('categoryChallengeReceived'),t('categoryChallengeResponse'),t('categoryPartner'),t('categoryResult'),t('categoryTournament'),t('categoryMarketplace')]
 return <div className="min-h-screen bg-[#0A0A0C] text-white"><Sidebar/><main className="lg:pl-64 pb-20 lg:pb-0"><div className="max-w-3xl mx-auto px-4 md:px-6 py-8"><PageHero><div className="text-xs tracking-[.3em] text-[#D4AF37] font-black">NOTIFICATIONS</div><h1 className="text-4xl md:text-5xl font-display font-black tracking-wide mt-2">{t('title')}</h1><p className="text-white/50 mt-2">{t('subtitle')}</p></PageHero>{!user?<div className="mt-7 rounded-3xl border border-white/10 bg-[#161616] p-7 text-white/50">{t('loginRequired')}</div>:<div className="mt-7 rounded-3xl border border-white/10 bg-[#161616] p-6 space-y-5"><div><div className="font-black text-lg">{t('currentStatus')}</div><div className="text-sm text-white/45 mt-1">{prefs?t('prefsExist'):t('prefsDefault')}</div></div><div className="grid md:grid-cols-2 gap-3">{categories.map((label)=><div key={label} className="rounded-2xl bg-white/5 border border-white/10 px-4 py-4"><div className="font-bold">{label}</div><div className="text-xs text-white/35 mt-1">{t('managedNote')}</div></div>)}</div><p className="text-xs text-white/30">{t('advancedNote')}</p></div>}</div></main><BottomNav/></div>
}
