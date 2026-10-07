-- Challenge Dynasty -- deja que el organizador cree categorias dentro de su torneo.
-- ESTADO: ESCRITA, NO APLICADA. El sistema de permisos bloqueo aplicarla desde Claude
-- porque es un deploy a produccion sin revision humana; la corre Luis en el editor SQL de Supabase.
--
-- QUE PASABA: encontrado en la auditoria completa de torneos. La tabla "tournament_categories"
-- (individual/parejas/equipos, cupo, costo de inscripcion) solo tenia permiso de LECTURA. No
-- existia ningun permiso para CREAR una categoria -- ni desde la pantalla ni directo en la base
-- de datos. Sin categoria, nadie se puede inscribir a ningun torneo: es la pieza que faltaba
-- para que todo lo demas de torneos pudiera funcionar.
--
-- QUE HACE ESTE ARCHIVO: agrega permiso para que el organizador del torneo (o quien tenga el
-- permiso "manage_tournaments" en el club organizador) cree, edite o borre las categorias de SU
-- propio torneo. Nadie mas puede tocar categorias de un torneo que no es suyo.

create policy "tournament categories organizer write"
on public.tournament_categories
for all
to authenticated
using (
  exists (
    select 1 from public.tournaments t
    where t.id = tournament_categories.tournament_id
      and (
        t.organizer_profile_id = auth.uid()
        or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))
      )
  )
)
with check (
  exists (
    select 1 from public.tournaments t
    where t.id = tournament_categories.tournament_id
      and (
        t.organizer_profile_id = auth.uid()
        or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))
      )
  )
);
