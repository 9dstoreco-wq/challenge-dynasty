-- Challenge Dynasty -- arregla una compra del marketplace que esta rota en produccion.
-- ESTADO: ESCRITA, NO APLICADA. El sistema de permisos bloqueo aplicarla desde Claude
-- porque es un deploy a produccion sin revision humana; la corre Luis en el editor SQL de Supabase.
--
-- QUE PASA: create_marketplace_order metia un valor a mano en marketplace_order_items.line_total,
-- pero esa columna es "generada" (Postgres la calcula solo con cantidad*precio+envio) y no se le
-- puede meter un valor a mano. Resultado: CUALQUIER intento de comprar algo en el marketplace
-- falla siempre con un error. Se descubrio probando el flujo de compra durante las pruebas de
-- seguridad que pedio Luis. No es un hueco de seguridad, es un bug que tiene el marketplace
-- 100% caido para compras.
--
-- Es identica a la funcion en produccion salvo que ya no intenta llenar line_total (se llena sola).

create or replace function public.create_marketplace_order(p_items jsonb, p_delivery_amount numeric DEFAULT 0)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare v_buyer uuid:=auth.uid(); v_order uuid; v_item jsonb; v_listing public.marketplace_listings%rowtype; v_inv public.marketplace_listing_inventory%rowtype; v_sub numeric:=0; v_fee numeric:=0; v_line numeric; v_qty integer; v_unit numeric; v_currency text; v_seen_currency text; v_seller uuid;
begin
 if v_buyer is null then raise exception 'not_authenticated'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'items_required'; end if;
 if coalesce(p_delivery_amount,0)<0 then raise exception 'invalid_delivery'; end if;
 for v_item in select * from jsonb_array_elements(p_items) loop
   v_qty:=nullif(v_item->>'quantity','')::integer;
   if v_qty is null or v_qty<=0 then raise exception 'invalid_quantity'; end if;
   select * into v_listing from public.marketplace_listings where id=(v_item->>'listing_id')::uuid and status in ('active','published') for update;
   if not found then raise exception 'listing_unavailable'; end if;
   if v_listing.owner_id=v_buyer then raise exception 'self_purchase_not_allowed'; end if;
   v_unit:=coalesce(v_listing.price,0); if v_unit<0 then raise exception 'invalid_price'; end if;
   v_currency:=v_listing.currency_code; if v_currency is null or length(trim(v_currency))=0 then raise exception 'listing_currency_missing'; end if;
   if v_seen_currency is null then v_seen_currency:=v_currency; elsif v_seen_currency<>v_currency then raise exception 'mixed_currency_not_allowed'; end if;
   select * into v_inv from public.marketplace_listing_inventory where listing_id=v_listing.id for update;
   if not found then raise exception 'inventory_not_configured'; end if;
   if v_inv.quantity_available-v_inv.reserved_quantity<v_qty then raise exception 'insufficient_inventory'; end if;
   v_line:=v_unit*v_qty; v_sub:=v_sub+v_line;
 end loop;
 v_fee:=round(v_sub*0.05,2);
 insert into public.marketplace_orders(buyer_id,currency_code,subtotal,delivery_amount,platform_fee,total_amount,status) values(v_buyer,v_seen_currency,v_sub,p_delivery_amount,v_fee,v_sub+p_delivery_amount,'reserved') returning id into v_order;
 for v_item in select * from jsonb_array_elements(p_items) loop
   select seller_id,price,currency_code into v_seller,v_unit,v_currency from public.marketplace_listings where id=(v_item->>'listing_id')::uuid;
   v_qty:=nullif(v_item->>'quantity','')::integer;
   insert into public.marketplace_order_items(order_id,listing_id,seller_id,sku,quantity,unit_price) values(v_order,(v_item->>'listing_id')::uuid,v_seller,null,v_qty,v_unit);
   update public.marketplace_listing_inventory set reserved_quantity=reserved_quantity+v_qty,updated_at=now() where listing_id=(v_item->>'listing_id')::uuid;
 end loop;
 return v_order;
end; $function$;
