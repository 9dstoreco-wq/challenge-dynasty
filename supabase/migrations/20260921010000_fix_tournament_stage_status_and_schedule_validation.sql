-- Fix obsolete/invalid status literals in tournament draw & validation RPCs.
--
-- EVIDENCE (live DB, project ggkthvewxmsmtupjzfnk):
--   tournament_stages_status_check   -> status IN ('pending','active','completed','cancelled')
--   tournament_entry_members_status_check -> status IN ('invited','confirmed','declined','removed')
--   guard_tournament_stage_status trigger -> valid transitions: pending->{pending,active,cancelled},
--                                             active->{active,completed,cancelled}
--
-- None of the 5 functions below match this contract: they read/write 'draft' and 'ready' for
-- tournament_stages.status (values that CANNOT exist in that column) and filter
-- tournament_entry_members.status on 'active'/'accepted' (values that CANNOT exist in that column
-- either). Net effect:
--   * generate_round_robin_draw / generate_groups_to_knockout_draw: the trailing
--     "mark stage ready" UPDATE is dead code (its WHERE status='draft' never matches a real row,
--     and even if it did, writing status='ready' would violate the CHECK constraint).
--   * generate_single_elimination_draw / swap_tournament_fixture_entries: the editability guard
--     `status not in ('draft','ready')` is ALWAYS true for every real row, so both RPCs
--     unconditionally raise STAGE_NOT_EDITABLE and can never be used.
--   * validate_tournament_schedule: `tem.status in ('active','accepted')` never matches any real
--     tournament_entry_members row, so the player-overlap/rest-gap detector always sees zero
--     players, always returns issues:[] and valid:true, and silently disables all schedule-conflict
--     detection for publish_tournament_schedule. This is the highest-severity finding.
--
-- ADDENDUM (same audit, follow-up pass): generate_round_robin_draw also gates on
-- `v_stage.stage_type not in ('round_robin','groups')`, but
-- tournament_stages_stage_type_check only allows the SINGULAR 'group' (plus
-- round_robin/single_elimination/double_elimination/ladder/custom) -- 'groups'
-- (plural) can never be a real stage_type value. Since this function is exactly
-- the one used to generate round-robin fixtures INSIDE a 'group' stage (it loops
-- public.tournament_groups for the stage), this typo means every legitimate
-- group-stage round-robin draw is rejected with 'Stage type not compatible with
-- round robin' -- group-stage tournaments (groups -> knockout, the most common
-- format) can never have their group-phase fixtures generated. Fixed below by
-- checking for 'group', not 'groups'.
--
-- Fix: replace the obsolete literals with the real state machine (pending/active for stages,
-- confirmed for entry members), and the 'groups'->'group' stage_type typo. No other logic changes.

-- 1. validate_tournament_schedule: entry-member status filter
CREATE OR REPLACE FUNCTION public.validate_tournament_schedule(p_tournament_id uuid, p_slot_minutes integer DEFAULT 60, p_required_rest_slots integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_issues jsonb;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión';
  end if;

  if p_slot_minutes < 1 or p_slot_minutes > 240 then
    raise exception 'slot_minutes inválido';
  end if;

  if p_required_rest_slots < 0 or p_required_rest_slots > 5 then
    raise exception 'required_rest_slots inválido';
  end if;

  if not exists (
    select 1
    from public.tournaments t
    where t.id = p_tournament_id
      and (
        t.organizer_profile_id = auth.uid()
        or (
          t.organization_id is not null
          and public.has_organization_permission(t.organization_id, 'manage_tournaments', auth.uid())
        )
      )
  ) then
    raise exception 'No autorizado para validar este torneo';
  end if;

  with fixture_entries as (
    select
      f.id as fixture_id,
      f.tournament_id,
      f.category_id,
      f.scheduled_at,
      x.entry_id
    from public.tournament_fixtures f
    cross join lateral (
      values (f.side_a_entry_id), (f.side_b_entry_id)
    ) x(entry_id)
    where f.tournament_id = p_tournament_id
      and f.scheduled_at is not null
      and x.entry_id is not null
  ),
  fixture_players as (
    select distinct
      fe.fixture_id,
      fe.tournament_id,
      fe.category_id,
      fe.scheduled_at,
      tem.profile_id,
      fe.entry_id
    from fixture_entries fe
    join public.tournament_entry_members tem
      on tem.entry_id = fe.entry_id
     and tem.status = 'confirmed'
  ),
  player_pairs as (
    select
      a.profile_id,
      a.fixture_id as fixture_a_id,
      b.fixture_id as fixture_b_id,
      a.category_id as category_a_id,
      b.category_id as category_b_id,
      a.entry_id as entry_a_id,
      b.entry_id as entry_b_id,
      least(a.scheduled_at, b.scheduled_at) as first_start,
      greatest(a.scheduled_at, b.scheduled_at) as second_start,
      abs(extract(epoch from (a.scheduled_at - b.scheduled_at))) / 60.0 as start_gap_minutes
    from fixture_players a
    join fixture_players b
      on a.profile_id = b.profile_id
     and a.fixture_id < b.fixture_id
  ),
  issues as (
    select
      profile_id,
      fixture_a_id,
      fixture_b_id,
      category_a_id,
      category_b_id,
      entry_a_id,
      entry_b_id,
      first_start,
      second_start,
      start_gap_minutes,
      case
        when start_gap_minutes < p_slot_minutes then 'CRITICAL'
        when start_gap_minutes < (p_slot_minutes * (p_required_rest_slots + 1)) then 'CRITICAL'
        else 'OK'
      end as severity,
      case
        when start_gap_minutes < p_slot_minutes then 'SOLAPAMIENTO DE PARTIDOS'
        when start_gap_minutes < (p_slot_minutes * (p_required_rest_slots + 1)) then 'DESCANSO INSUFICIENTE'
        else null
      end as issue_type
    from player_pairs
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'severity', severity,
        'issue_type', issue_type,
        'profile_id', profile_id,
        'fixture_a_id', fixture_a_id,
        'fixture_b_id', fixture_b_id,
        'category_a_id', category_a_id,
        'category_b_id', category_b_id,
        'entry_a_id', entry_a_id,
        'entry_b_id', entry_b_id,
        'first_start', first_start,
        'second_start', second_start,
        'start_gap_minutes', round(start_gap_minutes::numeric, 2),
        'required_gap_minutes', p_slot_minutes * (p_required_rest_slots + 1),
        'blocks_publication', (severity = 'CRITICAL')
      )
      order by first_start, profile_id
    ) filter (where severity <> 'OK'),
    '[]'::jsonb
  ) into v_issues
  from issues;

  return jsonb_build_object(
    'tournament_id', p_tournament_id,
    'valid', jsonb_array_length(v_issues) = 0,
    'issue_count', jsonb_array_length(v_issues),
    'slot_minutes', p_slot_minutes,
    'required_rest_slots', p_required_rest_slots,
    'issues', v_issues
  );
end;
$function$;

-- 2. generate_round_robin_draw: stage status literal
CREATE OR REPLACE FUNCTION public.generate_round_robin_draw(p_stage_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_stage public.tournament_stages;
  v_count integer;
  v_round integer;
  v_slot integer;
  v_entry_a uuid;
  v_entry_b uuid;
  v_group record;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  select * into v_stage from public.tournament_stages where id=p_stage_id for update;
  if not found then raise exception 'Stage not found'; end if;
  if not (exists(select 1 from public.tournaments t where t.id=v_stage.tournament_id and (t.organizer_profile_id=auth.uid() or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))))) then
    raise exception 'No autorizado';
  end if;
  if v_stage.stage_type not in ('round_robin','group') then raise exception 'Stage type not compatible with round robin'; end if;
  if exists(select 1 from public.tournament_fixtures where stage_id=p_stage_id) then
    return jsonb_build_object('ok',true,'existing',true,'fixtures', (select count(*) from public.tournament_fixtures where stage_id=p_stage_id));
  end if;
  v_count:=0;
  for v_group in select g.id from public.tournament_groups g where g.stage_id=p_stage_id order by g.group_order loop
    v_round:=1;
    v_slot:=1;
    for v_entry_a, v_entry_b in
      select a.entry_id,b.entry_id
      from public.tournament_group_entries a
      join public.tournament_group_entries b on b.group_id=a.group_id and b.entry_id>a.entry_id
      where a.group_id=v_group.id
      order by a.entry_id,b.entry_id
    loop
      insert into public.tournament_fixtures(tournament_id,category_id,stage_id,group_id,slot,round_number,side_a_entry_id,side_b_entry_id,status,metadata)
      select v_stage.tournament_id,v_stage.category_id,p_stage_id,v_group.id,v_slot,v_round,v_entry_a,v_entry_b,'scheduled',jsonb_build_object('draw_engine','round_robin','generated_at',now())
      where not exists(select 1 from public.tournament_fixtures f where f.stage_id=p_stage_id and f.group_id=v_group.id and ((f.side_a_entry_id=v_entry_a and f.side_b_entry_id=v_entry_b) or (f.side_a_entry_id=v_entry_b and f.side_b_entry_id=v_entry_a)));
      if found then v_count:=v_count+1; v_slot:=v_slot+1; end if;
      if v_slot>10000 then raise exception 'Too many fixtures'; end if;
    end loop;
  end loop;
  update public.tournament_stages set status='active' where id=p_stage_id and status='pending';
  return jsonb_build_object('ok',true,'fixtures',v_count,'stage_id',p_stage_id);
end;
$function$;

-- 3. generate_groups_to_knockout_draw: stage status literal
CREATE OR REPLACE FUNCTION public.generate_groups_to_knockout_draw(p_stage_id uuid, p_next_stage_id uuid, p_qualifiers_per_group integer DEFAULT 2)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_stage public.tournament_stages;
  v_next public.tournament_stages;
  v_entry_ids uuid[];
  v_count integer := 0;
  v_i integer;
  v_fixture_id uuid;
  v_cat uuid;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  if p_qualifiers_per_group < 1 or p_qualifiers_per_group > 8 then raise exception 'Invalid qualifier count'; end if;
  select * into v_stage from public.tournament_stages where id=p_stage_id for update;
  select * into v_next from public.tournament_stages where id=p_next_stage_id for update;
  if not found then raise exception 'Stage not found'; end if;
  if v_stage.tournament_id<>v_next.tournament_id then raise exception 'Stages belong to different tournaments'; end if;
  if not (exists(select 1 from public.tournaments t where t.id=v_stage.tournament_id and (t.organizer_profile_id=auth.uid() or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))))) then raise exception 'No autorizado'; end if;
  select category_id into v_cat from public.tournament_stages where id=p_stage_id;
  select array_agg(entry_id order by rank,group_id) into v_entry_ids
  from (select tge.entry_id,tge.group_id,tge.rank,row_number() over(partition by tge.group_id order by tge.rank nulls last,tge.entry_id) rn from public.tournament_group_entries tge where tge.group_id in (select id from public.tournament_groups where stage_id=p_stage_id)) q
  where q.rn<=p_qualifiers_per_group;
  if coalesce(array_length(v_entry_ids,1),0)<2 then raise exception 'Not enough qualified entries'; end if;
  if exists(select 1 from public.tournament_fixtures where stage_id=p_next_stage_id) then return jsonb_build_object('ok',true,'existing',true,'fixtures',(select count(*) from public.tournament_fixtures where stage_id=p_next_stage_id)); end if;
  for v_i in 1..floor(array_length(v_entry_ids,1)/2) loop
    insert into public.tournament_fixtures(tournament_id,category_id,stage_id,slot,round_number,side_a_entry_id,side_b_entry_id,status,metadata)
    values(v_next.tournament_id,v_cat,p_next_stage_id,v_i,1,v_entry_ids[(v_i*2)-1],v_entry_ids[v_i*2],'scheduled',jsonb_build_object('draw_engine','groups_to_knockout','generated_at',now(),'source_stage_id',p_stage_id)) returning id into v_fixture_id;
    v_count:=v_count+1;
  end loop;
  update public.tournament_stages set status='active' where id=p_next_stage_id and status='pending';
  return jsonb_build_object('ok',true,'fixtures',v_count,'next_stage_id',p_next_stage_id,'qualifiers_per_group',p_qualifiers_per_group);
end;
$function$;

-- 4. generate_single_elimination_draw: editability guard + closing status literal
CREATE OR REPLACE FUNCTION public.generate_single_elimination_draw(p_tournament_id uuid, p_category_id uuid, p_stage_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_stage record;
  v_tournament record;
  v_entry_count integer;
  v_bracket_size integer := 1;
  v_rounds integer;
  v_existing integer;
  v_round integer;
  v_slot integer;
  v_total_slots integer;
  v_pos integer;
  v_entry_id uuid;
  v_entry_ids uuid[] := '{}';
  v_fixture_id uuid;
  v_next_id uuid;
  v_seed integer;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;

  select * into v_tournament from public.tournaments where id=p_tournament_id for update;
  if not found then raise exception 'TOURNAMENT_NOT_FOUND'; end if;

  if not (
    v_tournament.organizer_profile_id = auth.uid()
    or (v_tournament.organization_id is not null and public.has_organization_permission(v_tournament.organization_id,'manage_tournaments'))
  ) then raise exception 'TOURNAMENT_PERMISSION_DENIED'; end if;

  select * into v_stage
  from public.tournament_stages
  where id=p_stage_id and tournament_id=p_tournament_id and category_id=p_category_id
  for update;
  if not found then raise exception 'STAGE_NOT_FOUND'; end if;
  if lower(v_stage.stage_type) not in ('single_elimination','knockout','elimination') and lower(coalesce(v_stage.rules->>'format','')) <> 'single_elimination' then
    raise exception 'UNSUPPORTED_STAGE_FORMAT';
  end if;
  if v_stage.status not in ('pending','active') then raise exception 'STAGE_NOT_EDITABLE'; end if;

  select count(*) into v_existing
  from public.tournament_fixtures
  where tournament_id=p_tournament_id and category_id=p_category_id and stage_id=p_stage_id;
  if v_existing > 0 then raise exception 'DRAW_ALREADY_EXISTS'; end if;

  select count(*) into v_entry_count
  from public.tournament_entries te
  where te.tournament_id=p_tournament_id
    and te.category_id=p_category_id
    and te.status='confirmed';
  if v_entry_count < 2 then raise exception 'NOT_ENOUGH_ENTRIES'; end if;

  while v_bracket_size < v_entry_count loop
    v_bracket_size := v_bracket_size * 2;
  end loop;
  v_rounds := ceil(log(2::numeric, v_bracket_size))::integer;
  v_total_slots := v_bracket_size / 2;

  select array_agg(entry_id order by
      case when seed is not null then 0 else 1 end,
      coalesce(seed, recommended_seed),
      recommended_seed,
      entry_id
    ) into v_entry_ids
  from public.get_tournament_fair_play_entries(p_category_id)
  where entry_id in (
    select id from public.tournament_entries
    where tournament_id=p_tournament_id and category_id=p_category_id and status='confirmed'
  );

  if coalesce(array_length(v_entry_ids,1),0) <> v_entry_count then raise exception 'DRAW_ENTRY_MISMATCH'; end if;

  -- Create bracket skeleton round by round.
  for v_round in 1..v_rounds loop
    if v_round = 1 then
      v_total_slots := v_bracket_size / 2;
    else
      v_total_slots := v_bracket_size / power(2,v_round);
    end if;
    for v_slot in 1..v_total_slots loop
      insert into public.tournament_fixtures(
        tournament_id,category_id,stage_id,slot,round_number,status,metadata
      ) values (
        p_tournament_id,p_category_id,p_stage_id,v_slot,v_round,'scheduled',
        jsonb_build_object('draw_method','fair_play_auto','generated_at',now())
      );
    end loop;
  end loop;

  -- Seed first round with bracket positions. Unfilled positions are BYEs.
  for v_pos in 1..v_bracket_size loop
    v_entry_id := case when v_pos <= coalesce(array_length(v_entry_ids,1),0) then v_entry_ids[v_pos] else null end;
    if v_entry_id is null then continue; end if;
    v_slot := ceil(v_pos/2.0)::integer;
    if mod(v_pos,2)=1 then
      update public.tournament_fixtures
      set side_a_entry_id=v_entry_id,
          metadata=metadata || jsonb_build_object('side_a_seed', (select seed from public.tournament_entries where id=v_entry_id),'side_a_position',v_pos)
      where tournament_id=p_tournament_id and category_id=p_category_id and stage_id=p_stage_id and round_number=1 and slot=v_slot;
    else
      update public.tournament_fixtures
      set side_b_entry_id=v_entry_id,
          metadata=metadata || jsonb_build_object('side_b_seed', (select seed from public.tournament_entries where id=v_entry_id),'side_b_position',v_pos)
      where tournament_id=p_tournament_id and category_id=p_category_id and stage_id=p_stage_id and round_number=1 and slot=v_slot;
    end if;
  end loop;

  -- BYE slots are immediately ready; normal fixtures remain scheduled.
  update public.tournament_fixtures
  set status='ready',
      winner_entry_id=coalesce(side_a_entry_id,side_b_entry_id),
      metadata=metadata || jsonb_build_object('bye',true)
  where tournament_id=p_tournament_id and category_id=p_category_id and stage_id=p_stage_id and round_number=1
    and ((side_a_entry_id is null) <> (side_b_entry_id is null));

  -- Link every fixture to the winner destination in the next round.
  for v_round in 1..v_rounds-1 loop
    for v_slot in 1..(v_bracket_size / power(2,v_round+1)) loop
      select id into v_next_id from public.tournament_fixtures
      where tournament_id=p_tournament_id and category_id=p_category_id and stage_id=p_stage_id and round_number=v_round+1 and slot=v_slot;

      update public.tournament_fixtures f
      set next_fixture_id=v_next_id
      where f.tournament_id=p_tournament_id and f.category_id=p_category_id and f.stage_id=p_stage_id
        and f.round_number=v_round and f.slot in (v_slot*2-1,v_slot*2);
    end loop;
  end loop;

  update public.tournament_stages set status='active' where id=p_stage_id;
  return v_bracket_size;
end;
$function$;

-- 5. swap_tournament_fixture_entries: editability guard
CREATE OR REPLACE FUNCTION public.swap_tournament_fixture_entries(p_fixture_a uuid, p_fixture_b uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  a record; b record; t record;
  tmp_a uuid; tmp_b uuid; v_stage_status text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_fixture_a = p_fixture_b then raise exception 'SAME_FIXTURE'; end if;
  select * into a from public.tournament_fixtures where id=p_fixture_a for update;
  if not found then raise exception 'FIXTURE_NOT_FOUND'; end if;
  select * into b from public.tournament_fixtures where id=p_fixture_b for update;
  if not found then raise exception 'FIXTURE_NOT_FOUND'; end if;
  if a.tournament_id<>b.tournament_id or a.category_id<>b.category_id or a.stage_id<>b.stage_id or a.round_number<>1 or b.round_number<>1 then raise exception 'INCOMPATIBLE_FIXTURES'; end if;
  select * into t from public.tournaments where id=a.tournament_id for update;
  if not (t.organizer_profile_id=auth.uid() or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments'))) then raise exception 'TOURNAMENT_PERMISSION_DENIED'; end if;
  select s.status into v_stage_status from public.tournament_stages s where s.id=a.stage_id;
  if v_stage_status not in ('pending','active') then raise exception 'STAGE_NOT_EDITABLE'; end if;
  if a.status in ('completed','in_progress') or b.status in ('completed','in_progress') then raise exception 'FIXTURE_NOT_EDITABLE'; end if;
  tmp_a:=a.side_a_entry_id; tmp_b:=a.side_b_entry_id;
  update public.tournament_fixtures set side_a_entry_id=b.side_a_entry_id,side_b_entry_id=b.side_b_entry_id,
    metadata=metadata||jsonb_build_object('manual_override',true,'override_by',auth.uid(),'override_at',now()) where id=a.id;
  update public.tournament_fixtures set side_a_entry_id=tmp_a,side_b_entry_id=tmp_b,
    metadata=metadata||jsonb_build_object('manual_override',true,'override_by',auth.uid(),'override_at',now()) where id=b.id;
end;
$function$;
