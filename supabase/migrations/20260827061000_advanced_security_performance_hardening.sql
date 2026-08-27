-- Dynasty Advanced Security & Performance Hardening
revoke all on table public.shop_pos_payments from anon, authenticated;
revoke all on table public.shop_pos_registers from anon, authenticated;
revoke all on table public.shop_pos_sale_items from anon, authenticated;
revoke all on table public.shop_return_items from anon, authenticated;
revoke all on table public.shop_returns from anon, authenticated;
revoke all on table public.shop_inventory_adjustments from anon, authenticated;
revoke select, insert, update, delete on table public.shop_inventory_levels from anon;
revoke insert, update, delete on table public.shop_inventory_levels from authenticated;
grant select on table public.shop_inventory_levels to authenticated;
alter policy partner_preferences_owner on public.partner_preferences using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy partner_requests_participant_select on public.partner_requests using (((select auth.uid()) = requester_id) or ((select auth.uid()) = recipient_id));
alter policy shop_staff_member_read on public.shop_staff using ((profile_id = (select auth.uid())) or has_shop_permission(location_id, 'manage_staff'::text, (select auth.uid())));
alter policy skill_challenges_self_insert on public.skill_challenges with check ((select auth.uid()) = creator_id);
alter policy skill_submissions_self_insert on public.skill_submissions with check ((select auth.uid()) = user_id);
alter policy skill_votes_self_insert on public.skill_votes with check ((select auth.uid()) = user_id);
alter policy skill_comments_self_insert on public.skill_comments with check ((select auth.uid()) = user_id);
drop index if exists public.shop_orders_profile_idx;
drop index if exists public.shop_pos_sales_customer_idx;
drop index if exists public.shop_pos_sales_location_created_idx;

-- Secure notification bulk-read action for the authenticated owner only.
create or replace function public.mark_all_notifications_read()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare v_count integer;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  update public.notifications
     set read_at = now()
   where profile_id = auth.uid()
     and read_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke all on function public.mark_all_notifications_read() from public;
grant execute on function public.mark_all_notifications_read() to authenticated;
