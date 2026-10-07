'use client'
import type { SupabaseClient } from '@supabase/supabase-js'
import {
  buildSingleEliminationRounds,
  buildRoundRobinPairs,
  splitIntoGroups,
  seedKnockoutFromGroups,
} from './tournamentBracket'

// Deja 2 horas entre ronda y ronda (dentro de una ronda, los partidos se asumen en paralelo
// en varias canchas). Es una fecha de referencia simple; el organizador puede ajustarla luego
// desde Supabase si hace falta repartir canchas con más detalle.
const ROUND_GAP_HOURS = 2

function roundStart(base: string | null, roundNumber: number): string {
  const anchor = base ? new Date(base) : new Date(Date.now() + 24 * 60 * 60 * 1000)
  return new Date(anchor.getTime() + (roundNumber - 1) * ROUND_GAP_HOURS * 60 * 60 * 1000).toISOString()
}

export type GenerateBracketParams = {
  tournamentId: string
  categoryId: string
  formatType: string
  startsAt: string | null
}

async function insertGroupStage(
  supabase: SupabaseClient,
  args: { tournamentId: string; categoryId: string; stageId: string; startsAt: string | null; entryIds: string[] }
) {
  const { tournamentId, categoryId, stageId, startsAt, entryIds } = args
  const { data: group, error: groupError } = await supabase
    .from('tournament_groups')
    .insert({ stage_id: stageId, name: 'Grupo único', group_order: 1 })
    .select('id')
    .single()
  if (groupError) throw groupError
  const groupId = (group as { id: string }).id

  const { error: groupEntriesError } = await supabase.from('tournament_group_entries').insert(
    entryIds.map((entryId: string) => ({
      group_id: groupId,
      entry_id: entryId,
      points: 0,
      played: 0,
      wins: 0,
      losses: 0,
      score_for: 0,
      score_against: 0,
    }))
  )
  if (groupEntriesError) throw groupEntriesError

  const pairs = buildRoundRobinPairs(entryIds)
  const rows = pairs.map((p) => ({
    tournament_id: tournamentId,
    category_id: categoryId,
    stage_id: stageId,
    group_id: groupId,
    round_number: p.round,
    side_a_entry_id: p.sideA,
    side_b_entry_id: p.sideB,
    status: 'scheduled',
    scheduled_at: roundStart(startsAt, p.round),
  }))
  const { error: fixturesError } = await supabase.from('tournament_fixtures').insert(rows)
  if (fixturesError) throw fixturesError
  return rows.length
}

async function insertMultipleGroups(
  supabase: SupabaseClient,
  args: { tournamentId: string; categoryId: string; stageId: string; startsAt: string | null; groups: string[][] }
) {
  const { tournamentId, categoryId, stageId, startsAt, groups } = args
  let fixturesCreated = 0
  for (let i = 0; i < groups.length; i++) {
    const { data: group, error: groupError } = await supabase
      .from('tournament_groups')
      .insert({ stage_id: stageId, name: `Grupo ${i + 1}`, group_order: i + 1 })
      .select('id')
      .single()
    if (groupError) throw groupError
    const groupId = (group as { id: string }).id

    const { error: groupEntriesError } = await supabase.from('tournament_group_entries').insert(
      groups[i].map((entryId: string) => ({
        group_id: groupId,
        entry_id: entryId,
        points: 0,
        played: 0,
        wins: 0,
        losses: 0,
        score_for: 0,
        score_against: 0,
      }))
    )
    if (groupEntriesError) throw groupEntriesError

    const pairs = buildRoundRobinPairs(groups[i])
    const rows = pairs.map((p) => ({
      tournament_id: tournamentId,
      category_id: categoryId,
      stage_id: stageId,
      group_id: groupId,
      round_number: p.round,
      side_a_entry_id: p.sideA,
      side_b_entry_id: p.sideB,
      status: 'scheduled',
      scheduled_at: roundStart(startsAt, p.round),
    }))
    const { error: fixturesError } = await supabase.from('tournament_fixtures').insert(rows)
    if (fixturesError) throw fixturesError
    fixturesCreated += rows.length
  }
  return fixturesCreated
}

async function insertSingleElimination(
  supabase: SupabaseClient,
  args: { tournamentId: string; categoryId: string; stageId: string; startsAt: string | null; entryIds: string[] }
) {
  const { tournamentId, categoryId, stageId, startsAt, entryIds } = args
  // Se inserta de la última ronda hacia la primera, para poder enlazar next_fixture_id con un
  // id real ya creado (next_fixture_id siempre apunta HACIA ADELANTE, a una ronda posterior).
  const rounds = buildSingleEliminationRounds(entryIds)
  let nextRoundIdsBySlot: Map<number, string> | null = null
  let fixturesCreated = 0

  for (let r = rounds.length - 1; r >= 0; r--) {
    const roundFixtures = rounds[r]
    const roundNumber = r + 1
    const idsBySlot = new Map<number, string>()
    for (const f of roundFixtures) {
      if (roundNumber === 1 && !f.sideA && !f.sideB) continue // nadie juega aquí, no se guarda
      const nextId = nextRoundIdsBySlot?.get(Math.floor(f.slot / 2)) ?? null
      const winner = f.isBye ? f.sideA ?? f.sideB : null
      const { data: row, error: insertError } = await supabase
        .from('tournament_fixtures')
        .insert({
          tournament_id: tournamentId,
          category_id: categoryId,
          stage_id: stageId,
          round_number: roundNumber,
          slot: f.slot,
          side_a_entry_id: f.sideA,
          side_b_entry_id: f.sideB,
          winner_entry_id: winner,
          status: winner ? 'completed' : 'scheduled',
          next_fixture_id: nextId,
          scheduled_at: roundStart(startsAt, roundNumber),
        })
        .select('id')
        .single()
      if (insertError) throw insertError
      idsBySlot.set(f.slot, (row as { id: string }).id)
      fixturesCreated += 1
    }
    nextRoundIdsBySlot = idsBySlot
  }

  return fixturesCreated
}

/**
 * Crea los partidos (tournament_fixtures) de una categoría a partir de los inscritos
 * confirmados. Soporta "single_elimination", "round_robin" y la fase de grupos de
 * "groups_then_knockout" (el cuadro final se genera después, por separado, con
 * generateKnockoutStage, una vez que todos los partidos de grupo ya tienen resultado).
 * Para los otros formatos lanza FORMAT_NOT_SUPPORTED (ver Auditoría de Torneos: doble
 * eliminación y escalera quedan pendientes).
 */
export async function generateBracket(supabase: SupabaseClient, params: GenerateBracketParams) {
  const { tournamentId, categoryId, formatType, startsAt } = params

  if (formatType !== 'single_elimination' && formatType !== 'round_robin' && formatType !== 'groups_then_knockout') {
    throw new Error('FORMAT_NOT_SUPPORTED')
  }

  const { count, error: existingError } = await supabase
    .from('tournament_fixtures')
    .select('id', { count: 'exact', head: true })
    .eq('category_id', categoryId)
  if (existingError) throw existingError
  if ((count ?? 0) > 0) throw new Error('ALREADY_GENERATED')

  const { data: entries, error: entriesError } = await supabase
    .from('tournament_entries')
    .select('id, created_at, seed')
    .eq('category_id', categoryId)
    .eq('status', 'confirmed')
    .order('seed', { ascending: true, nullsFirst: false })
    .order('created_at', { ascending: true })
  if (entriesError) throw entriesError
  const entryIds = (entries ?? []).map((e: { id: string }) => e.id)
  if (entryIds.length < 2) throw new Error('NOT_ENOUGH_ENTRIES')

  const stageName =
    formatType === 'round_robin'
      ? 'Todos contra todos'
      : formatType === 'groups_then_knockout'
        ? 'Fase de grupos'
        : 'Cuadro de eliminación'
  const stageType = formatType === 'groups_then_knockout' ? 'group' : formatType

  const { data: stage, error: stageError } = await supabase
    .from('tournament_stages')
    .insert({
      tournament_id: tournamentId,
      category_id: categoryId,
      name: stageName,
      stage_type: stageType,
      stage_order: 1,
      status: 'active',
    })
    .select('id')
    .single()
  if (stageError) throw stageError
  const stageId = (stage as { id: string }).id

  if (formatType === 'round_robin') {
    const fixturesCreated = await insertGroupStage(supabase, { tournamentId, categoryId, stageId, startsAt, entryIds })
    return { fixturesCreated }
  }

  if (formatType === 'groups_then_knockout') {
    const groups = splitIntoGroups(entryIds, 4)
    const fixturesCreated = await insertMultipleGroups(supabase, { tournamentId, categoryId, stageId, startsAt, groups })
    return { fixturesCreated }
  }

  const fixturesCreated = await insertSingleElimination(supabase, { tournamentId, categoryId, stageId, startsAt, entryIds })
  return { fixturesCreated }
}

export type GenerateKnockoutParams = {
  tournamentId: string
  categoryId: string
  startsAt: string | null
  qualifiersPerGroup?: number
}

/**
 * Segundo paso de "grupos + eliminación": una vez que TODOS los partidos de la fase de grupos
 * ya tienen resultado, toma los mejores de cada grupo (por la tabla de posiciones) y arma el
 * cuadro de eliminación final con ellos.
 */
export async function generateKnockoutStage(supabase: SupabaseClient, params: GenerateKnockoutParams) {
  const { tournamentId, categoryId, startsAt, qualifiersPerGroup = 2 } = params

  const { data: groupStage, error: stageError } = await supabase
    .from('tournament_stages')
    .select('id')
    .eq('category_id', categoryId)
    .eq('stage_type', 'group')
    .order('stage_order', { ascending: true })
    .limit(1)
    .maybeSingle()
  if (stageError) throw stageError
  if (!groupStage) throw new Error('GROUP_STAGE_NOT_FOUND')
  const groupStageId = (groupStage as { id: string }).id

  const { count: unfinished, error: unfinishedError } = await supabase
    .from('tournament_fixtures')
    .select('id', { count: 'exact', head: true })
    .eq('stage_id', groupStageId)
    .not('status', 'in', '(completed,cancelled)')
  if (unfinishedError) throw unfinishedError
  if ((unfinished ?? 0) > 0) throw new Error('GROUPS_NOT_FINISHED')

  const { data: groups, error: groupsError } = await supabase
    .from('tournament_groups')
    .select('id, group_order')
    .eq('stage_id', groupStageId)
    .order('group_order', { ascending: true })
  if (groupsError) throw groupsError
  const groupIds = (groups ?? []).map((g: { id: string }) => g.id)
  if (groupIds.length === 0) throw new Error('GROUP_STAGE_NOT_FOUND')

  const { data: standings, error: standingsError } = await supabase
    .from('tournament_group_entries')
    .select('group_id, entry_id, rank')
    .in('group_id', groupIds)
    .order('rank', { ascending: true, nullsFirst: false })
  if (standingsError) throw standingsError

  const qualifiersByGroup: string[][] = groupIds.map((groupId: string) =>
    (standings ?? [])
      .filter((s: { group_id: string }) => s.group_id === groupId)
      .slice(0, qualifiersPerGroup)
      .map((s: { entry_id: string }) => s.entry_id)
  )
  const seededEntryIds = seedKnockoutFromGroups(qualifiersByGroup)
  if (seededEntryIds.length < 2) throw new Error('NOT_ENOUGH_ENTRIES')

  const { data: stage, error: knockoutStageError } = await supabase
    .from('tournament_stages')
    .insert({
      tournament_id: tournamentId,
      category_id: categoryId,
      name: 'Fase final',
      stage_type: 'single_elimination',
      stage_order: 2,
      status: 'active',
    })
    .select('id')
    .single()
  if (knockoutStageError) throw knockoutStageError
  const stageId = (stage as { id: string }).id

  const fixturesCreated = await insertSingleElimination(supabase, {
    tournamentId,
    categoryId,
    stageId,
    startsAt,
    entryIds: seededEntryIds,
  })
  return { fixturesCreated }
}

export type RecordResultParams = {
  fixtureId: string
  winnerEntryId: string
  scoreA: number | null
  scoreB: number | null
}

/**
 * Registra el resultado de un partido (reusa la función ya existente del lado del servidor,
 * que se encarga del ranking y de las notificaciones) y, si ese partido alimenta a otro de la
 * siguiente ronda, avanza al ganador automáticamente.
 */
export async function recordFixtureResult(supabase: SupabaseClient, params: RecordResultParams) {
  const { data, error } = await supabase.rpc('record_tournament_fixture_result', {
    p_fixture_id: params.fixtureId,
    p_winner_entry_id: params.winnerEntryId,
    p_score_a: params.scoreA,
    p_score_b: params.scoreB,
  })
  if (error) throw error

  const { data: fx, error: fxError } = await supabase
    .from('tournament_fixtures')
    .select('next_fixture_id, slot')
    .eq('id', params.fixtureId)
    .single()
  if (fxError) throw fxError
  const row = fx as { next_fixture_id: string | null; slot: number | null }
  if (row.next_fixture_id) {
    const side = (row.slot ?? 0) % 2 === 0 ? 'side_a_entry_id' : 'side_b_entry_id'
    const { error: advanceError } = await supabase
      .from('tournament_fixtures')
      .update({ [side]: params.winnerEntryId })
      .eq('id', row.next_fixture_id)
    if (advanceError) throw advanceError
  }

  return data
}
