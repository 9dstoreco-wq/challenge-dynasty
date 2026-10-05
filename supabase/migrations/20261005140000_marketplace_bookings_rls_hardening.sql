-- Challenge Dynasty — endurecimiento de seguridad (revision en vivo 2026-10-05)
-- ESTADO: ESCRITA, NO APLICADA. Se aplica solo con autorizacion explicita del dueno.
-- Todo es idempotente (drop if exists / create or replace).
--
-- Contexto: las politicas RLS de estas tablas solo comparan owner_id = auth.uid(), pero no limitan
-- QUE columnas puede escribir ese dueno. Un usuario con sesion puede llamar la API directamente
-- (sin pasar por la app) y escribir columnas "privilegiadas".
--
-- 1. bookings: la politica "bookings user insert" permitia insertar una reserva con
--    payment_status = 'paid', status = 'confirmed' y amount = 0. La app NO la usa: las reservas
--    se crean con la RPC create_atomic_booking (SECURITY DEFINER, precio leido en el servidor).
-- 2. marketplace_seller_profiles: el dueno podia fijarse verification_status = 'verified' y
--    premium_status = 'premium' (insignias que deberian ser de pago o de verificacion manual).
-- 3. marketplace_listings: el dueno podia fijar is_featured / is_premium_placement (colocacion
--    destacada gratis) y apuntar seller_id al perfil de OTRO vendedor (suplantacion).
-- 4. bookable_entities: se podia colgar un servicio reservable de un recurso (cancha) de otro club.
-- 5. billing_invoices / billing_subscriptions: la condicion de vendedor referenciaba la tabla
--    externa en vez del vendedor, asi que un vendedor nunca veia sus propias facturas.
-- 6. Se revocan TRUNCATE / REFERENCES / TRIGGER a anon y authenticated (RLS no aplica a TRUNCATE).
--
-- Las llamadas con service_role (webhooks, Edge Functions, editor SQL) tienen auth.uid() = NULL y
-- no se ven afectadas por los triggers de abajo.

-- 1 ---------------------------------------------------------------------------------------------
drop policy if exists "bookings user insert" on public.bookings;

-- 2 ---------------------------------------------------------------------------------------------
create or replace function public.protect_seller_profile_privileged()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
begin
  if auth.uid() is null then return new; end if;   -- service_role / SQL editor
  if tg_op = 'INSERT' then
    new.verification_status := 'unverified';
    new.premium_status := 'free';
  else
    new.verification_status := old.verification_status;
    new.premium_status := old.premium_status;
  end if;
  return new;
end $$;

drop trigger if exists trg_protect_seller_profile_privileged on public.marketplace_seller_profiles;
create trigger trg_protect_seller_profile_privileged
  before insert or update on public.marketplace_seller_profiles
  for each row execute function public.protect_seller_profile_privileged();

-- 3 ---------------------------------------------------------------------------------------------
create or replace function public.protect_listing_privileged()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
begin
  if auth.uid() is null then return new; end if;   -- service_role / SQL editor
  if tg_op = 'INSERT' then
    new.is_featured := false;
    new.is_premium_placement := false;
  else
    new.is_featured := old.is_featured;
    new.is_premium_placement := old.is_premium_placement;
  end if;
  if new.seller_id is not null and (tg_op = 'INSERT' or new.seller_id is distinct from old.seller_id) then
    if not exists (
      select 1 from public.marketplace_seller_profiles sp
      where sp.id = new.seller_id
        and (sp.owner_id = auth.uid()
             or sp.organization_id in (select o.id from public.organizations o where o.owner_id = auth.uid()))
    ) then
      raise exception 'SELLER_NOT_OWNED';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_protect_listing_privileged on public.marketplace_listings;
create trigger trg_protect_listing_privileged
  before insert or update on public.marketplace_listings
  for each row execute function public.protect_listing_privileged();

-- 4 ---------------------------------------------------------------------------------------------
create or replace function public.enforce_bookable_resource_ownership()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
begin
  if auth.uid() is null then return new; end if;   -- service_role / SQL editor
  if new.organization_resource_id is not null
     and (tg_op = 'INSERT' or new.organization_resource_id is distinct from old.organization_resource_id) then
    if not exists (
      select 1
      from public.organization_resources r
      join public.organizations o on o.id = r.organization_id
      where r.id = new.organization_resource_id
        and (o.owner_id = auth.uid()
             or exists (select 1 from public.organization_memberships m
                        where m.organization_id = o.id and m.profile_id = auth.uid() and m.status = 'active'
                          and m.membership_type in ('owner', 'admin', 'manager', 'coach', 'staff')))
    ) then
      raise exception 'RESOURCE_NOT_OWNED';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_enforce_bookable_resource_ownership on public.bookable_entities;
create trigger trg_enforce_bookable_resource_ownership
  before insert or update of organization_resource_id on public.bookable_entities
  for each row execute function public.enforce_bookable_resource_ownership();

-- 5 ---------------------------------------------------------------------------------------------
drop policy if exists "billing invoices owner read" on public.billing_invoices;
create policy "billing invoices owner read" on public.billing_invoices
  for select to authenticated
  using (
    profile_id = (select auth.uid())
    or organization_id in (select o.id from public.organizations o where o.owner_id = (select auth.uid()))
    or seller_profile_id in (select sp.id from public.marketplace_seller_profiles sp where sp.owner_id = (select auth.uid()))
  );

drop policy if exists "billing subscriptions owner read" on public.billing_subscriptions;
create policy "billing subscriptions owner read" on public.billing_subscriptions
  for select to authenticated
  using (
    profile_id = (select auth.uid())
    or organization_id in (select o.id from public.organizations o where o.owner_id = (select auth.uid()))
    or seller_profile_id in (select sp.id from public.marketplace_seller_profiles sp where sp.owner_id = (select auth.uid()))
  );

-- 6 ---------------------------------------------------------------------------------------------
revoke truncate, references, trigger on all tables in schema public from anon, authenticated;
