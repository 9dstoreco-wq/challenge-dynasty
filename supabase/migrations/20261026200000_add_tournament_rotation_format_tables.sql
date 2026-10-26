-- Soporte para Americano y Mexicano: a diferencia de los demás formatos, la pareja cambia cada
-- ronda y el puntaje es POR JUGADOR, no por pareja fija. tournament_fixtures asume side_a/side_b
-- fijos durante todo el torneo, así que estos dos formatos usan tablas propias en vez de forzarlo
-- ahí. Sigue el mismo patrón de RLS que tournament_fixtures/tournament_entries (organizador
-- administra, visibilidad pública/propia para leer).

CREATE TABLE IF NOT EXISTS public.tournament_rotation_matches (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  tournament_id uuid NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES public.tournament_categories(id) ON DELETE CASCADE,
  stage_id uuid REFERENCES public.tournament_stages(id) ON DELETE SET NULL,
  round_number integer NOT NULL,
  court integer NOT NULL,
  side_a_player1_id uuid NOT NULL REFERENCES public.tournament_entries(id) ON DELETE CASCADE,
  side_a_player2_id uuid NOT NULL REFERENCES public.tournament_entries(id) ON DELETE CASCADE,
  side_b_player1_id uuid NOT NULL REFERENCES public.tournament_entries(id) ON DELETE CASCADE,
  side_b_player2_id uuid NOT NULL REFERENCES public.tournament_entries(id) ON DELETE CASCADE,
  score_a integer,
  score_b integer,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'completed', 'cancelled')),
  scheduled_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tournament_rotation_matches_category
  ON public.tournament_rotation_matches (category_id, round_number);

CREATE TABLE IF NOT EXISTS public.tournament_rotation_standings (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  tournament_id uuid NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES public.tournament_categories(id) ON DELETE CASCADE,
  entry_id uuid NOT NULL REFERENCES public.tournament_entries(id) ON DELETE CASCADE,
  total_points numeric NOT NULL DEFAULT 0,
  matches_played integer NOT NULL DEFAULT 0,
  UNIQUE (category_id, entry_id)
);

ALTER TABLE public.tournament_rotation_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_rotation_standings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tournament rotation matches organizer write" ON public.tournament_rotation_matches
  AS PERMISSIVE FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.tournaments t
    WHERE t.id = tournament_rotation_matches.tournament_id
      AND (t.organizer_profile_id = auth.uid()
        OR (t.organization_id IS NOT NULL AND public.has_organization_permission(t.organization_id, 'manage_tournaments', auth.uid())))
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.tournaments t
    WHERE t.id = tournament_rotation_matches.tournament_id
      AND (t.organizer_profile_id = auth.uid()
        OR (t.organization_id IS NOT NULL AND public.has_organization_permission(t.organization_id, 'manage_tournaments', auth.uid())))
  ));

CREATE POLICY "tournament rotation matches visibility read" ON public.tournament_rotation_matches
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.tournaments t
    WHERE t.id = tournament_rotation_matches.tournament_id
      AND (t.visibility = 'public'
        OR t.organizer_profile_id = auth.uid()
        OR t.organization_id IN (SELECT o.id FROM public.organizations o WHERE o.owner_id = auth.uid()))
  ));

CREATE POLICY "tournament rotation standings organizer write" ON public.tournament_rotation_standings
  AS PERMISSIVE FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.tournaments t
    WHERE t.id = tournament_rotation_standings.tournament_id
      AND (t.organizer_profile_id = auth.uid()
        OR (t.organization_id IS NOT NULL AND public.has_organization_permission(t.organization_id, 'manage_tournaments', auth.uid())))
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.tournaments t
    WHERE t.id = tournament_rotation_standings.tournament_id
      AND (t.organizer_profile_id = auth.uid()
        OR (t.organization_id IS NOT NULL AND public.has_organization_permission(t.organization_id, 'manage_tournaments', auth.uid())))
  ));

CREATE POLICY "tournament rotation standings visibility read" ON public.tournament_rotation_standings
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.tournaments t
    WHERE t.id = tournament_rotation_standings.tournament_id
      AND (t.visibility = 'public'
        OR t.organizer_profile_id = auth.uid()
        OR t.organization_id IN (SELECT o.id FROM public.organizations o WHERE o.owner_id = auth.uid()))
  ));

-- Registra el resultado de un partido de Americano/Mexicano: guarda el marcador y le suma el
-- puntaje a los 4 jugadores (cada uno de un lado recibe el puntaje de SU lado, no de ganar o
-- perder — así funciona el puntaje individual en Americano). Mismo patron de permisos y guardas
-- que record_tournament_fixture_result (solo el organizador puede registrar, un partido ya
-- cerrado no se puede tocar de nuevo).
CREATE OR REPLACE FUNCTION public.record_rotation_match_result(
  p_match_id uuid,
  p_score_a integer,
  p_score_b integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_match public.tournament_rotation_matches;
  v_t public.tournaments;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión';
  END IF;
  IF p_score_a IS NULL OR p_score_b IS NULL THEN
    RAISE EXCEPTION 'SCORES_REQUIRED';
  END IF;
  IF p_score_a < 0 OR p_score_b < 0 THEN
    RAISE EXCEPTION 'SCORES_MUST_BE_NON_NEGATIVE';
  END IF;

  SELECT * INTO v_match FROM public.tournament_rotation_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found';
  END IF;
  SELECT * INTO v_t FROM public.tournaments WHERE id = v_match.tournament_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tournament not found';
  END IF;
  IF NOT (v_t.organizer_profile_id = auth.uid()
      OR (v_t.organization_id IS NOT NULL AND public.has_organization_permission(v_t.organization_id, 'manage_tournaments', auth.uid()))) THEN
    RAISE EXCEPTION 'No autorizado para registrar resultado';
  END IF;
  IF v_match.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'Match already finalized';
  END IF;

  UPDATE public.tournament_rotation_matches
  SET score_a = p_score_a, score_b = p_score_b, status = 'completed'
  WHERE id = p_match_id;

  INSERT INTO public.tournament_rotation_standings (tournament_id, category_id, entry_id, total_points, matches_played)
  VALUES
    (v_match.tournament_id, v_match.category_id, v_match.side_a_player1_id, p_score_a, 1),
    (v_match.tournament_id, v_match.category_id, v_match.side_a_player2_id, p_score_a, 1),
    (v_match.tournament_id, v_match.category_id, v_match.side_b_player1_id, p_score_b, 1),
    (v_match.tournament_id, v_match.category_id, v_match.side_b_player2_id, p_score_b, 1)
  ON CONFLICT (category_id, entry_id) DO UPDATE
  SET total_points = tournament_rotation_standings.total_points + EXCLUDED.total_points,
      matches_played = tournament_rotation_standings.matches_played + 1;

  RETURN jsonb_build_object('ok', true, 'match_id', p_match_id);
END;
$function$;
