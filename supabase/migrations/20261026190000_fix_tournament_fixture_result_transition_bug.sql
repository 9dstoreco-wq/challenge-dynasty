-- BUG CRÍTICO (bloquea publicar torneos): la función que registra el resultado de CUALQUIER
-- partido de torneo (record_tournament_fixture_result, usada por TODOS los formatos ya en
-- producción: eliminación simple, round robin, grupos+eliminación, y ahora King of the Court)
-- intenta pasar un partido de 'scheduled' directo a 'completed'. El trigger de guarda
-- (guard_tournament_fixture_status) no permitía esa transición — solo dejaba pasar a
-- 'completed' desde 'in_progress', y la app nunca pone un partido en 'in_progress' antes de
-- registrar el resultado. Resultado: en cuanto el primer torneo real llegue al punto de que
-- alguien apriete "Registrar resultado", la base le devuelve el error 'invalid_fixture_transition'
-- y el resultado nunca se guarda. Nadie lo había visto porque todavía no hay torneos reales en
-- producción con partidos jugados.
--
-- Confirmado en Supabase dentro de BEGIN...ROLLBACK (torneo/categoría/partido de prueba,
-- llamando record_tournament_fixture_result exactamente como lo hace la app): el error
-- 'invalid_fixture_transition' se dispara siempre. Esta migración solo AMPLÍA las transiciones
-- permitidas (agrega 'completed' como destino válido desde 'scheduled' y desde 'ready'); no
-- quita ninguna de las protecciones existentes (un partido 'completed' o 'cancelled' sigue
-- siendo inmutable).
--
-- ADVERTENCIA DE ESTE PROYECTO: las funciones con varias guardas RAISE EXCEPTION como esta se
-- han colgado más de 3 minutos sin dejar rastro al aplicarse con las herramientas automáticas.
-- Por eso esta migración se deja lista aquí para que Luis la corra él mismo en el SQL Editor de
-- Supabase (Dashboard → su proyecto → SQL Editor → pegar y ejecutar), en vez de aplicarla desde
-- acá. No reintentar en bucle si se cuelga la herramienta automática.

CREATE OR REPLACE FUNCTION public.guard_tournament_fixture_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF OLD.status = 'completed' AND NEW.status NOT IN ('completed') THEN
    RAISE EXCEPTION 'completed_fixture_is_immutable';
  END IF;
  IF OLD.status = 'cancelled' AND NEW.status NOT IN ('cancelled') THEN
    RAISE EXCEPTION 'cancelled_fixture_is_immutable';
  END IF;
  IF OLD.status = 'scheduled' AND NEW.status NOT IN ('scheduled','ready','in_progress','completed','cancelled','walkover') THEN
    RAISE EXCEPTION 'invalid_fixture_transition';
  END IF;
  IF OLD.status = 'ready' AND NEW.status NOT IN ('ready','in_progress','completed','cancelled','walkover') THEN
    RAISE EXCEPTION 'invalid_fixture_transition';
  END IF;
  IF OLD.status = 'in_progress' AND NEW.status NOT IN ('in_progress','completed','cancelled','walkover') THEN
    RAISE EXCEPTION 'invalid_fixture_transition';
  END IF;
  RETURN NEW;
END;
$function$
;
