'use client'
import type { SupabaseClient } from '@supabase/supabase-js'
import {
  buildSingleEliminationRounds,
  buildRoundRobinPairs,
  splitIntoGroups,
  seedKnockoutFromGroups,
  buildLadderInitialRound,
  buildLadderNextRound,
  LADDER_TOTAL_ROUNDS,
  buildAmericanoRounds,
  buildMexicanoInitialRound,
  buildMexicanoNextRound,
  MEXICANO_TOTAL_ROUNDS,
  type LadderCourtResult,
  type MexicanoStandingInput,
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

  const supportedFormats = ['single_elimination', 'round_robin', 'groups_then_knockout', 'king_of_the_court', 'americano', 'mexicano']
  if (!supportedFormats.includes(formatType)) {
    throw new Error('FORMAT_NOT_SUPPORTED')
  }

  // Americano y Mexicano no usan tournament_fixtures (pareja cambia cada ronda, puntaje por
  // jugador) — usan tournament_rotation_matches, así que el chequeo de "ya se generó" mira esa
  // tabla en vez.
  if (formatType === 'americano' || formatType === 'mexicano') {
    const { count: rotationCount, error: rotationExistingError } = await supabase
      .from('tournament_rotation_matches')
      .select('id', { count: 'exact', head: true })
      .eq('category_id', categoryId)
    if (rotationExistingError) throw rotationExistingError
    if ((rotationCount ?? 0) > 0) throw new Error('ALREADY_GENERATED')
  } else {
    const { count, error: existingError } = await supabase
      .from('tournament_fixtures')
      .select('id', { count: 'exact', head: true })
      .eq('category_id', categoryId)
    if (existingError) throw existingError
    if ((count ?? 0) > 0) throw new Error('ALREADY_GENERATED')
  }

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
        : formatType === 'king_of_the_court'
          ? 'Escalera de canchas'
          : formatType === 'americano'
            ? 'Americano'
            : formatType === 'mexicano'
              ? 'Mexicano'
              : 'Cuadro de eliminación'
  // "king_of_the_court", "americano" y "mexicano" no son stage_type válidos en la base (el
  // constraint solo acepta group/round_robin/single_elimination/double_elimination/ladder/custom)
  // — king_of_the_court usa "ladder" (es justo lo que es); americano y mexicano usan "custom"
  // (no hay un tipo de "rotación" dedicado, y ambos comparten tournament_rotation_matches).
  const stageType =
    formatType === 'groups_then_knockout'
      ? 'group'
      : formatType === 'king_of_the_court'
        ? 'ladder'
        : formatType === 'americano' || formatType === 'mexicano'
          ? 'custom'
          : formatType

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

  if (formatType === 'americano') {
    // Lanza AMERICANO_REQUIRES_MULTIPLE_OF_4 si la cantidad de inscritos no es múltiplo de 4
    // (ver buildAmericanoRounds) — el panel de creación del cuadro traduce ese código a un
    // mensaje para el organizador.
    const rotationFixtures = buildAmericanoRounds(entryIds)
    const rows = rotationFixtures.map((f) => ({
      tournament_id: tournamentId,
      category_id: categoryId,
      stage_id: stageId,
      round_number: f.round,
      court: f.court,
      side_a_player1_id: f.sideA[0],
      side_a_player2_id: f.sideA[1],
      side_b_player1_id: f.sideB[0],
      side_b_player2_id: f.sideB[1],
      status: 'scheduled',
      scheduled_at: roundStart(startsAt, f.round),
    }))
    const { error: rotationError } = await supabase.from('tournament_rotation_matches').insert(rows)
    if (rotationError) throw rotationError
    return { fixturesCreated: rows.length }
  }

  if (formatType === 'mexicano') {
    // Lanza MEXICANO_REQUIRES_MULTIPLE_OF_4 si la cantidad de inscritos no es múltiplo de 4
    // (ver buildMexicanoInitialRound). Solo se arma la ronda 1 acá — las siguientes dependen del
    // puntaje acumulado y se generan una por una con generateNextMexicanoRound.
    const rotationFixtures = buildMexicanoInitialRound(entryIds)
    const rows = rotationFixtures.map((f) => ({
      tournament_id: tournamentId,
      category_id: categoryId,
      stage_id: stageId,
      round_number: f.round,
      court: f.court,
      side_a_player1_id: f.sideA[0],
      side_a_player2_id: f.sideA[1],
      side_b_player1_id: f.sideB[0],
      side_b_player2_id: f.sideB[1],
      status: 'scheduled',
      scheduled_at: roundStart(startsAt, f.round),
    }))
    const { error: rotationError } = await supabase.from('tournament_rotation_matches').insert(rows)
    if (rotationError) throw rotationError
    return { fixturesCreated: rows.length }
  }

  if (formatType === 'king_of_the_court') {
    const roundFixtures = buildLadderInitialRound(entryIds)
    const rows = roundFixtures.map((f) => ({
      tournament_id: tournamentId,
      category_id: categoryId,
      stage_id: stageId,
      round_number: f.round,
      slot: f.slot,
      side_a_entry_id: f.sideA,
      side_b_entry_id: f.sideB,
      // Un bye (cancha con un solo inscrito) se da por ganado de una vez, igual que en
      // eliminación simple, para no dejarlo esperando un rival que no existe.
      winner_entry_id: f.isBye ? f.sideA ?? f.sideB : null,
      status: f.isBye ? 'completed' : 'scheduled',
      scheduled_at: roundStart(startsAt, f.round),
    }))
    const { error: fixturesError } = await supabase.from('tournament_fixtures').insert(rows)
    if (fixturesError) throw fixturesError
    return { fixturesCreated: rows.length }
  }

  const fixturesCreated = await insertSingleElimination(supabase, { tournamentId, categoryId, stageId, startsAt, entryIds })
  return { fixturesCreated }
}

export type GenerateNextLadderRoundParams = {
  tournamentId: string
  categoryId: string
  startsAt: string | null
}

/**
 * King of the Court, ronda 2 en adelante: toma los resultados de la última ronda jugada de la
 * escalera (todas sus canchas ya con ganador) y arma la ronda siguiente — ganador sube de
 * cancha, perdedor baja (ver buildLadderNextRound). Se detiene en LADDER_TOTAL_ROUNDS: después
 * de esa ronda la escalera queda terminada y la posición final de cada cancha es el resultado.
 */
export async function generateNextLadderRound(supabase: SupabaseClient, params: GenerateNextLadderRoundParams) {
  const { tournamentId, categoryId, startsAt } = params

  const { data: stage, error: stageError } = await supabase
    .from('tournament_stages')
    .select('id')
    .eq('category_id', categoryId)
    .eq('stage_type', 'ladder')
    .limit(1)
    .maybeSingle()
  if (stageError) throw stageError
  if (!stage) throw new Error('LADDER_STAGE_NOT_FOUND')
  const stageId = (stage as { id: string }).id

  const { data: currentRoundFixtures, error: fixturesError } = await supabase
    .from('tournament_fixtures')
    .select('round_number, slot, side_a_entry_id, side_b_entry_id, winner_entry_id, status')
    .eq('stage_id', stageId)
    .order('round_number', { ascending: false })
    .order('slot', { ascending: true })
  if (fixturesError) throw fixturesError
  const fixtures = (currentRoundFixtures ?? []) as Array<{
    round_number: number
    slot: number
    side_a_entry_id: string | null
    side_b_entry_id: string | null
    winner_entry_id: string | null
    status: string
  }>
  if (fixtures.length === 0) throw new Error('LADDER_STAGE_NOT_FOUND')

  const currentRound = fixtures[0].round_number
  if (currentRound >= LADDER_TOTAL_ROUNDS) throw new Error('LADDER_COMPLETE')

  const roundFixtures = fixtures.filter((f) => f.round_number === currentRound)
  const unfinished = roundFixtures.some((f) => f.status !== 'completed' && f.status !== 'cancelled')
  if (unfinished) throw new Error('ROUND_NOT_FINISHED')

  const results: LadderCourtResult[] = roundFixtures
    .map((f) => {
      if (!f.winner_entry_id) return null // cancelado, no mueve a nadie
      const loser =
        f.side_a_entry_id && f.side_b_entry_id
          ? f.winner_entry_id === f.side_a_entry_id
            ? f.side_b_entry_id
            : f.side_a_entry_id
          : null
      return { court: f.slot, winnerEntryId: f.winner_entry_id, loserEntryId: loser }
    })
    .filter((r): r is LadderCourtResult => r !== null)

  const nextRoundNumber = currentRound + 1
  const nextFixtures = buildLadderNextRound(nextRoundNumber, results)
  const rows = nextFixtures.map((f) => ({
    tournament_id: tournamentId,
    category_id: categoryId,
    stage_id: stageId,
    round_number: f.round,
    slot: f.slot,
    side_a_entry_id: f.sideA,
    side_b_entry_id: f.sideB,
    winner_entry_id: f.isBye ? f.sideA ?? f.sideB : null,
    status: f.isBye ? 'completed' : 'scheduled',
    scheduled_at: roundStart(startsAt, f.round),
  }))
  const { error: insertError } = await supabase.from('tournament_fixtures').insert(rows)
  if (insertError) throw insertError

  return { fixturesCreated: rows.length, roundNumber: nextRoundNumber, isFinal: nextRoundNumber >= LADDER_TOTAL_ROUNDS }
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

export type RecordRotationResultParams = {
  matchId: string
  scoreA: number
  scoreB: number
}

/**
 * Registra el resultado de un partido de Americano/Mexicano (tournament_rotation_matches).
 * A diferencia de recordFixtureResult, acá no hay "ganador": el puntaje de cada lado se le suma
 * a los 2 jugadores de ese lado (ver record_rotation_match_result en la migración de rotación).
 */
export async function recordRotationMatchResult(supabase: SupabaseClient, params: RecordRotationResultParams) {
  const { data, error } = await supabase.rpc('record_rotation_match_result', {
    p_match_id: params.matchId,
    p_score_a: params.scoreA,
    p_score_b: params.scoreB,
  })
  if (error) throw error
  return data
}

export type GenerateNextMexicanoRoundParams = {
  tournamentId: string
  categoryId: string
  startsAt: string | null
}

/**
 * Mexicano, ronda 2 en adelante: toma el puntaje acumulado de todos los que jugaron la ronda
 * actual (tournament_rotation_standings) una vez que esa ronda queda completa, los reordena de
 * mejor a peor y arma las canchas de la ronda siguiente (ver buildMexicanoNextRound) — a
 * diferencia de Americano (pareja fija toda la noche), acá la pareja y el rival cambian según
 * el nivel de cada uno en ese momento. Se detiene en MEXICANO_TOTAL_ROUNDS.
 */
export async function generateNextMexicanoRound(supabase: SupabaseClient, params: GenerateNextMexicanoRoundParams) {
  const { tournamentId, categoryId, startsAt } = params

  const { data: matches, error: matchesError } = await supabase
    .from('tournament_rotation_matches')
    .select('id, stage_id, round_number, status, side_a_player1_id, side_a_player2_id, side_b_player1_id, side_b_player2_id')
    .eq('category_id', categoryId)
    .order('round_number', { ascending: false })
  if (matchesError) throw matchesError
  const rows = (matches ?? []) as Array<{
    id: string
    stage_id: string | null
    round_number: number
    status: string
    side_a_player1_id: string
    side_a_player2_id: string
    side_b_player1_id: string
    side_b_player2_id: string
  }>
  if (rows.length === 0) throw new Error('MEXICANO_STAGE_NOT_FOUND')

  const currentRound = rows[0].round_number
  if (currentRound >= MEXICANO_TOTAL_ROUNDS) throw new Error('MEXICANO_COMPLETE')

  const currentRoundMatches = rows.filter((r) => r.round_number === currentRound)
  const unfinished = currentRoundMatches.some((r) => r.status !== 'completed' && r.status !== 'cancelled')
  if (unfinished) throw new Error('ROUND_NOT_FINISHED')

  const stageId = currentRoundMatches[0].stage_id

  // Todos los que jugaron la ronda actual (= todos los inscritos de la categoría, en Mexicano
  // todos juegan todas las rondas) con su puntaje acumulado hasta ahora.
  const participantIds = Array.from(new Set(
    currentRoundMatches.flatMap((m) => [m.side_a_player1_id, m.side_a_player2_id, m.side_b_player1_id, m.side_b_player2_id])
  ))
  const { data: standingsData, error: standingsError } = await supabase
    .from('tournament_rotation_standings')
    .select('entry_id, total_points')
    .eq('category_id', categoryId)
    .in('entry_id', participantIds)
  if (standingsError) throw standingsError
  const pointsByEntry = new Map(
    (standingsData ?? []).map((s: { entry_id: string; total_points: number }) => [s.entry_id, s.total_points])
  )
  const standings: MexicanoStandingInput[] = participantIds.map((entryId) => ({
    entryId,
    totalPoints: pointsByEntry.get(entryId) ?? 0,
  }))

  const nextRoundNumber = currentRound + 1
  const nextFixtures = buildMexicanoNextRound(nextRoundNumber, standings)
  const insertRows = nextFixtures.map((f) => ({
    tournament_id: tournamentId,
    category_id: categoryId,
    stage_id: stageId,
    round_number: f.round,
    court: f.court,
    side_a_player1_id: f.sideA[0],
    side_a_player2_id: f.sideA[1],
    side_b_player1_id: f.sideB[0],
    side_b_player2_id: f.sideB[1],
    status: 'scheduled',
    scheduled_at: roundStart(startsAt, f.round),
  }))
  const { error: insertError } = await supabase.from('tournament_rotation_matches').insert(insertRows)
  if (insertError) throw insertError

  return {
    fixturesCreated: insertRows.length,
    roundNumber: nextRoundNumber,
    isFinal: nextRoundNumber >= MEXICANO_TOTAL_ROUNDS,
  }
}
