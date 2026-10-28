-- cancel_my_billing_subscription: permite que el dueno del club (plan de Membresia) o el
-- organizador (plan de Organizador de Torneos, a titulo personal u org propia) cancele su
-- suscripcion. No revoca el acceso de inmediato: solo marca cancel_at_period_end = true, asi que
-- el cliente sigue usando lo que ya pago hasta el final del periodo vigente (current_period_end).
-- Despues de esa fecha, organization_has_active_club_membership / profile_or_org_has_active_
-- organizer_plan dejan de dar acceso por si solos (comparan current_period_end >= now()), sin
-- necesidad de un cron que cambie el status a 'cancelled'.
-- Probado en BEGIN/ROLLBACK contra produccion: caso exitoso, idempotente (llamar dos veces no
-- da error), FORBIDDEN para quien no es dueno de la organizacion, SUBSCRIPTION_NOT_FOUND para
-- una familia de plan sin suscripcion.
create or replace function public.cancel_my_billing_subscription(p_plan_family text, p_organization_id uuid DEFAULT NULL::uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_sub public.billing_subscriptions%rowtype;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_organization_id is not null then
    if not exists (select 1 from public.organizations where id = p_organization_id and owner_id = auth.uid()) then
      raise exception 'FORBIDDEN';
    end if;
  end if;
  select bs.* into v_sub
  from public.billing_subscriptions bs
  join public.billing_plans bp on bp.id = bs.plan_id
  where bp.plan_family = p_plan_family
    and (
      (p_organization_id is not null and bs.organization_id = p_organization_id)
      or (p_organization_id is null and bs.profile_id = auth.uid())
    )
  order by bs.created_at desc
  limit 1
  for update;
  if not found then raise exception 'SUBSCRIPTION_NOT_FOUND'; end if;
  if v_sub.status in ('cancelled','expired') then raise exception 'SUBSCRIPTION_NOT_ACTIVE'; end if;
  update public.billing_subscriptions set cancel_at_period_end = true, updated_at = now() where id = v_sub.id;
end;
$function$;

grant execute on function public.cancel_my_billing_subscription(text, uuid) to authenticated;
