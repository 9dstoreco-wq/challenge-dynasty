-- NUEVO (2026-10-27, "dale con todo"): tuberia del "circuito de puntos" (varios torneos de la
-- misma categoria conectados en una temporada, con una tabla de posiciones propia). Ver la doc
-- "Circuito de Puntos - Plan Tecnico" (https://claude.ai/artifact/UiDwKgSuTWmRYFQxoRfSby) para el
-- diseno completo; esto es la implementacion de las 3 tablas + las funciones de esa doc.
--
-- La deteccion de podio para los 3 formatos (eliminacion directa, suizo, grupos+eliminacion) y
-- todo este archivo completo ya se probaron contra produccion en modo revertible
-- (BEGIN...ROLLBACK, incluyendo DDL de las 3 tablas nuevas) antes de aplicarlo de verdad. No se
-- inventa ningun precio/puntaje real aparte de la tabla de puntos por defecto (100/60/40/20/5),
-- que Luis puede ajustar por circuito en points_table (jsonb) sin tocar codigo.

create or replace function public.get_tournament_category_placements(p_category_id uuid)
 returns table (entry_id uuid, placement smallint)
 language sql
 stable
 set search_path to 'public', 'pg_temp'
as $function$
  with elim_stage as (
    select id as stage_id
    from public.tournament_stages
    where category_id = p_category_id
      and stage_type in ('single_elimination', 'double_elimination')
    order by stage_order desc
    limit 1
  ),
  final_round as (
    select max(round_number) as rn
    from public.tournament_fixtures
    where stage_id = (select stage_id from elim_stage)
  ),
  final_fixture as (
    select f.* from public.tournament_fixtures f, final_round fr
    where f.stage_id = (select stage_id from elim_stage) and f.round_number = fr.rn
  ),
  semis as (
    select f.* from public.tournament_fixtures f, final_round fr
    where f.stage_id = (select stage_id from elim_stage) and f.round_number = fr.rn - 1
  ),
  quarters as (
    select f.* from public.tournament_fixtures f, final_round fr
    where f.stage_id = (select stage_id from elim_stage) and f.round_number = fr.rn - 2
  ),
  elim_tiers as (
    select ff.winner_entry_id as entry_id, 1::smallint as placement
    from final_fixture ff where ff.winner_entry_id is not null
    union all
    select (case when ff.winner_entry_id = ff.side_a_entry_id then ff.side_b_entry_id else ff.side_a_entry_id end), 2
    from final_fixture ff where ff.winner_entry_id is not null
    union all
    select (case when s.winner_entry_id = s.side_a_entry_id then s.side_b_entry_id else s.side_a_entry_id end), 3
    from semis s
    where s.winner_entry_id is not null and s.side_a_entry_id is not null and s.side_b_entry_id is not null
    union all
    select (case when q.winner_entry_id = q.side_a_entry_id then q.side_b_entry_id else q.side_a_entry_id end), 4
    from quarters q
    where q.winner_entry_id is not null and q.side_a_entry_id is not null and q.side_b_entry_id is not null
  ),
  group_tiers as (
    select ge.entry_id,
      (case when ge.rank = 1 then 1 when ge.rank = 2 then 2 when ge.rank = 3 then 3 when ge.rank = 4 then 4 else 5 end)::smallint as placement
    from public.tournament_group_entries ge
    join public.tournament_groups g on g.id = ge.group_id
    join public.tournament_stages st on st.id = g.stage_id
    where st.category_id = p_category_id
      and not exists (select 1 from elim_stage)
      and ge.rank is not null
  ),
  ranked as (
    select * from elim_tiers
    union all
    select * from group_tiers
  ),
  all_entries as (
    select te.id as entry_id
    from public.tournament_entries te
    where te.category_id = p_category_id and te.status = 'confirmed'
  )
  select ae.entry_id, coalesce(min(r.placement), 5::smallint) as placement
  from all_entries ae
  left join ranked r on r.entry_id = ae.entry_id
  group by ae.entry_id;
$function$;

grant execute on function public.get_tournament_category_placements(uuid) to authenticated, anon;

create table if not exists public.tournament_circuits (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete set null,
  organizer_profile_id uuid references public.profiles(id) on delete set null,
  sport_id uuid references public.sports(id),
  name text not null,
  category_label text,
  season_starts_at date,
  season_ends_at date,
  points_table jsonb not null default '{"champion":100,"finalist":60,"semifinalist":40,"quarterfinalist":20,"participant":5}'::jsonb,
  status text not null default 'active' check (status = any (array['draft','active','completed','cancelled'])),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tournament_circuits_owner_check check (organization_id is not null or organizer_profile_id is not null)
);

create table if not exists public.circuit_tournaments (
  id uuid primary key default gen_random_uuid(),
  circuit_id uuid not null references public.tournament_circuits(id) on delete cascade,
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  category_id uuid not null references public.tournament_categories(id) on delete cascade,
  points_applied boolean not null default false,
  applied_at timestamptz,
  created_at timestamptz not null default now(),
  unique (tournament_id, category_id)
);

create table if not exists public.circuit_standings (
  id uuid primary key default gen_random_uuid(),
  circuit_id uuid not null references public.tournament_circuits(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  points numeric not null default 0,
  tournaments_played integer not null default 0,
  best_placement smallint,
  updated_at timestamptz not null default now(),
  unique (circuit_id, profile_id)
);

alter table public.tournament_circuits enable row level security;
alter table public.circuit_tournaments enable row level security;
alter table public.circuit_standings enable row level security;

create policy "circuits public read" on public.tournament_circuits for select using (true);
create policy "circuits organizer write" on public.tournament_circuits for all using (
  organizer_profile_id = auth.uid() or (organization_id is not null and public.has_organization_permission(organization_id, 'manage_tournaments', auth.uid()))
) with check (
  organizer_profile_id = auth.uid() or (organization_id is not null and public.has_organization_permission(organization_id, 'manage_tournaments', auth.uid()))
);
create policy "circuit tournaments public read" on public.circuit_tournaments for select using (true);
create policy "circuit standings public read" on public.circuit_standings for select using (true);

create or replace function public.create_tournament_circuit(
  p_name text, p_sport_id uuid default null, p_category_label text default null,
  p_season_starts_at date default null, p_season_ends_at date default null,
  p_organization_id uuid default null, p_points_table jsonb default null
)
 returns uuid language plpgsql security definer set search_path to 'public', 'pg_temp'
as $function$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_organization_id is not null and not public.has_organization_permission(p_organization_id, 'manage_tournaments') then
    raise exception 'forbidden';
  end if;
  if coalesce(btrim(p_name), '') = '' then raise exception 'NAME_REQUIRED'; end if;
  insert into public.tournament_circuits(name, sport_id, category_label, season_starts_at, season_ends_at, organization_id, organizer_profile_id, points_table)
  values (p_name, p_sport_id, p_category_label, p_season_starts_at, p_season_ends_at, p_organization_id,
    case when p_organization_id is null then auth.uid() else null end,
    coalesce(p_points_table, '{"champion":100,"finalist":60,"semifinalist":40,"quarterfinalist":20,"participant":5}'::jsonb))
  returning id into v_id;
  return v_id;
end;
$function$;
grant execute on function public.create_tournament_circuit(text, uuid, text, date, date, uuid, jsonb) to authenticated;

create or replace function public.add_tournament_to_circuit(p_circuit_id uuid, p_tournament_id uuid, p_category_id uuid)
 returns uuid language plpgsql security definer set search_path to 'public', 'pg_temp'
as $function$
declare
  v_circuit public.tournament_circuits%rowtype;
  v_category public.tournament_categories%rowtype;
  v_ct_id uuid; v_points jsonb; v_awarded numeric; r record;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into v_circuit from public.tournament_circuits where id = p_circuit_id;
  if not found then raise exception 'circuit_not_found'; end if;
  if not (
    v_circuit.organizer_profile_id = auth.uid()
    or (v_circuit.organization_id is not null and public.has_organization_permission(v_circuit.organization_id, 'manage_tournaments', auth.uid()))
  ) then raise exception 'forbidden'; end if;

  select tc.* into v_category from public.tournament_categories tc where tc.id = p_category_id and tc.tournament_id = p_tournament_id;
  if not found then raise exception 'category_not_found'; end if;
  if v_category.status <> 'completed' then raise exception 'CATEGORY_NOT_COMPLETED'; end if;

  insert into public.circuit_tournaments(circuit_id, tournament_id, category_id) values (p_circuit_id, p_tournament_id, p_category_id) returning id into v_ct_id;
  v_points := v_circuit.points_table;

  for r in
    select tem.profile_id, min(pl.placement) as placement
    from public.get_tournament_category_placements(p_category_id) pl
    join public.tournament_entries te on te.id = pl.entry_id
    join public.tournament_entry_members tem on tem.entry_id = te.id and tem.status = 'confirmed'
    group by tem.profile_id
  loop
    v_awarded := case r.placement
      when 1 then coalesce((v_points->>'champion')::numeric, 0)
      when 2 then coalesce((v_points->>'finalist')::numeric, 0)
      when 3 then coalesce((v_points->>'semifinalist')::numeric, 0)
      when 4 then coalesce((v_points->>'quarterfinalist')::numeric, 0)
      else coalesce((v_points->>'participant')::numeric, 0)
    end;
    insert into public.circuit_standings(circuit_id, profile_id, points, tournaments_played, best_placement, updated_at)
    values (p_circuit_id, r.profile_id, v_awarded, 1, r.placement, now())
    on conflict (circuit_id, profile_id) do update
      set points = public.circuit_standings.points + excluded.points,
          tournaments_played = public.circuit_standings.tournaments_played + 1,
          best_placement = least(public.circuit_standings.best_placement, excluded.best_placement),
          updated_at = now();
  end loop;

  update public.circuit_tournaments set points_applied = true, applied_at = now() where id = v_ct_id;
  return v_ct_id;
end;
$function$;
grant execute on function public.add_tournament_to_circuit(uuid, uuid, uuid) to authenticated;

create or replace function public.get_circuit_standings(p_circuit_id uuid)
 returns table (profile_id uuid, display_name text, avatar_url text, points numeric, tournaments_played integer, best_placement smallint, rank integer)
 language sql stable set search_path to 'public', 'pg_temp'
as $function$
  select cs.profile_id, p.display_name, p.avatar_url, cs.points, cs.tournaments_played, cs.best_placement,
         row_number() over (order by cs.points desc, cs.best_placement asc nulls last, cs.tournaments_played desc)::int as rank
  from public.circuit_standings cs join public.profiles p on p.id = cs.profile_id
  where cs.circuit_id = p_circuit_id order by rank;
$function$;
grant execute on function public.get_circuit_standings(uuid) to authenticated, anon;
