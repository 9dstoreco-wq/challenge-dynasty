-- Challenge Dynasty -- deja ver el cuadro de partidos (rivales) de un torneo publico.
-- ESTADO: APLICADA EN PRODUCCION (confirmado 2026-10-14, F10: las policies 'tournament entries public read' y
-- 'tournament entry members public read' ya existen en vivo). Esta nota decia 'NO APLICADA' pero nunca se
-- actualizo despues de que Luis la corriera a mano en el editor SQL -- ver Challenge_Dynasty_F10_entrega.md.
--
-- QUE PASABA: encontrado durante la auditoria completa de torneos que pidio Luis. Hoy, aunque
-- un torneo sea publico, nadie puede ver quien esta inscrito ni quien juega contra quien --
-- "tournament_entries" y "tournament_entry_members" solo dejan ver tu propia inscripcion, nunca
-- la de los demas. Es decir: ni el publico ni los otros jugadores pueden ver el cuadro de
-- partidos de un torneo publico, aunque la pantalla lo mostrara bien.
--
-- QUE HACE ESTE ARCHIVO: agrega permiso de SOLO LECTURA (nadie puede escribir con esto) para
-- ver las inscripciones y sus integrantes cuando el torneo es publico, o cuando quien mira es el
-- organizador del torneo. No cambia nada mas.

create policy "tournament entries public read"
on public.tournament_entries
for select
to public
using (
  exists (
    select 1 from public.tournaments t
    where t.id = tournament_entries.tournament_id
      and (
        t.visibility = 'public'
        or t.organizer_profile_id = auth.uid()
        or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))
      )
  )
);

create policy "tournament entry members public read"
on public.tournament_entry_members
for select
to public
using (
  exists (
    select 1 from public.tournament_entries te
    join public.tournaments t on t.id = te.tournament_id
    where te.id = tournament_entry_members.entry_id
      and (
        t.visibility = 'public'
        or t.organizer_profile_id = auth.uid()
        or (t.organization_id is not null and public.has_organization_permission(t.organization_id,'manage_tournaments',auth.uid()))
      )
  )
);
