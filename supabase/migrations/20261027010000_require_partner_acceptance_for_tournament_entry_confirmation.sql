-- FIX PEDIDO POR LUIS (2026-10-27, "dale con todo"): hoy una pareja/equipo de torneo
-- podia quedar "confirmed" (y por lo tanto entrar al cuadro del torneo) solo porque la
-- cuota ya se pago o es gratis -- sin que el companero/a invitado hubiera aceptado la
-- invitacion. Eso permitia que un jugador entrara a un cuadro sin que su pareja real
-- hubiera dicho que si.
--
-- Se corrige en los TRES puntos donde una inscripcion (tournament_entries) puede pasar
-- a 'confirmed':
--   1) register_tournament_entry               -- inscripcion gratis (fee = 0)
--   2) confirm_tournament_registration_payment  -- pago confirmado (ledger de eventos,
--      idempotente por provider+provider_payment_id/provider_event_id; service_role only)
--   3) respond_tournament_entry_invite          -- cuando el companero acepta DESPUES de
--      que la cuota ya estaba pagada, la inscripcion debe pasar a 'confirmed' en ese
--      momento, no quedarse pegada en 'pending' para siempre
--
-- IMPORTANTE: las definiciones de abajo se tomaron tal cual estaban viviendo en
-- produccion (via pg_get_functiondef) justo antes de este cambio -- NO de
-- supabase/schema_master.sql, que para confirm_tournament_registration_payment tiene una
-- firma vieja y completamente distinta (2 argumentos) de un rework anterior (F12) que
-- nunca se reflejo en el archivo local. Solo se les agrego la condicion de "todos los
-- miembros ya confirmados" antes de marcar la inscripcion como 'confirmed'. Todo se
-- probo exhaustivamente dentro de BEGIN...ROLLBACK contra produccion antes de aplicarse
-- (torneos/categorias/inscripciones sinteticas, usando los perfiles de prueba
-- reutilizables). Las tres funciones se reemplazan con CREATE OR REPLACE y la MISMA
-- firma que ya tenian -- no se necesita ningun DROP.

CREATE OR REPLACE FUNCTION public.register_tournament_entry(p_category_id uuid, p_member_profile_ids uuid[], p_registration_data jsonb DEFAULT '{}'::jsonb)
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
  -- Antes: se confirmaba la inscripcion solo porque no se debia nada (fee = 0), sin
  -- revisar si los demas miembros (la pareja/equipo invitado) ya habian aceptado.
  -- Ahora: solo se confirma si TODOS los miembros ya estan en 'confirmed'.
  if v_amount_due=0 and not exists (
    select 1 from public.tournament_entry_members where entry_id=v_entry and status<>'confirmed'
  ) then
    update public.tournament_entries set status='confirmed', updated_at=now() where id=v_entry;
  end if;
  return v_entry;
end;
$function$;

GRANT EXECUTE ON FUNCTION public.register_tournament_entry(uuid, uuid[], jsonb) TO authenticated;

-- confirm_tournament_registration_payment: firma real de produccion (ledger de eventos,
-- idempotente por provider+provider_payment_id/provider_event_id, service_role only).
-- Solo se le agrego la condicion de "todos los miembros confirmados" al bloque que
-- promueve la inscripcion a 'confirmed' tras un pago exitoso (el resto de la funcion,
-- incluyendo las validaciones y la deteccion de sobrepago, queda igual).
CREATE OR REPLACE FUNCTION public.confirm_tournament_registration_payment(p_entry_id uuid, p_provider text, p_provider_payment_id text, p_provider_event_id text, p_amount numeric, p_currency_code text DEFAULT 'COP'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_entry public.tournament_entries;
  v_payment public.tournament_registration_payments;
  v_existing public.tournament_registration_payment_events;
  v_total numeric;
begin
  if auth.role() <> 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED';
  end if;
  if p_provider is null or length(trim(p_provider)) = 0 then
    raise exception 'INVALID_PAYMENT_PROVIDER';
  end if;
  if p_provider_payment_id is null or length(trim(p_provider_payment_id)) = 0 then
    raise exception 'INVALID_PROVIDER_PAYMENT_ID';
  end if;
  if p_provider_event_id is null or length(trim(p_provider_event_id)) = 0 then
    raise exception 'INVALID_PROVIDER_EVENT_ID';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'INVALID_PAYMENT_AMOUNT';
  end if;

  select * into v_entry from public.tournament_entries where id = p_entry_id for update;
  if not found then
    raise exception 'ENTRY_NOT_FOUND';
  end if;
  select * into v_payment from public.tournament_registration_payments where entry_id = p_entry_id for update;
  if not found then
    raise exception 'REGISTRATION_PAYMENT_NOT_FOUND';
  end if;

  select * into v_existing from public.tournament_registration_payment_events
    where provider = p_provider and provider_payment_id = p_provider_payment_id
    for update;
  if found then
    if v_existing.entry_id <> p_entry_id
       or v_existing.amount <> p_amount
       or v_existing.currency_code <> p_currency_code then
      raise exception 'PAYMENT_IDENTITY_MISMATCH';
    end if;
    return jsonb_build_object('ok', true, 'idempotent', true, 'entry_id', p_entry_id, 'status', v_payment.status, 'amount_paid', v_payment.amount_paid);
  end if;
  if exists (
    select 1 from public.tournament_registration_payment_events
    where provider = p_provider and provider_event_id = p_provider_event_id
  ) then
    raise exception 'PAYMENT_EVENT_ALREADY_USED';
  end if;

  insert into public.tournament_registration_payment_events(
    entry_id, provider, provider_payment_id, provider_event_id, amount, currency_code
  ) values (
    p_entry_id, p_provider, p_provider_payment_id, p_provider_event_id, p_amount, p_currency_code
  );

  select coalesce(sum(amount), 0) into v_total
  from public.tournament_registration_payment_events
  where entry_id = p_entry_id;

  if v_total > v_payment.amount_due then
    raise exception 'OVERPAYMENT_DETECTED';
  end if;

  update public.tournament_registration_payments
    set amount_paid = v_total,
        status = case when v_total >= amount_due then 'paid' when v_total > 0 then 'partial' else 'unpaid' end,
        paid_at = case when v_total >= amount_due then coalesce(paid_at, now()) else paid_at end,
        updated_at = now()
    where id = v_payment.id
    returning * into v_payment;

  -- Antes: al llegar a 'paid' se confirmaba la inscripcion de una, sin revisar si la
  -- pareja/equipo invitado ya habia aceptado. Ahora: solo se confirma si TODOS los
  -- miembros ya estan en 'confirmed'.
  if v_payment.status = 'paid' and not exists (
    select 1 from public.tournament_entry_members where entry_id=p_entry_id and status<>'confirmed'
  ) then
    update public.tournament_entries
      set status = case when status in ('pending','waitlisted') then 'confirmed' else status end,
          updated_at = now()
      where id = p_entry_id;
  end if;

  return jsonb_build_object('ok', true, 'idempotent', false, 'entry_id', p_entry_id, 'status', v_payment.status, 'amount_paid', v_payment.amount_paid);
end;
$function$;

GRANT EXECUTE ON FUNCTION public.confirm_tournament_registration_payment(uuid, text, text, text, numeric, text) TO service_role;

-- respond_tournament_entry_invite: (1) corrige un bug real que ya estaba viviendo en
-- produccion: escribia 'rejected' en tournament_entry_members.status al rechazar, pero
-- el CHECK constraint de esa columna (tournament_entry_members_status_check) solo
-- permite 'invited' | 'confirmed' | 'declined' | 'removed' -- cualquier rechazo real de
-- un companero de equipo hacia crashear la funcion. Ahora escribe 'declined'.
-- (2) si al aceptar ya estaban todos los demas miembros confirmados Y el pago ya estaba
-- 'paid', promueve la inscripcion a 'confirmed' en ese momento (antes se quedaba pegada
-- en 'pending' para siempre si el pago llegaba antes que la aceptacion del companero).
CREATE OR REPLACE FUNCTION public.respond_tournament_entry_invite(p_entry_id uuid, p_accept boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
    set status = case when p_accept then 'confirmed' else 'declined' end
    where entry_id = p_entry_id and profile_id = auth.uid();

  if not p_accept then
    update public.tournament_entries
      set status = 'rejected'
      where id = p_entry_id and status in ('pending','confirmed','waitlisted');
  else
    if exists (select 1 from public.tournament_registration_payments where entry_id=p_entry_id and status='paid')
       and not exists (select 1 from public.tournament_entry_members where entry_id=p_entry_id and status<>'confirmed')
    then
      update public.tournament_entries
        set status='confirmed', updated_at=now()
        where id=p_entry_id and status in ('pending','waitlisted');
    end if;
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

GRANT EXECUTE ON FUNCTION public.respond_tournament_entry_invite(uuid, boolean) TO authenticated;
