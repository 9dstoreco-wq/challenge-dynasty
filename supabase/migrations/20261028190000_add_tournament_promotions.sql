-- Paquetes "Boost"/"Destacado" (app/promote): el organizador paga UNA VEZ para que SU torneo
-- aparezca primero en /competitions y /season durante una ventana de tiempo. Reutiliza
-- billing_invoices + WompiCheckoutButton domain="billing" (igual patron que MembershipPaywall,
-- components/MembershipPaywall.tsx) pero NO reutiliza create_subscription_invoice /
-- activate_subscription_from_paid_invoice como suscripcion: esas dos asumen una suscripcion
-- recurrente a nivel perfil/organizacion (billing_subscriptions), y esto es un pago unico atado a
-- UN torneo especifico. En vez de eso se agrega una tabla propia (tournament_promotions) y se
-- EXTIENDE el cuerpo de la funcion activate_subscription_from_paid_invoice() (CREATE OR REPLACE,
-- sin tocar el trigger que ya existe) para que tambien active la ventana de "destacado" cuando
-- la factura paga es de este tipo. Precios calibrados contra los dos billing_plans que ya cobran
-- en COP (club_membership_monthly $99.900, tournament_organizer_monthly $66.900): Destacado se
-- fija debajo de esos dos (es un addon puntual para UN torneo, no una suscripcion recurrente de
-- toda la cuenta) y Boost queda como entrada mas barata/corta para quien solo quiere probar.
-- DYNASTY PROMOTE (campana externa + patrocinios + espacios premium) se deja fuera de este
-- cobro self-service a proposito: es un paquete a medida, se cotiza por WhatsApp (ver
-- messages/es.json Promote.dynastyPromoteCta), no tiene un precio fijo que cobrar aqui.
--
-- IMPORTANTE (ver skill challenge-dynasty-release): DROP de cualquier tipo y CREATE/DROP TRIGGER
-- se cuelgan en este proyecto sin dejar rastro. Esta migracion no usa ninguno de los dos --
-- CREATE TABLE/POLICY/FUNCTION nuevas, y el unico cambio sobre algo existente es un
-- CREATE OR REPLACE FUNCTION sobre un trigger que YA esta creado.

insert into public.billing_plans (code, name, audience_type, description, billing_interval, price, currency_code, charge_amount_cop, plan_family, is_active)
values
  ('tournament_promo_boost', 'Boost', 'all', 'Prioridad en /competitions y /season por 5 dias.', 'one_time', 29000, 'COP', 29000, 'tournament_promotion', true),
  ('tournament_promo_destacado', 'Destacado', 'all', 'Primer lugar en /competitions y /season por 15 dias (o hasta que cierren las inscripciones, lo que ocurra primero).', 'one_time', 59000, 'COP', 59000, 'tournament_promotion', true)
on conflict (code) do nothing;

create table if not exists public.tournament_promotions (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  package_code text not null references public.billing_plans(code),
  invoice_id uuid references public.billing_invoices(id),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  status text not null default 'active' check (status in ('active','expired','cancelled')),
  created_at timestamptz not null default now()
);

create index if not exists tournament_promotions_active_idx
  on public.tournament_promotions (tournament_id, status, ends_at);

alter table public.tournament_promotions enable row level security;

-- Lectura publica: /competitions y /season necesitan saber que torneos estan destacados AHORA
-- para ordenar la lista, y eso no es informacion sensible (es publicidad, no un dato privado).
-- No hay politica de insert/update/delete para anon/authenticated: solo el trigger (security
-- definer, mas abajo) escribe aqui, nunca un cliente directo.
create policy "tournament promotions public read"
  on public.tournament_promotions
  for select
  to anon, authenticated
  using (true);

-- El organizador (dueno del torneo, por perfil o por organizacion) abre la factura de compra de
-- un paquete para SU torneo. Mismo patron de ownership que create_subscription_invoice /
-- mark_tournament_entry_paid_manually: verificar organizer_profile_id o organizations.owner_id.
create or replace function public.create_tournament_promotion_invoice(p_tournament_id uuid, p_package_code text)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_plan public.billing_plans%rowtype;
  v_tournament public.tournaments%rowtype;
  v_invoice_id uuid;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select * into v_tournament from public.tournaments where id = p_tournament_id;
  if not found then
    raise exception 'TOURNAMENT_NOT_FOUND';
  end if;

  if v_tournament.organizer_profile_id is distinct from auth.uid()
     and not exists (
       select 1 from public.organizations o
       where o.id = v_tournament.organization_id and o.owner_id = auth.uid()
     )
  then
    raise exception 'FORBIDDEN';
  end if;

  select * into v_plan from public.billing_plans
    where code = p_package_code and plan_family = 'tournament_promotion' and is_active = true;
  if not found then
    raise exception 'PLAN_NOT_FOUND';
  end if;
  if v_plan.charge_amount_cop is null then
    raise exception 'PLAN_NOT_CHARGEABLE';
  end if;

  -- Anula cualquier factura abierta previa del mismo organizador para el mismo torneo+paquete,
  -- para que abrir el checkout dos veces sin pagar no deje facturas "open" duplicadas.
  update public.billing_invoices bi
    set status = 'void', updated_at = now()
    where bi.status = 'open'
      and bi.profile_id = auth.uid()
      and (bi.metadata->>'plan_family') = 'tournament_promotion'
      and (bi.metadata->>'tournament_id') = p_tournament_id::text
      and (bi.metadata->>'package_code') = p_package_code;

  insert into public.billing_invoices(profile_id, amount_due, currency_code, status, due_at, metadata)
  values (
    auth.uid(), v_plan.charge_amount_cop, 'COP', 'open', now(),
    jsonb_build_object(
      'plan_family', 'tournament_promotion',
      'package_code', v_plan.code,
      'tournament_id', p_tournament_id,
      'redirect_path', '/competitions/' || p_tournament_id::text
    )
  ) returning id into v_invoice_id;

  return v_invoice_id;
end;
$$;

grant execute on function public.create_tournament_promotion_invoice(uuid, text) to authenticated;

-- Extiende la funcion del trigger YA EXISTENTE (trg_activate_subscription_from_paid_invoice,
-- AFTER UPDATE OF status ON billing_invoices) en vez de crear un trigger nuevo. Cuando la
-- factura pagada es de plan_family='tournament_promotion' activa la ventana de destacado;
-- cualquier otra factura sigue el camino de suscripcion de siempre, sin cambios.
create or replace function public.activate_subscription_from_paid_invoice()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_plan_id uuid;
  v_plan_family text;
  v_billing_interval text;
  v_period interval;
  v_sub public.billing_subscriptions%rowtype;
  v_found boolean := false;
  v_new_start timestamptz;
  v_new_end timestamptz;
  v_sub_id uuid;
  v_tournament_id uuid;
  v_package_code text;
  v_promo_duration interval;
  v_reg_closes timestamptz;
  v_promo_ends_at timestamptz;
begin
  if NEW.status <> 'paid' or OLD.status = 'paid' then
    return NEW;
  end if;
  if NEW.metadata is null or not (NEW.metadata ? 'plan_family') then
    return NEW;
  end if;

  if (NEW.metadata->>'plan_family') = 'tournament_promotion' then
    v_tournament_id := (NEW.metadata->>'tournament_id')::uuid;
    v_package_code := NEW.metadata->>'package_code';
    v_promo_duration := case v_package_code when 'tournament_promo_boost' then interval '5 days' else interval '15 days' end;

    select registration_closes_at into v_reg_closes from public.tournaments where id = v_tournament_id;
    v_promo_ends_at := now() + v_promo_duration;
    if v_reg_closes is not null and v_reg_closes > now() and v_reg_closes < v_promo_ends_at then
      v_promo_ends_at := v_reg_closes;
    end if;

    insert into public.tournament_promotions(tournament_id, package_code, invoice_id, starts_at, ends_at, status)
    values (v_tournament_id, v_package_code, NEW.id, now(), v_promo_ends_at, 'active');

    return NEW;
  end if;

  if not (NEW.metadata ? 'plan_id') then
    return NEW;
  end if;

  v_plan_id := (NEW.metadata->>'plan_id')::uuid;
  v_plan_family := NEW.metadata->>'plan_family';
  v_billing_interval := NEW.metadata->>'billing_interval';
  v_period := case v_billing_interval when 'yearly' then interval '1 year' else interval '1 month' end;

  select bs.* into v_sub
  from public.billing_subscriptions bs
  join public.billing_plans bp on bp.id = bs.plan_id
  where bp.plan_family = v_plan_family
    and (
      (NEW.organization_id is not null and bs.organization_id = NEW.organization_id)
      or (NEW.profile_id is not null and bs.profile_id = NEW.profile_id)
    )
  order by bs.created_at desc
  limit 1
  for update;
  v_found := FOUND;

  if v_found and v_sub.status = 'active' and v_sub.current_period_end > now() then
    v_new_start := v_sub.current_period_start;
    v_new_end := v_sub.current_period_end + v_period;
  else
    v_new_start := now();
    v_new_end := now() + v_period;
  end if;

  if v_found then
    update public.billing_subscriptions
      set plan_id = v_plan_id, status = 'active', current_period_start = v_new_start,
          current_period_end = v_new_end, cancel_at_period_end = false, provider_name = 'wompi',
          updated_at = now()
      where id = v_sub.id
      returning id into v_sub_id;
  else
    insert into public.billing_subscriptions(plan_id, profile_id, organization_id, status, current_period_start, current_period_end, provider_name)
    values (v_plan_id, NEW.profile_id, NEW.organization_id, 'active', v_new_start, v_new_end, 'wompi')
    returning id into v_sub_id;
  end if;

  update public.billing_invoices set subscription_id = v_sub_id where id = NEW.id;

  return NEW;
end;
$function$;
