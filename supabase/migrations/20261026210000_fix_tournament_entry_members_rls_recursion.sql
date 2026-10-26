-- BUG CRÍTICO #2 de esta sesión (26 de octubre): encontrado probando la migración de Americano.
-- Después de arreglar el permiso que faltaba en has_organization_permission (migración anterior),
-- cualquier lectura de tournament_entries como usuario normal falla con:
--   "infinite recursion detected in policy for relation tournament_entries"
--
-- Causa: dos políticas se llaman en círculo.
--   - tournament_entries."tournament entry own read" necesita consultar tournament_entry_members
--     (para saber si el usuario es integrante de esa inscripción).
--   - tournament_entry_members."tournament entry members public read" necesita consultar
--     tournament_entries + tournaments (para saber si el torneo es visible).
-- Cada consulta dispara la política de la otra tabla, que vuelve a disparar la primera — recursión
-- infinita. Esto bloquea por completo ver los inscritos de cualquier torneo (roster) como jugador.
--
-- Arreglo: una función SECURITY DEFINER (tournament_entry_is_visible) hace la consulta de
-- visibilidad POR FUERA de las políticas normales (las funciones SECURITY DEFINER corren con los
-- permisos de su dueño — postgres, dueño de ambas tablas, que no tiene RLS forzada — así que no
-- vuelven a disparar las políticas). La política de tournament_entry_members pasa a usar esa
-- función en vez de la consulta directa, rompiendo el círculo. No se quita ninguna protección: el
-- resultado de la función es exactamente la misma condición de visibilidad que ya existía.
--
-- ADVERTENCIA DE ESTE PROYECTO: DROP POLICY / CREATE POLICY se cuelga sin dejar rastro al
-- aplicarse con las herramientas automáticas (confirmado de nuevo en esta sesión: la prueba en
-- BEGIN...ROLLBACK se colgó más de 3 minutos). Por eso esta migración queda lista aquí para que
-- Luis la corra él mismo en el SQL Editor de Supabase (Dashboard → su proyecto → SQL Editor →
-- pegar y ejecutar). No reintentar en bucle con las herramientas automáticas.

CREATE OR REPLACE FUNCTION public.tournament_entry_is_visible(p_entry_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.tournament_entries te
    JOIN public.tournaments t ON t.id = te.tournament_id
    WHERE te.id = p_entry_id
      AND (t.visibility = 'public'
        OR t.organizer_profile_id = auth.uid()
        OR (t.organization_id IS NOT NULL AND public.has_organization_permission(t.organization_id, 'manage_tournaments', auth.uid())))
  );
$function$;

DROP POLICY IF EXISTS "tournament entry members public read" ON public.tournament_entry_members;
CREATE POLICY "tournament entry members public read" ON public.tournament_entry_members
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (public.tournament_entry_is_visible(entry_id));
