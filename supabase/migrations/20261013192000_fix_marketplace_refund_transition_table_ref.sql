-- Hallazgo adicional encontrado durante la verificacion en vivo de F02
-- (Auditoria_Challenge_Dynasty_2026-10-12.md). F02 en si ("RLS de marketplace_orders
-- bloquea al comprador") NO reproduce: ya existe un RPC SECURITY DEFINER
-- (get_my_marketplace_orders/get_my_marketplace_order_items, propiedad de "postgres",
-- rolbypassrls=true) que correctamente filtra por buyer_id/seller_id y evade el
-- deny_all deliberado sobre la tabla cruda -- probado de punta a punta contra la base
-- en vivo (comprador crea orden, se ve a si mismo, vendedor ve su venta, un tercero no
-- ve nada, el select directo a la tabla sigue bloqueado), 6/6 checks OK, revertido con
-- RAISE EXCEPTION, nada persistido. Ningun cambio de codigo necesario para F02.
--
-- Pero advance_marketplace_order_status() -- la funcion que mueve una orden a
-- 'refunded'/'partially_refunded' -- SI tenia un bug real, no señalado por la auditoria
-- original: referenciaba una tabla que no existe, `public.marketplace_payment_refunds`
-- (confirmado contra information_schema.tables -- solo existe `marketplace_order_refunds`),
-- y aun corrigiendo el nombre, la consulta original filtraba por una columna
-- `order_id` que `marketplace_order_refunds` tampoco tiene (solo tiene `payment_id`,
-- que referencia `marketplace_order_payments.id`). Es decir: CUALQUIER intento de marcar
-- una orden como reembolsada (total o parcial) fallaba siempre con un error duro de
-- Postgres ("relation does not exist"), para cualquier orden, sin excepcion -- el camino
-- de reembolso del marketplace estaba completamente roto, no solo mal señalado.
--
-- Corregido: la suma de reembolsos exitosos para una orden ahora se calcula uniendo
-- marketplace_order_refunds.payment_id -> marketplace_order_payments.id, filtrando por
-- marketplace_order_payments.order_id = p_order_id y marketplace_order_refunds.status =
-- 'succeeded' (confirmado como valor válido vía pg_get_constraintdef). El resto de la
-- función (chequeo de service_role, transiciones de estado, REFUND_TOTAL_MISMATCH,
-- PARTIAL_REFUND_AMOUNT_INVALID) queda igual -- ya era correcto.
--
-- Verificado con fixtures reales dentro de DO $$ ... RAISE EXCEPTION ... END $$ contra
-- la base en vivo (confirmado revertido, nada persistido): un reembolso total real pasa
-- la transición a 'refunded'; un reembolso parcial sigue siendo rechazado correctamente
-- para la transición a 'refunded' completo (REFUND_TOTAL_MISMATCH). 2/2 checks OK.
--
-- NOT applied to production by this commit. Prepared on branch
-- fix/wompi-webhook-reconciliation per Mensaje_para_Claude.md ("no apliques migraciones
-- a producción"). Apply only after the user reviews it.

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
   -- Fix: marketplace_order_refunds (not the nonexistent marketplace_payment_refunds)
   -- joined through its payment_id -> marketplace_order_payments.order_id, since refunds
   -- are keyed by payment, not by order, directly.
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
