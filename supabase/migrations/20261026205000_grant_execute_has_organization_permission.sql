-- Bug crítico: has_organization_permission() se usa dentro de las políticas RLS de 8 tablas de
-- torneos (organization_resources, tournament_categories, tournament_entries,
-- tournament_entry_members, tournament_fixtures, tournament_groups,
-- tournament_registration_payments, tournament_stages), pero nunca se le dio permiso de EJECUCIÓN
-- a los roles 'authenticated' ni 'anon'. Resultado: cualquier lectura de esas tablas por un usuario
-- normal o visitante fallaba con "permission denied for function has_organization_permission",
-- sin importar si había filas o no (el chequeo de permiso ocurre al inicializar el plan, no por
-- fila). Encontrado el 26 de octubre probando la migración de Americano; ya aplicado en vivo
-- (migración ligera, sin riesgo de colgarse — no es DROP, trigger, ni función con guardas).
GRANT EXECUTE ON FUNCTION public.has_organization_permission(uuid, text, uuid) TO authenticated, anon;
