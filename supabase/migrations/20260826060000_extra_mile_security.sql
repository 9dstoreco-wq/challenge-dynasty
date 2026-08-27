-- Challenge Dynasty Extra Mile security hardening.
-- Do NOT enable RLS on public.spatial_ref_sys automatically: it is PostGIS-owned
-- and requires a dedicated policy decision.
revoke execute on function public.st_estimatedextent(text,text) from anon, authenticated, public;
revoke execute on function public.st_estimatedextent(text,text,text) from anon, authenticated, public;
revoke execute on function public.st_estimatedextent(text,text,text,boolean) from anon, authenticated, public;

create table if not exists public.platform_security_exceptions (
  key text primary key,
  severity text not null,
  status text not null,
  details text not null,
  updated_at timestamptz not null default now()
);

alter table public.platform_security_exceptions enable row level security;
revoke all on table public.platform_security_exceptions from anon, authenticated, public;

insert into public.platform_security_exceptions(key,severity,status,details)
values (
  'postgis_spatial_ref_sys',
  'critical',
  'accepted_exception',
  'PostGIS-owned public.spatial_ref_sys requires special handling; automatic RLS enablement is intentionally not applied because policies must be designed for geospatial internals. The release documents this exception for final platform review.'
)
on conflict (key) do update set
  severity = excluded.severity,
  status = excluded.status,
  details = excluded.details,
  updated_at = now();
