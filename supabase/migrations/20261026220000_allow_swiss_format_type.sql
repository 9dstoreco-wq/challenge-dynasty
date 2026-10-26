-- Bug encontrado probando el sistema suizo (antes de activarlo, dentro de BEGIN...ROLLBACK): la
-- restricción CHECK de tournaments.format_type nunca se actualizó para incluir 'swiss' —
-- intentar crear un torneo con ese formato fallaba de una con
-- "violates check constraint tournaments_format_type_check". Esta migración solo AMPLÍA la lista
-- de valores permitidos (agrega 'swiss'); no quita ninguno de los que ya estaban.
--
-- Es un ALTER TABLE ... DROP/ADD CONSTRAINT simple (no es DROP de índice/función/trigger, ni
-- CREATE/DROP de trigger o policy, ni una función con varias guardas RAISE EXCEPTION), así que no
-- debería entrar en la categoría de migraciones que se cuelgan en este proyecto — pero igual se
-- deja el archivo listo por si hace falta correrla a mano desde el SQL Editor.

ALTER TABLE public.tournaments DROP CONSTRAINT IF EXISTS tournaments_format_type_check;
ALTER TABLE public.tournaments ADD CONSTRAINT tournaments_format_type_check
  CHECK (format_type = ANY (ARRAY[
    'single_elimination'::text,
    'double_elimination'::text,
    'round_robin'::text,
    'groups_then_knockout'::text,
    'ladder'::text,
    'americano'::text,
    'mexicano'::text,
    'king_of_the_court'::text,
    'custom'::text,
    'swiss'::text
  ]));
