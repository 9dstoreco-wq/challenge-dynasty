-- F02 (Auditoria_Challenge_Dynasty_2026-10-12.md): "RLS de marketplace_orders bloquea al
-- comprador (deny_all)". SAFE: everything runs inside DO $$ ... RAISE EXCEPTION ... END $$
-- blocks that always roll back (confirmed after every run: no leftover rows, current_user
-- reverts to postgres). Never commits.
--
-- PART 1 verifies that F02, as literally stated, does not currently reproduce: the table
-- IS deny_all for `authenticated` (confirmed -- direct SELECT raises insufficient_privilege,
-- not just an empty RLS result), but the buyer never has to touch the raw table. A
-- SECURITY DEFINER RPC pair already exists (get_my_marketplace_orders /
-- get_my_marketplace_order_items), owned by "postgres" (rolbypassrls=true -- confirmed via
-- pg_roles, not assumed), correctly scoped by buyer_id/seller join, with EXECUTE already
-- granted to `authenticated` (confirmed via information_schema.routine_privileges). This is
-- exactly what app/marketplace/orders/page.tsx and orders/[id]/page.tsx already call. None
-- of this is represented in any local migration file under supabase/migrations/ (grep
-- confirms zero matches) -- it only exists live on the database, consistent with F10's
-- finding of drift between 278 registered migrations and 27 local files. The audit's
-- static read of the deny_all policy, without checking for a compensating RPC, produced a
-- false positive here.
--
-- PART 2 verifies a real, separate bug found while checking F02's surrounding functions:
-- advance_marketplace_order_status() referenced a nonexistent table
-- (public.marketplace_payment_refunds) and a nonexistent column (order_id on refunds) --
-- every refund/partial-refund transition failed outright. See
-- 20261013192000_fix_marketplace_refund_transition_table_ref.sql for the fix this verifies.
--
-- Needs >=3 profiles and >=1 sport in the database (uses the oldest). Simulates the buyer,
-- the seller and an unrelated third profile by switching SET LOCAL ROLE / request.jwt.claims
-- mid-transaction, the same way PostgREST does per request.
do $$
declare
  v_owner_a uuid; v_owner_b uuid; v_outsider uuid; v_sport uuid;
  v_seller_profile uuid; v_listing uuid; v_order_id uuid;
  v_raw_count int; v_own_orders int; v_own_items int;
  v_seller_items int; v_outsider_orders int; v_outsider_items int;
  res text := ''; fails int := 0;
  v_denied boolean := false;
begin
  select id into v_owner_a from public.profiles order by created_at limit 1;
  select id into v_owner_b from public.profiles order by created_at offset 1 limit 1;
  select id into v_outsider from public.profiles order by created_at offset 2 limit 1;
  select id into v_sport from public.sports order by name limit 1;
  if v_owner_a is null or v_owner_b is null or v_outsider is null or v_sport is null then
    raise exception 'se necesitan >=3 profiles y >=1 sport';
  end if;

  insert into public.marketplace_seller_profiles(owner_id, display_name, seller_type)
    values (v_owner_a, 'F02 test seller', 'individual') returning id into v_seller_profile;

  insert into public.marketplace_listings(owner_id, seller_id, listing_type, title, price, currency_code, status, audience_scope, location_scope)
    values (v_owner_a, v_seller_profile, 'other', 'F02 test listing', 10000, 'COP', 'published', 'universal', 'online')
    returning id into v_listing;

  insert into public.marketplace_listing_inventory(listing_id, quantity_available)
    values (v_listing, 5);

  -- act as the buyer (owner_b): this is exactly what checkout does client-side
  execute format('set local role authenticated');
  execute format('set local request.jwt.claims = %L', json_build_object('sub', v_owner_b, 'role','authenticated')::text);

  select public.create_marketplace_order(
    jsonb_build_array(jsonb_build_object('listing_id', v_listing, 'quantity', 1)),
    0
  ) into v_order_id;
  if v_order_id is not null then
    res := res || E'OK    01 create_marketplace_order funciona para un comprador autenticado via RPC\n';
  else
    res := res || E'FALLO 01: create_marketplace_order no devolvio id\n'; fails:=fails+1;
  end if;

  select count(*) into v_own_orders from public.get_my_marketplace_orders() o where o.id = v_order_id;
  if v_own_orders = 1 then
    res := res || E'OK    02 el comprador ve su propia orden via get_my_marketplace_orders()\n';
  else
    res := res || format(E'FALLO 02: el comprador deberia ver 1 orden, vio %s\n', v_own_orders); fails:=fails+1;
  end if;

  select count(*) into v_own_items from public.get_my_marketplace_order_items(v_order_id);
  if v_own_items = 1 then
    res := res || E'OK    03 el comprador ve sus items via get_my_marketplace_order_items()\n';
  else
    res := res || format(E'FALLO 03: el comprador deberia ver 1 item, vio %s\n', v_own_items); fails:=fails+1;
  end if;

  begin
    execute 'select count(*) from public.marketplace_orders' into v_raw_count;
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if v_denied or v_raw_count = 0 then
    res := res || E'OK    04 el acceso directo a la tabla cruda marketplace_orders esta bloqueado para authenticated (permiso denegado o 0 filas) -- el RPC es obligatorio por diseno\n';
  else
    res := res || format(E'FALLO 04: select directo deberia estar bloqueado, devolvio %s filas\n', v_raw_count); fails:=fails+1;
  end if;

  execute format('set local request.jwt.claims = %L', json_build_object('sub', v_owner_a, 'role','authenticated')::text);
  select count(*) into v_seller_items from public.get_my_marketplace_order_items(v_order_id);
  if v_seller_items = 1 then
    res := res || E'OK    05 el vendedor tambien ve el item de su propia venta via el mismo RPC (join por seller_profiles)\n';
  else
    res := res || format(E'FALLO 05: el vendedor deberia ver 1 item, vio %s\n', v_seller_items); fails:=fails+1;
  end if;

  execute format('set local request.jwt.claims = %L', json_build_object('sub', v_outsider, 'role','authenticated')::text);
  select count(*) into v_outsider_orders from public.get_my_marketplace_orders() o where o.id = v_order_id;
  select count(*) into v_outsider_items from public.get_my_marketplace_order_items(v_order_id);
  if v_outsider_orders = 0 and v_outsider_items = 0 then
    res := res || E'OK    06 un tercero sin relacion no ve ni la orden ni los items (aislamiento correcto)\n';
  else
    res := res || format(E'FALLO 06: tercero vio orders=%s items=%s (esperado 0 y 0)\n', v_outsider_orders, v_outsider_items); fails:=fails+1;
  end if;

  raise exception E'RESULTADOS F02 parte 1 (% fallos)\n%', fails, res;
end $$;

-- PART 2: advance_marketplace_order_status() fix (separate DO block/transaction -- part 1
-- already rolled back on its own RAISE EXCEPTION above; run this one after it).
do $$
declare
  v_owner_a uuid; v_owner_b uuid;
  v_order1 uuid; v_order2 uuid; v_payment1 uuid; v_payment2 uuid;
  res text := ''; fails int := 0;
  v_ok boolean;
  v_caught text;
begin
  select id into v_owner_a from public.profiles order by created_at limit 1;
  select id into v_owner_b from public.profiles order by created_at offset 1 limit 1;
  if v_owner_a is null or v_owner_b is null then
    raise exception 'se necesitan >=2 profiles';
  end if;

  execute $FN$
    create or replace function public.advance_marketplace_order_status(p_order_id uuid, p_next_status text)
    returns boolean
    language plpgsql
    security definer
    set search_path to 'public', 'pg_temp'
    as $function$
    declare v_status text; v_total numeric; v_refunded numeric;
    begin
     if auth.role()<>'service_role' then raise exception 'service_role_required'; end if;
     if p_next_status not in ('fulfilled','refunded','partially_refunded') then raise exception 'invalid_state_transition'; end if;
     select status,total_amount into v_status,v_total from public.marketplace_orders where id=p_order_id for update;
     if not found then raise exception 'order_not_found'; end if;
     if v_status='paid' and p_next_status='fulfilled' then
       update public.marketplace_orders set status='fulfilled',updated_at=now() where id=p_order_id;
       return true;
     end if;
     if v_status='fulfilled' and p_next_status in ('refunded','partially_refunded') then
       select coalesce(sum(r.amount),0) into v_refunded
       from public.marketplace_order_refunds r
       join public.marketplace_order_payments pay on pay.id = r.payment_id
       where pay.order_id = p_order_id and r.status='succeeded';
       if p_next_status='refunded' and v_refunded<>v_total then raise exception 'REFUND_TOTAL_MISMATCH'; end if;
       if p_next_status='partially_refunded' and (v_refunded<=0 or v_refunded>=v_total) then raise exception 'PARTIAL_REFUND_AMOUNT_INVALID'; end if;
       update public.marketplace_orders set status=p_next_status,updated_at=now() where id=p_order_id;
       return true;
     end if;
     raise exception 'invalid_state_transition';
    end; $function$;
  $FN$;

  insert into public.marketplace_orders(buyer_id, currency_code, subtotal, delivery_amount, platform_fee, total_amount, status)
    values (v_owner_b, 'COP', 100000, 0, 5000, 100000, 'fulfilled') returning id into v_order1;
  insert into public.marketplace_order_payments(order_id, provider, provider_payment_id, amount, currency_code, status)
    values (v_order1, 'wompi', 'f02b-test-pay-1', 100000, 'COP', 'paid') returning id into v_payment1;
  insert into public.marketplace_order_refunds(payment_id, amount, status, provider_refund_id)
    values (v_payment1, 100000, 'succeeded', 'f02b-refund-1');

  execute format('set local role service_role');
  execute format('set local request.jwt.claims = %L', json_build_object('role','service_role')::text);

  select public.advance_marketplace_order_status(v_order1, 'refunded') into v_ok;
  if v_ok then
    res := res || E'OK    01 advance_marketplace_order_status(refunded) funciona con la tabla/columna corregidas (marketplace_order_refunds via payment_id->order_payments.order_id)\n';
  else
    res := res || E'FALLO 01: no devolvio true\n'; fails:=fails+1;
  end if;

  insert into public.marketplace_orders(buyer_id, currency_code, subtotal, delivery_amount, platform_fee, total_amount, status)
    values (v_owner_b, 'COP', 50000, 0, 2500, 50000, 'fulfilled') returning id into v_order2;
  insert into public.marketplace_order_payments(order_id, provider, provider_payment_id, amount, currency_code, status)
    values (v_order2, 'wompi', 'f02b-test-pay-2', 50000, 'COP', 'paid') returning id into v_payment2;
  insert into public.marketplace_order_refunds(payment_id, amount, status, provider_refund_id)
    values (v_payment2, 10000, 'succeeded', 'f02b-refund-2');

  begin
    perform public.advance_marketplace_order_status(v_order2, 'refunded');
    v_caught := 'no_exception';
  exception when others then
    v_caught := sqlerrm;
  end;
  if v_caught = 'REFUND_TOTAL_MISMATCH' then
    res := res || E'OK    02 un reembolso parcial sigue siendo rechazado para la transicion a refunded total (REFUND_TOTAL_MISMATCH)\n';
  else
    res := res || format(E'FALLO 02: se esperaba REFUND_TOTAL_MISMATCH, se obtuvo %s\n', v_caught); fails:=fails+1;
  end if;

  raise exception E'RESULTADOS F02 parte 2 / refund-transition-fix (% fallos)\n%', fails, res;
end $$;
