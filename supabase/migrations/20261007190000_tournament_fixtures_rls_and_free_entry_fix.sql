-- Challenge Dynasty -- deja que el organizador arme el cuadro de partidos, deja que el
-- organizador vea quien ya pago su inscripcion, y corrige que una categoria SIN costo de
-- inscripcion se quedaba "pendiente" para siempre.
-- ESTADO: ESCRITA, NO APLICADA. El sistema de permisos bloqueo aplicarla desde Claude
-- porque es un deploy a produccion sin revision humana; la corre Luis en el editor SQL de Supabase.
--
-- QUE PASABA (encontrado en el repaso de hoy, construyendo "armar el cuadro automatico"):
-- 1) "tournament_fixtures" (los partidos de un torneo) solo tenia permiso de LECTURA. No habia
--    ningun permiso para CREAR los partidos ni para que el sistema avance al ganador a la
--    siguiente ronda. Sin esto, el boton de "armar el cuadro" no podia guardar nada.
-- 2) "tournament_registration_payments" (quien debe/pago la inscripcion) solo lo podia ver el
--    propio jugador. El organizador no tenia forma de ver, dentro de su propio torneo, quien ya
--    pago y quien no.
-- 3) Al inscribirse, SIEMPRE queda la inscripcion en estado "pendiente" hasta que alguien confirma
--    el pago -- incluso cuando la categoria no cobra nada (costo = 0). Eso significa que en un
--    torneo gratis, nadie queda nunca "confirmado", y por lo tanto nunca se le puede armar el
--    cuadro de partidos. Esto ya pasaba antes de hoy; lo encontre al intentar armar un cuadro de
--    prueba y ver que ninguna inscripcion contaba como confirmada.
--
-- QUE HACE ESTE ARCHIVO:
-- 1) Agrega permiso para que el organizador del torneo (o quien tenga "manage_tournaments" en el
--    club organizador) cree y actualice los partidos de SU propio torneo, y tambien las "etapas"
--    y "grupos" que usa el round robin para las tablas de posiciones. Nadie mas puede tocar nada
--    de un torneo que no es suyo.
-- 2) Agrega permiso de SOLO LECTURA para que el organizador vea los pagos de inscripcion de SU
--    propio torneo (sigue sin poder cambiarlos directamente -- eso sigue pasando solo a traves de
--    la funcion seguia que ya existe, "confirm_tournament_registration_payment").
-- 3) Corrige la funcion que crea una inscripcion ("register_tournament_entry"): si la categoria no
--    cobra nada, la inscripcion queda "confirmada" de inmediato (igual que si alguien ya hubiera
--    pagado $0), en vez de quedar pendiente para siempre. No cambia nada para categorias que SI
--    cobran -- esas siguen necesitando que se confirme el pago como ya funcionaba.

create policy "tournament stages organizer write"
on public.tournament_stages
for all
to authenticated
using (
  exists (
    select 1 from public.tournaments t
    where t.id = tournament_stages.tournament_id
      and (
        t.organizer_profile_id = auth.uid()
        or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))
      )
  )
)
with check (
  exists (
    select 1 from public.tournaments t
    where t.id = tournament_stages.tournament_id
      and (
        t.organizer_profile_id = auth.uid()
        or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))
      )
  )
);

create policy "tournament groups organizer write"
on public.tournament_groups
for all
to authenticated
using (
  exists (
    select 1 from public.tournament_stages s
    join public.tournaments t on t.id = s.tournament_id
    where s.id = tournament_groups.stage_id
      and (
        t.organizer_profile_id = auth.uid()
        or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))
      )
  )
)
with check (
  exists (
    select 1 from public.tournament_stages s
    join public.tournaments t on t.id = s.tournament_id
    where s.id = tournament_groups.stage_id
      and (
        t.organizer_profile_id = auth.uid()
        or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))
      )
  )
);

create policy "tournament fixtures organizer write"
on public.tournament_fixtures
for all
to authenticated
using (
  exists (
    select 1 from public.tournaments t
    where t.id = tournament_fixtures.tournament_id
      and (
        t.organizer_profile_id = auth.uid()
        or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))
      )
  )
)
with check (
  exists (
    select 1 from public.tournaments t
    where t.id = tournament_fixtures.tournament_id
      and (
        t.organizer_profile_id = auth.uid()
        or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))
      )
  )
);

create policy "tournament payments organizer read"
on public.tournament_registration_payments
for select
to authenticated
using (
  exists (
    select 1 from public.tournament_entries te
    join public.tournaments t on t.id = te.tournament_id
    where te.id = tournament_registration_payments.entry_id
      and (
        t.organizer_profile_id = auth.uid()
        or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))
      )
  )
);

create or replace function public.register_tournament_entry(p_category_id uuid, p_member_profile_ids uuid[], p_registration_data jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_cat public.tournament_categories;
  v_tournament public.tournaments;
  v_entry uuid;
  v_member uuid;
  v_count integer;
  v_amount_due numeric;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  if coalesce(array_length(p_member_profile_ids,1),0)<1 then raise exception 'Debe existir al menos un jugador'; end if;
  select * into v_cat from public.tournament_categories where id=p_category_id for update;
  if not found then raise exception 'Category not found'; end if;
  select * into v_tournament from public.tournaments where id=v_cat.tournament_id for update;
  if not found then raise exception 'Tournament not found'; end if;
  if v_tournament.status not in ('published','registration_open') or v_cat.status<>'open' then raise exception 'Registrations are not open'; end if;
  if v_tournament.registration_opens_at is not null and now()<v_tournament.registration_opens_at then raise exception 'Registration has not opened'; end if;
  if v_tournament.registration_closes_at is not null and now()>v_tournament.registration_closes_at then raise exception 'Registration has closed'; end if;
  if v_cat.participant_mode='pair' and array_length(p_member_profile_ids,1)<>2 then raise exception 'Pair category requires exactly 2 members'; end if;
  if v_cat.participant_mode='individual' and array_length(p_member_profile_ids,1)<>1 then raise exception 'Individual category requires exactly 1 member'; end if;
  if v_cat.participant_mode='team' and array_length(p_member_profile_ids,1)<2 then raise exception 'Team category requires at least 2 members'; end if;
  select count(*) into v_count from public.tournament_entries where category_id=p_category_id and status in ('pending','confirmed','waitlisted');
  if v_cat.capacity is not null and v_count>=v_cat.capacity then raise exception 'Category capacity reached'; end if;
  foreach v_member in array p_member_profile_ids loop
    if not exists(select 1 from public.profiles where id=v_member) then raise exception 'Player not found'; end if;
    if exists(select 1 from public.tournament_entry_members tem join public.tournament_entries te on te.id=tem.entry_id where te.category_id=p_category_id and te.status in ('pending','confirmed','waitlisted') and tem.profile_id=v_member) then raise exception 'Player already registered in this category'; end if;
  end loop;
  if not auth.uid() = p_member_profile_ids[1] then
    if not exists(select 1 from public.tournaments t where t.id=v_tournament.id and (t.organizer_profile_id=auth.uid() or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid())))) then
      raise exception 'Only the captain or tournament organizer may register this entry';
    end if;
  end if;
  insert into public.tournament_entries(tournament_id,category_id,entry_type,captain_profile_id,status,registration_data)
  values(v_tournament.id,p_category_id,v_cat.participant_mode,p_member_profile_ids[1],'pending',coalesce(p_registration_data,'{}'::jsonb)) returning id into v_entry;
  foreach v_member in array p_member_profile_ids loop
    insert into public.tournament_entry_members(entry_id,profile_id,role,status)
    values(v_entry,v_member,case when v_member=p_member_profile_ids[1] then 'captain' else 'member' end,case when v_member=p_member_profile_ids[1] then 'confirmed' else 'invited' end);
    if v_member <> p_member_profile_ids[1] then
      insert into public.notifications(profile_id, category, type, title, body, source_type, source_id)
      values (
        v_member, 'tournament', 'tournament_entry_invite_received',
        'Te invitaron a un torneo', 'Alguien te anotó como compañero de equipo. Acepta o rechaza la invitación.',
        'tournament_entry', v_entry
      );
    end if;
  end loop;
  v_amount_due := coalesce(v_cat.entry_fee,v_tournament.entry_fee,0);
  insert into public.tournament_registration_payments(entry_id,amount_due,amount_paid,currency_code,status,paid_at)
  values(
    v_entry,
    v_amount_due,
    0,
    coalesce(v_tournament.currency_code,'COP'),
    case when v_amount_due=0 then 'paid' else 'unpaid' end,
    case when v_amount_due=0 then now() else null end
  );
  if v_amount_due=0 then
    update public.tournament_entries set status='confirmed', updated_at=now() where id=v_entry;
  end if;
  return v_entry;
end;
$function$;
