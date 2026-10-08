export const dynamic = 'force-dynamic'
import Link from 'next/link'
import { redirect } from 'next/navigation'
import BusinessShell from '@/components/business/BusinessShell'
import BusinessHeader from '@/components/business/BusinessHeader'
import { createClient } from '@/lib/supabase/server'
import { Building2, Plus } from 'lucide-react'

// Entrada de la cara de "negocio". Hoy vive en /negocio dentro del mismo dominio; cuando exista
// un subdominio propio (ej: clubes.tudominio.com), el middleware puede reescribir "/" en ese host
// hacia esta misma pagina sin tocar nada mas.
export default async function NegocioPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    return (
      <BusinessShell>
        <div className="max-w-md mx-auto py-10 text-center">
          <h1 className="text-2xl font-semibold tracking-tight">Panel de negocio</h1>
          <p className="text-white/50 mt-2 text-sm">Inicia sesión con tu cuenta para administrar tu club.</p>
          <Link href="/login?next=/negocio" className="inline-block mt-6 rounded-lg bg-[#3B6EA5] px-5 py-2.5 text-sm font-semibold">Iniciar sesión</Link>
        </div>
      </BusinessShell>
    )
  }

  const { data: orgs } = await supabase
    .from('organizations')
    .select('id,name,city,country_code')
    .eq('owner_id', user.id)
    .order('created_at', { ascending: true })

  const organizations = orgs ?? []

  if (organizations.length === 1) {
    redirect(`/clubs/manage/${organizations[0].id}`)
  }

  return (
    <BusinessShell>
      <BusinessHeader
        eyebrow="Negocio"
        title="Tus clubes"
        subtitle="Administra reservas e ingresos del club o la cancha que registraste en Challenge Dynasty."
      />
      {organizations.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-white/15 p-8 text-center">
          <Building2 className="mx-auto text-white/30" size={28} />
          <p className="text-white/55 mt-3 text-sm max-w-sm mx-auto">
            Todavía no tienes un club registrado. Regístralo para empezar a recibir reservas y ver tus ingresos aquí.
          </p>
          <Link href="/clubs/new" className="inline-flex items-center gap-2 mt-5 rounded-lg bg-[#3B6EA5] px-5 py-2.5 text-sm font-semibold">
            <Plus size={16} /> Registrar mi club
          </Link>
        </div>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2">
          {organizations.map((org) => (
            <Link key={org.id} href={`/clubs/manage/${org.id}`} className="rounded-2xl border border-white/10 bg-white/5 p-5 hover:bg-white/[.07] transition">
              <div className="flex items-center gap-2 text-[#6FA3D8]"><Building2 size={18} /></div>
              <div className="font-semibold mt-2">{org.name}</div>
              <div className="text-xs text-white/40 mt-1">{[org.city, org.country_code].filter(Boolean).join(' · ') || 'Sin ubicación'}</div>
            </Link>
          ))}
        </div>
      )}
    </BusinessShell>
  )
}
