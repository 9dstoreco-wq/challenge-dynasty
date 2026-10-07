-- Challenge Dynasty -- cierra el hueco de consentimiento al inscribir pareja/equipo en torneos.
-- ESTADO: ESCRITA, NO APLICADA. El sistema de permisos bloqueo aplicarla desde Claude
-- porque es un deploy a produccion sin revision humana; la corre Luis en el editor SQL de Supabase.
--
-- QUE PASABA: cuando alguien se inscribe en un torneo con pareja/equipo, el sistema metia a los
-- demas jugadores como "invited" sin preguntarles nada, y no existia ninguna forma (ni boton, ni
-- funcion) de que esa persona aceptara o rechazara. Se descubrio probando el flujo durante las
-- pruebas de abuso que pidio Luis.
--
-- QUE HACE ESTE ARCHIVO:
-- 1) Agrega una funcion nueva para que el invitado acepte o rechace su propia invitacion.
-- 2) Avisa (notificacion) al capitan cuando el invitado responde.
-- 3) Avisa (notificacion) a cada invitado en el momento en que lo meten al equipo, para que se
--    entere y pueda ir a aceptar/rechazar (antes no se enteraba de nada).
-- No borra ni cambia nada de lo que ya existia en create_challenge, retos, cartas, etc.

create or replace function public.respond_tournament_entry_invite(p_entry_id uuid, p_accept boolean)
 returns void
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_member public.tournament_entry_members;
  v_captain uuid;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;

  select * into v_member from public.tournament_entry_members
    where entry_id = p_entry_id and profile_id = auth.uid()
    for update;

  if not found then
    raise exception 'No tienes una invitación pendiente para este equipo';
  end if;

  if v_member.status <> 'invited' then
    raise exception 'Esta invitación ya fue respondida';
  end if;

  update public.tournament_entry_members
    set status = case when p_accept then 'confirmed' else 'rejected' end
    where entry_id = p_entry_id and profile_id = auth.uid();

  if not p_accept then
    update public.tournament_entries
      set status = 'rejected'
      where id = p_entry_id and status in ('pending','confirmed','waitlisted');
  end if;

  select captain_profile_id into v_captain from public.tournament_entries where id = p_entry_id;

  if v_captain is not null and v_captain <> auth.uid() then
    insert into public.notifications(profile_id, category, type, title, body, source_type, source_id)
    values (
      v_captain, 'tournament', 'tournament_entry_invite_responded',
      case when p_accept then 'Tu compañero aceptó la invitación al torneo' else 'Tu compañero rechazó la invitación al torneo' end,
      null, 'tournament_entry', p_entry_id
    );
  end if;
end;
$function$;

grant execute on function public.respond_tournament_entry_invite(uuid, boolean) to authenticated;

-- Avisa a cada invitado (no al capitan) justo cuando se crea la inscripcion.
create or replace function public.register_tournament_entry(p_category_id uuid, p_member_profile_ids uuid[], p_registration_data jsonb DEFAULT '{}'::jsonb)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_cat public.tournament_categories;
  v_tournament public.tournaments;
  v_entry uuid;
  v_member uuid;
  v_count integer;
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
    -- >>> NUEVO: avisarle al invitado para que pueda aceptar o rechazar
    if v_member <> p_member_profile_ids[1] then
      insert into public.notifications(profile_id, category, type, title, body, source_type, source_id)
      values (
        v_member, 'tournament', 'tournament_entry_invite_received',
        'Te invitaron a un torneo', 'Alguien te anotó como compañero de equipo. Acepta o rechaza la invitación.',
        'tournament_entry', v_entry
      );
    end if;
    -- <<< fin de lo nuevo
  end loop;
  insert into public.tournament_registration_payments(entry_id,amount_due,amount_paid,currency_code,status)
  values(v_entry,coalesce(v_cat.entry_fee,v_tournament.entry_fee),0,coalesce(v_tournament.currency_code,'COP'),'unpaid');
  return v_entry;
end;
$function$;
