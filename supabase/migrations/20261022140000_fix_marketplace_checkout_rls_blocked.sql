-- Challenge Dynasty -- el checkout de marketplace estaba totalmente bloqueado.
-- ESTADO: ESCRITA, NO APLICADA. El sistema de permisos bloqueo aplicarla desde Claude porque es
-- un deploy a produccion sin revision humana; la corre Luis en el editor SQL de Supabase.
--
-- QUE PASABA:
-- public.marketplace_orders tiene una sola policy de RLS para `authenticated`:
--   deny_all_authenticated_marketplace_orders -- USING (false), WITH CHECK (false), para ALL.
-- lib/dynasty/checkout-resolvers.ts (funcion resolveMarketplace) lee esa tabla directo con la
-- sesion del usuario (createClient() de lib/supabase/server.ts, NO service_role), asi que esa
-- policy la bloqueaba siempre: cualquier intento real de pagar una orden de marketplace
-- respondia "ORDER_NOT_FOUND" sin importar que la orden existiera.
--
-- El resto de la app ya resuelve esto bien: app/marketplace/orders/page.tsx no lee la tabla
-- directo, llama a la funcion get_my_marketplace_orders() (security definer, filtra por
-- auth.uid()). checkout-resolvers.ts era el unico lugar que se habia quedado con la lectura
-- directa. Esta migracion agrega el mismo patron, acotado a una sola orden por id, para que el
-- checkout pueda usarlo (ver el cambio correspondiente en checkout-resolvers.ts).
create or replace function public.resolve_marketplace_order_for_checkout(p_order_id uuid)
returns table (
  id uuid,
  total_amount numeric,
  currency_code text,
  buyer_id uuid,
  status text
)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
  select o.id, o.total_amount, o.currency_code, o.buyer_id, o.status
  from public.marketplace_orders o
  where o.id = p_order_id and o.buyer_id = auth.uid();
$$;

revoke all on function public.resolve_marketplace_order_for_checkout(uuid) from public, anon;
grant execute on function public.resolve_marketplace_order_for_checkout(uuid) to authenticated;
