-- Fixes two live bugs found in a full code<->DB contract audit (2026-09-21),
-- same root-cause class as the player_sports_relationship_check incident:
-- application-side (here: SECURITY DEFINER function) code wrote a literal
-- that does not match the live CHECK constraint's allowed values because of
-- a case mismatch. The constraints themselves are correct and are NOT
-- modified here; only the two function bodies are corrected.
--
-- NOTE: this migration could not be applied automatically from this session
-- (writing to the production database was blocked by policy). Apply it
-- manually via the Supabase SQL editor or `supabase db push` before/along
-- with this code release.
--
-- 1) create_physical_shop_sale: always inserted
--    shop_inventory_movements.movement_type = 'SALE', but
--    shop_inventory_movements_movement_type_check only allows the lowercase
--    set ('sale','purchase',...). Every physical POS sale therefore failed
--    with a check-constraint violation. Also: the shop_orders row created
--    for a physical sale never set sales_channel, so it silently defaulted
--    to 'online', misclassifying physical sales in reporting.
--
-- 2) upsert_shop_cart_item: for a cart item with no variant (plain
--    product_id only), it compared shop_products.status = 'ACTIVE', but
--    shop_products_status_check only allows the lowercase set
--    ('draft','active','archived'). Every attempt to add a variant-less
--    product to the cart therefore always failed with PRODUCT_NOT_AVAILABLE,
--    even for genuinely active products. (Currently unreachable from the
--    wired UI, which always supplies a variant, but the RPC is exposed to
--    any authenticated client and must be correct on its own.)

CREATE OR REPLACE FUNCTION public.create_physical_shop_sale(p_location_id uuid, p_register_id uuid, p_customer_id uuid, p_items jsonb, p_payment_method text, p_notes text DEFAULT NULL::text, p_tax_amount numeric DEFAULT 0, p_discount_amount numeric DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_sale public.shop_pos_sales;
  v_order public.shop_orders;
  v_item jsonb;
  v_variant uuid;
  v_qty int;
  v_product uuid;
  v_price numeric;
  v_stock int;
  v_title text;
  v_variant_title text;
  v_subtotal numeric := 0;
  v_total numeric;
  v_customer uuid;
  v_invoice_id uuid;
  v_location_type text;
  v_register public.shop_pos_registers;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)=0 then raise exception 'ITEMS_REQUIRED'; end if;
  if coalesce(p_tax_amount,0) < 0 or coalesce(p_discount_amount,0) < 0 then raise exception 'INVALID_ADJUSTMENT'; end if;

  select location_type into v_location_type
  from public.shop_locations
  where id=p_location_id and status='active';
  if v_location_type is null then raise exception 'LOCATION_NOT_FOUND'; end if;
  if v_location_type <> 'physical' then raise exception 'POS_REQUIRES_PHYSICAL_LOCATION'; end if;

  select * into v_register
  from public.shop_pos_registers
  where id=p_register_id and location_id=p_location_id and status='open'
  for update;
  if not found then raise exception 'REGISTER_NOT_OPEN'; end if;

  if p_customer_id is not null then
    perform 1 from public.shop_customers where id=p_customer_id;
    if not found then raise exception 'CUSTOMER_NOT_FOUND'; end if;
    v_customer := p_customer_id;
  end if;

  insert into public.shop_orders(profile_id,status,currency_code,subtotal,discount_amount,shipping_amount,total_amount,shipping_data,fulfillment_status,payment_status,sales_channel)
  values(null,'paid','COP',0,greatest(coalesce(p_discount_amount,0),0),0,0,jsonb_build_object('channel','PHYSICAL','location_id',p_location_id),'delivered','paid','physical')
  returning * into v_order;

  insert into public.shop_pos_sales(order_id,location_id,register_id,customer_id,seller_profile_id,sale_channel,subtotal,discount_amount,tax_amount,total_amount,payment_method,status,created_by,channel_location_id)
  values(v_order.id,p_location_id,p_register_id,v_customer,null,'physical',0,greatest(coalesce(p_discount_amount,0),0),greatest(coalesce(p_tax_amount,0),0),0,p_payment_method,'completed',auth.uid(),p_location_id)
  returning * into v_sale;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_variant := (v_item->>'variant_id')::uuid;
    v_qty := greatest((v_item->>'quantity')::int,1);
    select pv.product_id,pv.price,pv.title,p.title into v_product,v_price,v_variant_title,v_title
    from public.shop_product_variants pv
    join public.shop_products p on p.id=pv.product_id
    where pv.id=v_variant and pv.is_active=true and lower(p.status)='active'
    for update;
    if not found then raise exception 'VARIANT_NOT_AVAILABLE'; end if;

    insert into public.shop_inventory_levels(location_id,variant_id,stock_quantity)
    values(p_location_id,v_variant,0)
    on conflict do nothing;

    select stock_quantity into v_stock
    from public.shop_inventory_levels
    where location_id=p_location_id and variant_id=v_variant
    for update;
    if v_stock < v_qty then raise exception 'INSUFFICIENT_LOCATION_STOCK'; end if;

    insert into public.shop_pos_sale_items(sale_id,product_id,variant_id,product_title,variant_title,quantity,unit_price,line_total)
    values(v_sale.id,v_product,v_variant,v_title,v_variant_title,v_qty,v_price,v_price*v_qty);

    insert into public.shop_order_items(order_id,product_id,variant_id,product_title,variant_title,quantity,unit_price,line_total)
    values(v_order.id,v_product,v_variant,v_title,v_variant_title,v_qty,v_price,v_price*v_qty);

    v_subtotal := v_subtotal + v_price*v_qty;

    update public.shop_inventory_levels
    set stock_quantity=stock_quantity-v_qty,updated_at=now()
    where location_id=p_location_id and variant_id=v_variant;

    insert into public.shop_inventory_movements(location_id,variant_id,movement_type,quantity,source_type,source_id,created_by,notes)
    values(p_location_id,v_variant,'sale',-v_qty,'POS_SALE',v_sale.id,auth.uid(),p_notes);
  end loop;

  v_total := greatest(0,v_subtotal-greatest(coalesce(p_discount_amount,0),0)+greatest(coalesce(p_tax_amount,0),0));

  update public.shop_pos_sales set subtotal=v_subtotal,total_amount=v_total where id=v_sale.id;
  update public.shop_orders set subtotal=v_subtotal,total_amount=v_total where id=v_order.id;
  insert into public.shop_pos_payments(sale_id,payment_method,amount)
  values(v_sale.id,p_payment_method,v_total);

  insert into public.shop_invoices(order_id,customer_id,status,subtotal,tax_amount,discount_amount,total_amount,currency_code,issued_at)
  values(v_order.id,v_customer,'issued',v_subtotal,greatest(coalesce(p_tax_amount,0),0),greatest(coalesce(p_discount_amount,0),0),v_total,'COP',now())
  returning id into v_invoice_id;

  update public.shop_pos_sales set invoice_id=v_invoice_id where id=v_sale.id;

  return jsonb_build_object('ok',true,'sale_id',v_sale.id,'order_id',v_order.id,'invoice_id',v_invoice_id,'total_amount',v_total,'location_id',p_location_id,'register_id',p_register_id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.upsert_shop_cart_item(p_product_id uuid, p_variant_id uuid, p_quantity integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_cart uuid;
  v_item uuid;
  v_active boolean;
  v_stock integer;
  v_reserved integer;
  v_online uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_quantity < 1 or p_quantity > 100 then raise exception 'INVALID_QUANTITY'; end if;
  v_online := (select id from public.shop_locations where code='ONLINE' and status='active' limit 1);
  if v_online is null then raise exception 'ONLINE_LOCATION_NOT_CONFIGURED'; end if;
  v_cart := public.get_or_create_shop_cart();
  if p_variant_id is not null then
    select pv.is_active,p.stock_quantity into v_active,v_stock
    from public.shop_product_variants pv
    join public.shop_products p on p.id=pv.product_id
    where pv.id=p_variant_id and pv.product_id=p_product_id;
    if not found then raise exception 'VARIANT_NOT_FOUND'; end if;
    if not coalesce(v_active,false) then raise exception 'PRODUCT_NOT_AVAILABLE'; end if;
    insert into public.shop_inventory_levels(location_id,variant_id,stock_quantity)
    values(v_online,p_variant_id,0) on conflict do nothing;
    select il.stock_quantity,il.reserved_quantity into v_stock,v_reserved
    from public.shop_inventory_levels il
    where il.location_id=v_online and il.variant_id=p_variant_id
    for update;
    if coalesce(v_stock,0)-coalesce(v_reserved,0) < p_quantity then raise exception 'ONLINE_STOCK_INSUFFICIENT'; end if;
  else
    select (status='active') into v_active from public.shop_products where id=p_product_id;
    if not found or not v_active then raise exception 'PRODUCT_NOT_AVAILABLE'; end if;
  end if;
  insert into public.shop_cart_items(cart_id,product_id,variant_id,quantity)
  values(v_cart,p_product_id,p_variant_id,p_quantity)
  on conflict(cart_id,product_id,variant_id)
  do update set quantity=excluded.quantity,updated_at=now()
  returning id into v_item;
  update public.shop_carts set updated_at=now() where id=v_cart;
  return v_item;
end;
$function$;
