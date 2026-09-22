-- Fixes a guaranteed runtime crash in checkout_shop_cart, found during the
-- second global sweep for the obsolete/mismatched-literal bug class
-- (2026-09-21).
--
-- EVIDENCE (live DB, project ggkthvewxmsmtupjzfnk):
--   information_schema.columns for shop_cart_items: id, cart_id, product_id,
--   variant_id, quantity, created_at, updated_at -- there is NO status column
--   on this table (confirmed: no shop_cart_items_status_check constraint
--   exists either; the only status-bearing cart table is shop_carts, whose
--   status is a different, UPPERCASE enum: ACTIVE/CHECKOUT/CONVERTED/
--   ABANDONED).
--
-- checkout_shop_cart's validation loop selects `ci.*` (shop_cart_items,
-- which has no status field) plus product/variant fields, then evaluates:
--   if v_item.status<>'ACTIVE' then raise exception 'PRODUCT_NOT_AVAILABLE'; end if;
-- `v_item` is a plpgsql RECORD with no `status` field at all, so this line
-- raises `record "v_item" has no field "status"` the moment ANY row reaches
-- it -- i.e. on every checkout attempt where the cart has at least one item.
-- CREATE OR REPLACE succeeds because plpgsql does not type-check record
-- field access until the loop actually executes, which is why this shipped
-- and stayed live undetected: the online checkout flow (shop/cart ->
-- checkout_shop_cart RPC) is completely broken for any non-empty cart.
--
-- The evident intent was to gate on the PRODUCT's status (shop_products,
-- lowercase enum draft/active/archived per shop_products_status_check), not
-- the cart's. Fix: select p.status alongside the existing product/variant
-- fields and compare against the correct lowercase value. No other logic
-- changes.

CREATE OR REPLACE FUNCTION public.checkout_shop_cart(p_shipping_data jsonb DEFAULT '{}'::jsonb)
 RETURNS shop_orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_user uuid:=auth.uid(); v_cart public.shop_carts; v_order public.shop_orders; v_item record; v_subtotal numeric:=0; v_online_location uuid;
begin
  if v_user is null then raise exception 'AUTH_REQUIRED'; end if;
  select id into v_online_location from public.shop_locations where code='ONLINE' and status='active' limit 1;
  if v_online_location is null then raise exception 'ONLINE_LOCATION_NOT_CONFIGURED'; end if;
  select * into v_cart from public.shop_carts where profile_id=v_user and status='ACTIVE' order by updated_at desc limit 1 for update;
  if not found then raise exception 'NO_ACTIVE_CART'; end if;
  if not exists(select 1 from public.shop_cart_items where cart_id=v_cart.id) then raise exception 'CART_EMPTY'; end if;
  update public.shop_carts set status='CHECKOUT',updated_at=now() where id=v_cart.id;
  for v_item in
    select ci.*,p.title product_title,p.status product_status,coalesce(v.title,'Default') variant_title,coalesce(v.price,p.base_price) unit_price,coalesce(v.is_active,true) variant_active
    from public.shop_cart_items ci join public.shop_products p on p.id=ci.product_id left join public.shop_product_variants v on v.id=ci.variant_id where ci.cart_id=v_cart.id order by ci.id
  loop
    if v_item.product_status<>'active' then raise exception 'PRODUCT_NOT_AVAILABLE'; end if;
    if not v_item.variant_active then raise exception 'VARIANT_NOT_AVAILABLE'; end if;
    if v_item.variant_id is not null then
      insert into public.shop_inventory_levels(location_id,variant_id,stock_quantity) values(v_online_location,v_item.variant_id,0) on conflict do nothing;
      perform 1 from public.shop_inventory_levels il where il.location_id=v_online_location and il.variant_id=v_item.variant_id and il.stock_quantity-il.reserved_quantity>=v_item.quantity for update;
      if not found then raise exception 'ONLINE_STOCK_INSUFFICIENT'; end if;
    end if;
    v_subtotal:=v_subtotal+(v_item.unit_price*v_item.quantity);
  end loop;
  insert into public.shop_orders(profile_id,status,currency_code,subtotal,discount_amount,shipping_amount,total_amount,shipping_data,fulfillment_status,payment_status)
  values(v_user,'payment_pending',v_cart.currency_code,v_subtotal,0,0,v_subtotal,coalesce(p_shipping_data,'{}'::jsonb),'unfulfilled','pending') returning * into v_order;
  for v_item in select ci.*,p.title product_title,coalesce(v.title,'Default') variant_title,coalesce(v.price,p.base_price) unit_price from public.shop_cart_items ci join public.shop_products p on p.id=ci.product_id left join public.shop_product_variants v on v.id=ci.variant_id where ci.cart_id=v_cart.id order by ci.id loop
    insert into public.shop_order_items(order_id,product_id,variant_id,product_title,variant_title,quantity,unit_price,line_total) values(v_order.id,v_item.product_id,v_item.variant_id,v_item.product_title,v_item.variant_title,v_item.quantity,v_item.unit_price,v_item.unit_price*v_item.quantity);
    if v_item.variant_id is not null then
      update public.shop_inventory_levels set reserved_quantity=reserved_quantity+v_item.quantity,updated_at=now() where location_id=v_online_location and variant_id=v_item.variant_id and stock_quantity-reserved_quantity>=v_item.quantity;
      if not found then raise exception 'ONLINE_STOCK_CHANGED'; end if;
      insert into public.shop_inventory_reservations(order_id,variant_id,location_id,quantity,expires_at) values(v_order.id,v_item.variant_id,v_online_location,v_item.quantity,now()+interval '15 minutes');
    end if;
  end loop;
  update public.shop_carts set status='CONVERTED',updated_at=now() where id=v_cart.id;
  delete from public.shop_cart_items where cart_id=v_cart.id;
  return v_order;
exception when others then
  if v_cart.id is not null then update public.shop_carts set status='ACTIVE',updated_at=now() where id=v_cart.id; end if;
  raise;
end; $function$;
