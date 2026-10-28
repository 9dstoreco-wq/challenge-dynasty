'use client'
import { useEffect, useState } from 'react'

// Compartido por Sidebar.tsx y BottomNav.tsx: oculta el item "Finanzas" del menu hasta que el
// usuario tenga algo real registrado en esas tablas. Ver app/api/finance/status/route.ts.
export function useHasFinanceActivity(): boolean {
  const [hasActivity, setHasActivity] = useState(false)
  useEffect(() => {
    let cancelled = false
    fetch('/api/finance/status')
      .then((res) => (res.ok ? res.json() : { hasActivity: false }))
      .then((data) => { if (!cancelled) setHasActivity(Boolean(data?.hasActivity)) })
      .catch(() => {})
    return () => { cancelled = true }
  }, [])
  return hasActivity
}
