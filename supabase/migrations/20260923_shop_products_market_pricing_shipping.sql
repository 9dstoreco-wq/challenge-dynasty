-- Dynasty Shop: product catalog management (currently impossible -- no RLS write
-- policy and no RPC exists for shop_products at all, so nobody, including the
-- owner, can add a product through the app today), plus per-country market
-- pricing and a real shipping cost calculation at checkout (shipping_amount is
-- currently hardcoded to 0 in checkout_shop_cart).
--
-- IMPORTANT: Wompi (the only payment processor connected today) settles in COP
-- only. All amounts below (base_price, market prices, shipping costs) are
-- stored and charged in COP. A market_price row in another currency is a
-- DISPLAY price for that market only -- actually charging a customer in USD
-- (or any non-COP currency) requires a second payment processor such as
-- Stripe, which is not connected yet.

-- ============================================================
-- 1. Extend the permission matrix: product catalog management
--    (owner/manager only, same as staff/register management)
-- ============================================================
create or replace function public.has_shop_permission(p_location_id uuid, p_permission text, p_profile_id uuid DEFAULT auth.uid())
returns boolean
language sql
stable security definer
set search_path to 'public', 'pg_temp'
as $$
  select exists (
    select 1 from public.shop_staff ss
    where ss.location_id=p_location_id
      and ss.profile_id = case when auth.role()='service_role' then p_profile_id else auth.uid() end
      and ss.status='active'
      and case p_permission
        when 'sell' then ss.role in ('owner','manager','cashier')
        when 'manage_register' then ss.role in ('owner','manager')
        when 'manage_inventory' then ss.role in ('owner','manager','inventory')
        when 'manage_staff' then ss.role in ('owner','manager')
        when 'manage_products' then ss.role in ('owner','manager')
        when 'view_reports' then ss.role in ('owner','manager','inventory')
        else false
      end
  );
$$;

-- Small helper: the one online location's id, used by every product/shipping
-- RPC below to check permission (mirrors checkout_shop_cart's own lookup).
create or replace function public.get_shop_online_location_id()
returns uuid
language sql
stable security definer
set search_path to 'public', 'pg_temp'
as $$
  select id from public.shop_locations where code = 'ONLINE' and status = 'active' limit 1;
$$;

revoke all on function public.get_shop_online_location_id() from public;
grant execute on function public.get_shop_online_location_id() to authenticated;

-- ============================================================
-- 2. Product + variant management RPCs
-- ============================================================
create or replace function public.create_shop_product(
  p_slug text, p_title text, p_description text, p_base_price numeric,
  p_currency_code text default 'COP', p_product_type text default 'merchandise',
  p_image_url text default null
)
returns public.shop_products
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_location uuid := public.get_shop_online_location_id();
  v_product public.shop_products;
begin
  if v_location is null or not public.has_shop_permission(v_location, 'manage_products') then
    raise exception 'SHOP_PERMISSION_DENIED';
  end if;
  if p_base_price is null or p_base_price < 0 then raise exception 'INVALID_PRICE'; end if;

  insert into public.shop_products (slug, title, description, product_type, status, base_price, currency_code, metadata)
  values (p_slug, p_title, p_description, coalesce(p_product_type, 'merchandise'), 'draft', p_base_price, coalesce(p_currency_code, 'COP'),
    case when p_image_url is not null then jsonb_build_object('image_url', p_image_url) else '{}'::jsonb end)
  returning * into v_product;

  return v_product;
end;
$function$;

revoke all on function public.create_shop_product(text, text, text, numeric, text, text, text) from public;
grant execute on function public.create_shop_product(text, text, text, numeric, text, text, text) to authenticated;

create or replace function public.update_shop_product(
  p_product_id uuid, p_title text, p_description text, p_base_price numeric,
  p_currency_code text, p_status text, p_image_url text
)
returns public.shop_products
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_location uuid := public.get_shop_online_location_id();
  v_product public.shop_products;
begin
  if v_location is null or not public.has_shop_permission(v_location, 'manage_products') then
    raise exception 'SHOP_PERMISSION_DENIED';
  end if;
  if p_status is not null and p_status not in ('draft','active','archived') then raise exception 'INVALID_STATUS'; end if;

  update public.shop_products set
    title = coalesce(p_title, title),
    description = coalesce(p_description, description),
    base_price = coalesce(p_base_price, base_price),
    currency_code = coalesce(p_currency_code, currency_code),
    status = coalesce(p_status, status),
    metadata = case when p_image_url is not null then metadata || jsonb_build_object('image_url', p_image_url) else metadata end,
    updated_at = now()
  where id = p_product_id
  returning * into v_product;

  if not found then raise exception 'PRODUCT_NOT_FOUND'; end if;
  return v_product;
end;
$function$;

revoke all on function public.update_shop_product(uuid, text, text, numeric, text, text, text) from public;
grant execute on function public.update_shop_product(uuid, text, text, numeric, text, text, text) to authenticated;

create or replace function public.list_my_shop_products()
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_location uuid := public.get_shop_online_location_id();
  v_result jsonb;
begin
  if v_location is null or not public.has_shop_permission(v_location, 'manage_products') then
    raise exception 'SHOP_PERMISSION_DENIED';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id, 'slug', p.slug, 'title', p.title, 'description', p.description,
    'status', p.status, 'base_price', p.base_price, 'currency_code', p.currency_code,
    'image_url', p.metadata->>'image_url', 'created_at', p.created_at
  ) order by p.created_at desc), '[]'::jsonb)
  into v_result
  from public.shop_products p;

  return v_result;
end;
$function$;

revoke all on function public.list_my_shop_products() from public;
grant execute on function public.list_my_shop_products() to authenticated;

create or replace function public.add_shop_product_variant(
  p_product_id uuid, p_title text, p_sku text, p_price numeric, p_stock_quantity integer, p_attributes jsonb default '{}'::jsonb
)
returns public.shop_product_variants
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_location uuid := public.get_shop_online_location_id();
  v_variant public.shop_product_variants;
begin
  if v_location is null or not public.has_shop_permission(v_location, 'manage_products') then
    raise exception 'SHOP_PERMISSION_DENIED';
  end if;

  insert into public.shop_product_variants (product_id, title, sku, price, stock_quantity, attributes)
  values (p_product_id, p_title, p_sku, p_price, coalesce(p_stock_quantity, 0), coalesce(p_attributes, '{}'::jsonb))
  returning * into v_variant;

  insert into public.shop_inventory_levels (location_id, variant_id, stock_quantity)
  values (v_location, v_variant.id, coalesce(p_stock_quantity, 0))
  on conflict do nothing;

  return v_variant;
end;
$function$;

revoke all on function public.add_shop_product_variant(uuid, text, text, numeric, integer, jsonb) from public;
grant execute on function public.add_shop_product_variant(uuid, text, text, numeric, integer, jsonb) to authenticated;

-- ============================================================
-- 3. Per-country market price overrides (display prices for other
--    markets; actual charge still happens in COP via Wompi until a
--    second, non-COP payment processor is connected)
-- ============================================================
create table if not exists public.shop_product_market_prices (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.shop_products(id) on delete cascade,
  country_code text not null,
  currency_code text not null,
  price numeric not null check (price >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, country_code)
);

alter table public.shop_product_market_prices enable row level security;

drop policy if exists "shop_product_market_prices public read" on public.shop_product_market_prices;
create policy "shop_product_market_prices public read"
  on public.shop_product_market_prices for select
  to anon, authenticated
  using (true);

create or replace function public.set_shop_product_market_price(
  p_product_id uuid, p_country_code text, p_currency_code text, p_price numeric
)
returns public.shop_product_market_prices
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_location uuid := public.get_shop_online_location_id();
  v_row public.shop_product_market_prices;
begin
  if v_location is null or not public.has_shop_permission(v_location, 'manage_products') then
    raise exception 'SHOP_PERMISSION_DENIED';
  end if;
  if p_price is null or p_price < 0 then raise exception 'INVALID_PRICE'; end if;

  insert into public.shop_product_market_prices (product_id, country_code, currency_code, price)
  values (p_product_id, upper(p_country_code), upper(p_currency_code), p_price)
  on conflict (product_id, country_code)
  do update set currency_code = excluded.currency_code, price = excluded.price, updated_at = now()
  returning * into v_row;

  return v_row;
end;
$function$;

revoke all on function public.set_shop_product_market_price(uuid, text, text, numeric) from public;
grant execute on function public.set_shop_product_market_price(uuid, text, text, numeric) to authenticated;

-- ============================================================
-- 4. Shipping rules per destination country + free/discounted
--    threshold, and a real shipping_amount at checkout (was
--    always hardcoded to 0)
-- ============================================================
create table if not exists public.shop_shipping_rules (
  id uuid primary key default gen_random_uuid(),
  country_code text not null unique, -- 'CO' domestic, '*' = rest-of-world default
  currency_code text not null default 'COP',
  standard_cost numeric not null check (standard_cost >= 0),
  free_threshold numeric, -- order subtotal at/above which discounted_cost applies (null = no discount tier)
  discounted_cost numeric check (discounted_cost is null or discounted_cost >= 0),
  updated_at timestamptz not null default now()
);

alter table public.shop_shipping_rules enable row level security;

drop policy if exists "shop_shipping_rules public read" on public.shop_shipping_rules;
create policy "shop_shipping_rules public read"
  on public.shop_shipping_rules for select
  to anon, authenticated
  using (true);

create or replace function public.set_shop_shipping_rule(
  p_country_code text, p_currency_code text, p_standard_cost numeric, p_free_threshold numeric, p_discounted_cost numeric
)
returns public.shop_shipping_rules
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_location uuid := public.get_shop_online_location_id();
  v_row public.shop_shipping_rules;
begin
  if v_location is null or not public.has_shop_permission(v_location, 'manage_products') then
    raise exception 'SHOP_PERMISSION_DENIED';
  end if;

  insert into public.shop_shipping_rules (country_code, currency_code, standard_cost, free_threshold, discounted_cost)
  values (upper(p_country_code), coalesce(p_currency_code, 'COP'), p_standard_cost, p_free_threshold, p_discounted_cost)
  on conflict (country_code)
  do update set currency_code = excluded.currency_code, standard_cost = excluded.standard_cost,
    free_threshold = excluded.free_threshold, discounted_cost = excluded.discounted_cost, updated_at = now()
  returning * into v_row;

  return v_row;
end;
$function$;

revoke all on function public.set_shop_shipping_rule(text, text, numeric, numeric, numeric) from public;
grant execute on function public.set_shop_shipping_rule(text, text, numeric, numeric, numeric) to authenticated;

-- Seed a sensible starting point: free-ish domestic shipping in Colombia above
-- 150,000 COP, and an international rule matching the real carrier research
-- (4-72 is the cheapest international option at ~190,000 COP / ~$47 USD)
-- discounted above an ~800,000 COP (~200 USD) order, matching what the owner
-- proposed.
insert into public.shop_shipping_rules (country_code, currency_code, standard_cost, free_threshold, discounted_cost)
values
  ('CO', 'COP', 12000, 150000, 0),
  ('*', 'COP', 250000, 800000, 190000)
on conflict (country_code) do nothing;

-- ============================================================
-- 5. Wire real shipping into checkout (was hardcoded to 0)
-- ============================================================
create or replace function public.checkout_shop_cart(p_shipping_data jsonb DEFAULT '{}'::jsonb)
 RETURNS shop_orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_user uuid:=auth.uid(); v_cart public.shop_carts; v_order public.shop_orders; v_item record; v_subtotal numeric:=0; v_online_location uuid;
  v_dest_country text; v_rule public.shop_shipping_rules; v_shipping numeric := 0;
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

  -- Real shipping cost: destination country from p_shipping_data, falling back
  -- to the '*' rest-of-world rule, falling back to 0 if nothing is configured.
  v_dest_country := upper(coalesce(p_shipping_data->>'country_code', 'CO'));
  select * into v_rule from public.shop_shipping_rules where country_code = v_dest_country;
  if not found then
    select * into v_rule from public.shop_shipping_rules where country_code = '*';
  end if;
  if found then
    if v_rule.free_threshold is not null and v_subtotal >= v_rule.free_threshold then
      v_shipping := coalesce(v_rule.discounted_cost, 0);
    else
      v_shipping := v_rule.standard_cost;
    end if;
  end if;

  insert into public.shop_orders(profile_id,status,currency_code,subtotal,discount_amount,shipping_amount,total_amount,shipping_data,fulfillment_status,payment_status)
  values(v_user,'payment_pending',v_cart.currency_code,v_subtotal,0,v_shipping,v_subtotal+v_shipping,coalesce(p_shipping_data,'{}'::jsonb),'unfulfilled','pending') returning * into v_order;
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
