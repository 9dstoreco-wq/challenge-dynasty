'use client'
import { useState, type FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

type Profile = {
  id: string
  headline: string | null
  bio: string | null
  is_independent: boolean
  accepts_online: boolean
  accepts_in_person: boolean
  default_currency: string
  status: string
} | null

type ServiceRow = {
  id: string
  title: string
  description: string | null
  service_mode: string
  price: number
  currency_code: string
  duration_minutes: number | null
  status: string
  bookable_id: string | null
}

type BookingRow = {
  id: string
  starts_at: string
  ends_at: string
  status: string
  payment_status: string
  amount: number
  currency_code: string
  bookable_title: string | null
}

const MODE_LABELS: Record<string, string> = { in_person: 'Presencial', online: 'Online', hybrid: 'Híbrido' }
const STATUS_LABELS: Record<string, string> = { draft: 'Borrador', active: 'Activo', paused: 'Pausado', archived: 'Archivado' }

function friendlyError(message: string): string {
  const map: Record<string, string> = {
    AUTH_REQUIRED: 'Necesitas iniciar sesión.',
    'Booking not found': 'Esa reserva no existe.',
    'Booking is not a provider service': 'Esa reserva no corresponde a un servicio de coach.',
    'Not authorized to complete this booking': 'No tienes permiso para completar esta reserva.',
    'Only confirmed bookings can be completed': 'Solo puedes completar reservas confirmadas.',
  }
  return map[message] || 'Algo salió mal. Intenta de nuevo.'
}

export default function CoachDashboard({ profile, services, bookings, myProfileId }: { profile: Profile; services: ServiceRow[]; bookings: BookingRow[]; myProfileId: string }) {
  const supabase = createClient()
  const router = useRouter()
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [headline, setHeadline] = useState(profile?.headline || '')
  const [bio, setBio] = useState(profile?.bio || '')
  const [acceptsOnline, setAcceptsOnline] = useState(profile?.accepts_online ?? true)
  const [acceptsInPerson, setAcceptsInPerson] = useState(profile?.accepts_in_person ?? true)
  const [currency, setCurrency] = useState(profile?.default_currency || 'COP')

  const [svcTitle, setSvcTitle] = useState('')
  const [svcDesc, setSvcDesc] = useState('')
  const [svcMode, setSvcMode] = useState('in_person')
  const [svcPrice, setSvcPrice] = useState('')
  const [svcDuration, setSvcDuration] = useState('60')

  async function saveProfile(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setError(null)
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { setError('Necesitas iniciar sesión.'); setBusy(false); return }
    const payload = {
      profile_id: user.id,
      headline: headline.trim() || null,
      bio: bio.trim() || null,
      provider_type: 'coach',
      is_independent: true,
      accepts_online: acceptsOnline,
      accepts_in_person: acceptsInPerson,
      default_currency: currency,
      status: 'active',
    }
    const { error: upsertError } = profile
      ? await supabase.from('provider_profiles').update(payload).eq('id', profile.id)
      : await supabase.from('provider_profiles').insert(payload)
    setBusy(false)
    if (upsertError) { setError(upsertError.message); return }
    router.refresh()
  }

  async function addService(e: FormEvent) {
    e.preventDefault()
    if (!profile) return
    if (!svcTitle.trim() || !svcPrice.trim()) return
    setBusy(true); setError(null)
    const price = Number(svcPrice)
    const duration = svcDuration.trim() ? Number(svcDuration) : null
    const { data: newService, error: svcError } = await supabase.from('provider_services').insert({
      provider_id: profile.id,
      title: svcTitle.trim(),
      description: svcDesc.trim() || null,
      service_mode: svcMode,
      ownership_type: 'provider',
      operational_owner_type: 'provider',
      payment_owner_type: 'provider',
      duration_minutes: duration,
      capacity: 1,
      price,
      currency_code: currency,
      status: 'active',
    }).select('id').single()

    if (svcError || !newService) { setBusy(false); setError(svcError?.message || 'No se pudo crear el servicio.'); return }

    const { error: bookableError } = await supabase.from('bookable_entities').insert({
      owner_id: myProfileId,
      entity_type: 'service',
      entity_id: newService.id,
      title: svcTitle.trim(),
      duration_minutes: duration,
      capacity: 1,
      price,
      currency_code: currency,
      booking_mode: 'instant',
      status: 'active',
    })

    if (bookableError) {
      await supabase.from('provider_services').delete().eq('id', newService.id)
      setBusy(false)
      setError('No se pudo publicar el servicio para reservas: ' + bookableError.message)
      return
    }

    setBusy(false)
    setSvcTitle(''); setSvcDesc(''); setSvcPrice(''); setSvcDuration('60')
    router.refresh()
  }

  async function toggleService(svc: ServiceRow) {
    setBusy(true); setError(null)
    const nextStatus = svc.status === 'active' ? 'paused' : 'active'
    const { error: svcError } = await supabase.from('provider_services').update({ status: nextStatus }).eq('id', svc.id)
    if (!svcError && svc.bookable_id) {
      await supabase.from('bookable_entities').update({ status: nextStatus === 'active' ? 'active' : 'paused' }).eq('id', svc.bookable_id)
    }
    setBusy(false)
    if (svcError) { setError(svcError.message); return }
    router.refresh()
  }

  async function completeBooking(bookingId: string) {
    setBusy(true); setError(null)
    const { error: rpcError } = await supabase.rpc('complete_provider_booking', { p_booking_id: bookingId })
    setBusy(false)
    if (rpcError) { setError(friendlyError(rpcError.message)); return }
    router.refresh()
  }

  const paidTotal = bookings.filter((b) => b.payment_status === 'paid').reduce((a, b) => a + Number(b.amount || 0), 0)
  const upcomingCount = bookings.filter((b) => b.status === 'confirmed' && new Date(b.starts_at) > new Date()).length
  const completedCount = bookings.filter((b) => b.status === 'completed').length

  return (
    <div className="space-y-6">
      {error && <div className="rounded-2xl border border-red-400/30 bg-red-400/10 p-4 text-sm text-red-300">{error}</div>}

      <div className="rounded-3xl border border-white/10 bg-[#161616] p-6">
        <h2 className="font-black text-xl">{profile ? 'Mi perfil de coach' : 'Activar mi perfil de coach'}</h2>
        <p className="text-sm text-white/40 mt-1">{profile ? 'Así te ven los clientes en /coaches.' : 'Publica tu perfil para empezar a ofrecer servicios y recibir reservas.'}</p>
        <form onSubmit={saveProfile} className="grid md:grid-cols-2 gap-3 mt-5">
          <input value={headline} onChange={(e) => setHeadline(e.target.value)} placeholder="Titular (ej: Coach de pádel nivel 3)" className="rounded-xl bg-white/[.05] border border-white/10 px-3 py-2 text-sm md:col-span-2" />
          <textarea value={bio} onChange={(e) => setBio(e.target.value)} placeholder="Bio" rows={3} className="rounded-xl bg-white/[.05] border border-white/10 px-3 py-2 text-sm md:col-span-2" />
          <label className="flex items-center gap-2 text-sm text-white/70"><input type="checkbox" checked={acceptsOnline} onChange={(e) => setAcceptsOnline(e.target.checked)} /> Acepta clases online</label>
          <label className="flex items-center gap-2 text-sm text-white/70"><input type="checkbox" checked={acceptsInPerson} onChange={(e) => setAcceptsInPerson(e.target.checked)} /> Acepta clases presenciales</label>
          <select value={currency} onChange={(e) => setCurrency(e.target.value)} className="rounded-xl bg-white/[.05] border border-white/10 px-3 py-2 text-sm">
            <option value="COP">COP</option>
            <option value="USD">USD</option>
          </select>
          <button type="submit" disabled={busy} className="rounded-full bg-[#D4AF37] text-black text-xs font-bold px-5 py-2 disabled:opacity-50 md:col-span-2 justify-self-start">{profile ? 'Guardar cambios' : 'Activar perfil'}</button>
        </form>
      </div>

      {profile && (
        <>
          <div className="grid md:grid-cols-3 gap-4">
            <div className="rounded-3xl border border-white/10 bg-[#161616] p-6"><div className="text-xs text-white/40 tracking-widest">INGRESOS COBRADOS</div><div className="text-2xl font-display font-black tracking-wide mt-2">{paidTotal.toLocaleString('es-CO')} {currency}</div></div>
            <div className="rounded-3xl border border-white/10 bg-[#161616] p-6"><div className="text-xs text-white/40 tracking-widest">PRÓXIMAS SESIONES</div><div className="text-2xl font-display font-black tracking-wide mt-2">{upcomingCount}</div></div>
            <div className="rounded-3xl border border-white/10 bg-[#161616] p-6"><div className="text-xs text-white/40 tracking-widest">SESIONES COMPLETADAS</div><div className="text-2xl font-display font-black tracking-wide mt-2">{completedCount}</div></div>
          </div>

          <div className="rounded-3xl border border-white/10 bg-[#161616] p-6">
            <h2 className="font-black text-xl">Mis servicios</h2>
            <p className="text-sm text-white/40 mt-1">Lo que ofreces y lo que se puede reservar en tu perfil.</p>
            <form onSubmit={addService} className="grid md:grid-cols-5 gap-2 mt-5">
              <input value={svcTitle} onChange={(e) => setSvcTitle(e.target.value)} placeholder="Título" className="rounded-xl bg-white/[.05] border border-white/10 px-3 py-2 text-sm md:col-span-2" />
              <input value={svcPrice} onChange={(e) => setSvcPrice(e.target.value)} type="number" min="0" placeholder={`Precio (${currency})`} className="rounded-xl bg-white/[.05] border border-white/10 px-3 py-2 text-sm" />
              <input value={svcDuration} onChange={(e) => setSvcDuration(e.target.value)} type="number" min="1" placeholder="Minutos" className="rounded-xl bg-white/[.05] border border-white/10 px-3 py-2 text-sm" />
              <select value={svcMode} onChange={(e) => setSvcMode(e.target.value)} className="rounded-xl bg-white/[.05] border border-white/10 px-3 py-2 text-sm">
                <option value="in_person">Presencial</option>
                <option value="online">Online</option>
                <option value="hybrid">Híbrido</option>
              </select>
              <textarea value={svcDesc} onChange={(e) => setSvcDesc(e.target.value)} placeholder="Descripción (opcional)" rows={2} className="rounded-xl bg-white/[.05] border border-white/10 px-3 py-2 text-sm md:col-span-4" />
              <button type="submit" disabled={busy} className="rounded-full bg-[#D4AF37] text-black text-xs font-bold px-5 py-2 disabled:opacity-50">Agregar</button>
            </form>
            <div className="mt-5 space-y-2">
              {services.length === 0 && <div className="text-white/40 text-sm">Todavía no tienes servicios publicados.</div>}
              {services.map((s) => (
                <div key={s.id} className="flex items-center justify-between rounded-xl bg-white/[.03] p-3 text-sm gap-2">
                  <div className="truncate">
                    <div className="font-bold truncate">{s.title}</div>
                    <div className="text-white/40 text-xs">{MODE_LABELS[s.service_mode] || s.service_mode} · {Number(s.price).toLocaleString('es-CO')} {s.currency_code} · {STATUS_LABELS[s.status] || s.status}</div>
                  </div>
                  <button onClick={() => toggleService(s)} disabled={busy} className="text-xs text-white/50 hover:text-white shrink-0">{s.status === 'active' ? 'Pausar' : 'Activar'}</button>
                </div>
              ))}
            </div>
          </div>

          <div className="rounded-3xl border border-white/10 bg-[#161616] p-6">
            <h2 className="font-black text-xl">Reservas</h2>
            <p className="text-sm text-white/40 mt-1">Últimas reservas de tus servicios.</p>
            <div className="mt-5 space-y-2 max-h-96 overflow-auto">
              {bookings.length === 0 && <div className="text-white/40 text-sm">Todavía no tienes reservas.</div>}
              {bookings.slice(0, 30).map((b) => (
                <div key={b.id} className="flex items-center justify-between rounded-xl bg-white/[.03] p-3 text-sm gap-2">
                  <div className="truncate">
                    <div className="font-bold truncate">{b.bookable_title || 'Servicio'}</div>
                    <div className="text-white/40 text-xs">{new Date(b.starts_at).toLocaleString('es-CO')} · {b.status} · {b.payment_status} · {Number(b.amount).toLocaleString('es-CO')} {b.currency_code}</div>
                  </div>
                  {b.status === 'confirmed' && (
                    <button onClick={() => completeBooking(b.id)} disabled={busy} className="text-xs text-[#D4AF37] hover:text-white shrink-0">Marcar completada</button>
                  )}
                </div>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  )
}
