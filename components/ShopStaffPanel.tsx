'use client'
import { useEffect, useState, type FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { useTranslations } from 'next-intl'

type StaffRow = { profile_id: string; role: string; status: string; display_name: string | null; username: string | null; created_at: string }
type ClaimableLocation = { id: string; name: string; location_type: string }

export function ShopClaimOwnership({ locations }: { locations: ClaimableLocation[] }) {
  const t = useTranslations('ShopAdmin')
  const supabase = createClient()
  const router = useRouter()
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const ERROR_LABELS: Record<string, string> = {
    AUTH_REQUIRED: t('errAuthRequired'),
    SHOP_PERMISSION_DENIED: t('errPermissionDenied'),
    PROFILE_NOT_FOUND: t('errProfileNotFound'),
    INVALID_ROLE: t('errInvalidRole'),
    INVALID_STATUS: t('errInvalidStatus'),
    CANNOT_REMOVE_LAST_OWNER: t('errCannotRemoveLastOwner'),
  }
  function friendlyError(message: string): string {
    return ERROR_LABELS[message] || t('genericStaffError')
  }

  async function claim(locationId: string) {
    setBusy(locationId); setError(null)
    const { data: { user } } = await supabase.auth.getUser()
    if (!user?.email) { setError(t('errAuthRequired')); setBusy(null); return }
    const { error: rpcError } = await supabase.rpc('invite_shop_staff', { p_location_id: locationId, p_email: user.email, p_role: 'owner' })
    setBusy(null)
    if (rpcError) { setError(friendlyError(rpcError.message)); return }
    router.refresh()
  }

  if (locations.length === 0) return null

  return (
    <div className="rounded-3xl border border-[#D4AF37]/30 bg-[#161616] p-6">
      <h2 className="font-black text-xl">{t('claimTitle')}</h2>
      <p className="text-sm text-white/50 mt-1">{t('claimSubtitle')}</p>
      <div className="mt-5 space-y-2">
        {locations.map((loc) => (
          <div key={loc.id} className="flex items-center justify-between rounded-xl bg-white/[.03] p-3">
            <span>{loc.name} <span className="text-white/40 text-xs">({loc.location_type})</span></span>
            <button onClick={() => claim(loc.id)} disabled={busy === loc.id} className="rounded-full bg-[#D4AF37] text-black text-xs font-bold px-4 py-2 disabled:opacity-50">
              {busy === loc.id ? t('claiming') : t('claimBtn')}
            </button>
          </div>
        ))}
      </div>
      {error && <div className="mt-3 text-sm text-red-400">{error}</div>}
    </div>
  )
}

export function ShopStaffPanel({ locationId, locationName, myRole }: { locationId: string; locationName: string; myRole: string }) {
  const t = useTranslations('ShopAdmin')
  const supabase = createClient()
  const [staff, setStaff] = useState<StaffRow[]>([])
  const [loading, setLoading] = useState(true)
  const [email, setEmail] = useState('')
  const [role, setRole] = useState('cashier')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const canManage = myRole === 'owner' || myRole === 'manager'

  const ROLE_LABELS: Record<string, string> = { owner: t('roleOwner'), manager: t('roleManager'), cashier: t('roleCashier'), inventory: t('roleInventory') }
  const STATUS_LABELS: Record<string, string> = { active: t('statusActive'), suspended: t('statusSuspended'), revoked: t('statusRevoked') }
  const ERROR_LABELS: Record<string, string> = {
    AUTH_REQUIRED: t('errAuthRequired'),
    SHOP_PERMISSION_DENIED: t('errPermissionDenied'),
    PROFILE_NOT_FOUND: t('errProfileNotFound'),
    INVALID_ROLE: t('errInvalidRole'),
    INVALID_STATUS: t('errInvalidStatus'),
    CANNOT_REMOVE_LAST_OWNER: t('errCannotRemoveLastOwner'),
  }
  function friendlyError(message: string): string {
    return ERROR_LABELS[message] || t('genericStaffError')
  }

  async function load() {
    const { data, error: rpcError } = await supabase.rpc('list_shop_staff', { p_location_id: locationId })
    setLoading(false)
    if (rpcError) { setError(friendlyError(rpcError.message)); return }
    setStaff(Array.isArray(data) ? data : [])
  }

  // Mirrors the promise-chain shape used elsewhere (WompiCheckoutButton): setState
  // only happens inside the .then() callback, never in the effect's own synchronous
  // body, which is what react-hooks/set-state-in-effect actually checks for -- calling
  // an async/await function directly from the effect still trips it even when the
  // setState calls are technically after an await.
  useEffect(() => {
    let cancelled = false
    supabase.rpc('list_shop_staff', { p_location_id: locationId }).then(({ data, error: rpcError }) => {
      if (cancelled) return
      setLoading(false)
      if (rpcError) { setError(friendlyError(rpcError.message)); return }
      setStaff(Array.isArray(data) ? data : [])
    })
    return () => { cancelled = true }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [locationId, supabase])

  async function addStaff(e: FormEvent) {
    e.preventDefault()
    if (!email.trim()) return
    setBusy(true); setError(null)
    const { error: rpcError } = await supabase.rpc('invite_shop_staff', { p_location_id: locationId, p_email: email.trim(), p_role: role })
    setBusy(false)
    if (rpcError) { setError(friendlyError(rpcError.message)); return }
    setEmail('')
    setLoading(true)
    load()
  }

  async function setStatus(profileId: string, status: string) {
    setBusy(true); setError(null)
    const { error: rpcError } = await supabase.rpc('set_shop_staff_status', { p_location_id: locationId, p_profile_id: profileId, p_status: status })
    setBusy(false)
    if (rpcError) { setError(friendlyError(rpcError.message)); return }
    setLoading(true)
    load()
  }

  return (
    <div className="rounded-3xl border border-white/10 bg-[#161616] p-6">
      <h2 className="font-black text-xl">{t('teamTitle', {name: locationName})}</h2>
      <p className="text-sm text-white/40 mt-1">{t('teamSubtitle')}</p>

      {canManage && (
        <form onSubmit={addStaff} className="mt-5 flex flex-wrap gap-2">
          <input value={email} onChange={(e) => setEmail(e.target.value)} type="email" placeholder={t('staffEmailPlaceholder')} className="flex-1 min-w-[200px] rounded-xl bg-white/[.05] border border-white/10 px-3 py-2 text-sm" />
          <select value={role} onChange={(e) => setRole(e.target.value)} className="rounded-xl bg-white/[.05] border border-white/10 px-3 py-2 text-sm">
            <option value="manager">{t('roleManager')}</option>
            <option value="cashier">{t('roleCashier')}</option>
            <option value="inventory">{t('roleInventory')}</option>
          </select>
          <button type="submit" disabled={busy} className="rounded-full bg-[#D4AF37] text-black text-xs font-bold px-5 py-2 disabled:opacity-50">{t('addBtn')}</button>
        </form>
      )}

      {error && <div className="mt-3 text-sm text-red-400">{error}</div>}

      <div className="mt-5 space-y-2 max-h-96 overflow-auto">
        {loading && <div className="text-white/40 text-sm">{t('loadingEllipsis')}</div>}
        {!loading && staff.length === 0 && <div className="text-white/40 text-sm">{t('noStaff')}</div>}
        {staff.map((s) => (
          <div key={s.profile_id} className="flex items-center justify-between rounded-xl bg-white/[.03] p-3 text-sm gap-2">
            <div className="truncate">
              <div className="font-bold truncate">{s.display_name || s.username || t('noName')}</div>
              <div className="text-white/40 text-xs">{ROLE_LABELS[s.role] || s.role} · {STATUS_LABELS[s.status] || s.status}</div>
            </div>
            {canManage && s.status === 'active' && (
              <button onClick={() => setStatus(s.profile_id, 'suspended')} disabled={busy} className="text-xs text-white/50 hover:text-white shrink-0">{t('suspendBtn')}</button>
            )}
            {canManage && s.status !== 'active' && (
              <button onClick={() => setStatus(s.profile_id, 'active')} disabled={busy} className="text-xs text-[#D4AF37] hover:text-white shrink-0">{t('reactivateBtn')}</button>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
