// Lecturas de cartas coleccionables (dynasty_cards). Pensado para no romper nada si las tablas
// todavia no existen en la base: cualquier error devuelve una lista vacia.
import type { SupabaseClient } from '@supabase/supabase-js'

export type CardRarity = 'common' | 'rare' | 'epic' | 'legendary'
export type CardOrigin = 'base' | 'win_reward'

export interface DynastyCardView {
  id: string
  serial: number
  rarity: CardRarity
  origin: CardOrigin
  isProtected: boolean
  sportId: string
  sportName: string | null
  sportIcon: string | null
  playerName: string
  username: string | null
  rating: number
  level: number
  ownerId: string
}

type Row = {
  id: string
  serial: number
  rarity: CardRarity
  origin: CardOrigin
  is_protected: boolean
  sport_id: string
  owner_profile_id: string
  stats: { rating?: number; level?: number } | null
  sport: { name: string | null; icon: string | null } | { name: string | null; icon: string | null }[] | null
  original: { display_name: string | null; username: string | null } | { display_name: string | null; username: string | null }[] | null
}

function one<T>(v: T | T[] | null | undefined): T | null {
  if (!v) return null
  return Array.isArray(v) ? (v[0] ?? null) : v
}

const SELECT =
  'id,serial,rarity,origin,is_protected,sport_id,owner_profile_id,stats,sport:sports(name,icon),original:profiles!dynasty_cards_original_profile_id_fkey(display_name,username)'

const RARITY_ORDER: Record<CardRarity, number> = { legendary: 0, epic: 1, rare: 2, common: 3 }

export function toCardView(row: Row, fallbackName: string): DynastyCardView {
  const sport = one(row.sport)
  const original = one(row.original)
  return {
    id: row.id,
    serial: Number(row.serial),
    rarity: row.rarity,
    origin: row.origin,
    isProtected: row.is_protected,
    sportId: row.sport_id,
    sportName: sport?.name ?? null,
    sportIcon: sport?.icon ?? null,
    playerName: original?.display_name || original?.username || fallbackName,
    username: original?.username ?? null,
    rating: Math.round(Number(row.stats?.rating ?? 1000)),
    level: Number(row.stats?.level ?? 1),
    ownerId: row.owner_profile_id,
  }
}

export async function getPlayerCards(supabase: SupabaseClient, ownerId: string, fallbackName: string): Promise<DynastyCardView[]> {
  try {
    const { data, error } = await supabase.from('dynasty_cards').select(SELECT).eq('owner_profile_id', ownerId)
    if (error || !data) return []
    return (data as unknown as Row[])
      .map((r) => toCardView(r, fallbackName))
      .sort((a, b) => RARITY_ORDER[a.rarity] - RARITY_ORDER[b.rarity] || b.rating - a.rating)
  } catch {
    return []
  }
}

export interface ChallengeStakeView {
  profileId: string
  status: 'locked' | 'settled' | 'released'
  card: DynastyCardView | null
}

type StakeRow = { profile_id: string; status: 'locked' | 'settled' | 'released'; card: Row | Row[] | null }

// null = la funcion de cartas no esta disponible (tablas ausentes o error): la UI oculta el panel.
export async function getChallengeStakes(supabase: SupabaseClient, challengeId: string, fallbackName: string): Promise<ChallengeStakeView[] | null> {
  try {
    const { data, error } = await supabase
      .from('challenge_card_stakes')
      .select(`profile_id,status,card:dynasty_cards(${SELECT})`)
      .eq('challenge_id', challengeId)
      .in('status', ['locked', 'settled'])
    if (error || !data) return null
    return (data as unknown as StakeRow[]).map((s) => {
      const c = one(s.card)
      return { profileId: s.profile_id, status: s.status, card: c ? toCardView(c, fallbackName) : null }
    })
  } catch {
    return null
  }
}

export interface CardTransferView {
  id: string
  createdAt: string
  fromName: string
  toName: string
  fromId: string
  toId: string
  card: DynastyCardView | null
}

type TransferRow = {
  id: string
  created_at: string
  from_profile_id: string
  to_profile_id: string
  card: Row | Row[] | null
  from: { display_name: string | null } | { display_name: string | null }[] | null
  to: { display_name: string | null } | { display_name: string | null }[] | null
}

export async function getRecentTransfers(supabase: SupabaseClient, profileId: string, fallbackName: string, limit = 10): Promise<CardTransferView[]> {
  try {
    const { data, error } = await supabase
      .from('dynasty_card_transfers')
      .select(`id,created_at,from_profile_id,to_profile_id,card:dynasty_cards(${SELECT}),from:profiles!dynasty_card_transfers_from_profile_id_fkey(display_name),to:profiles!dynasty_card_transfers_to_profile_id_fkey(display_name)`)
      .or(`from_profile_id.eq.${profileId},to_profile_id.eq.${profileId}`)
      .order('created_at', { ascending: false })
      .limit(limit)
    if (error || !data) return []
    return (data as unknown as TransferRow[]).map((r) => {
      const c = one(r.card)
      return {
        id: r.id,
        createdAt: r.created_at,
        fromId: r.from_profile_id,
        toId: r.to_profile_id,
        fromName: one(r.from)?.display_name ?? fallbackName,
        toName: one(r.to)?.display_name ?? fallbackName,
        card: c ? toCardView(c, fallbackName) : null,
      }
    })
  } catch {
    return []
  }
}
