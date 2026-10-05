-- Challenge Dynasty -- evita retos duplicados en el servidor.
-- ESTADO: ESCRITA, NO APLICADA. El sistema de permisos bloqueo aplicarla desde Claude; la corre el dueno
-- en el editor SQL de Supabase (usa "create or replace", sin drops).
--
-- Regla: mismo creador + mismo rival + mismo deporte + misma fecha mientras el reto siga abierto => 'Ya enviaste este reto'.
-- Es identica a la funcion en produccion salvo por el bloque marcado.

create or replace function public.create_challenge(p_challenged_id uuid, p_sport_id uuid, p_match_date timestamp with time zone, p_club_id uuid DEFAULT NULL::uuid, p_match_type text DEFAULT 'DIRECT'::text, p_points integer DEFAULT 100)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
DECLARE v_challenge public.challenges; v_id uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Debes iniciar sesión'; END IF;
 IF p_challenged_id IS NULL OR p_challenged_id=auth.uid() THEN RAISE EXCEPTION 'Rival inválido'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=p_challenged_id) THEN RAISE EXCEPTION 'Rival no encontrado'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.sports WHERE id=p_sport_id) THEN RAISE EXCEPTION 'Deporte no encontrado'; END IF;
 IF p_match_date IS NOT NULL AND p_match_date<=now() THEN RAISE EXCEPTION 'La fecha del reto debe ser futura'; END IF;
 IF p_points<1 OR p_points>5000 THEN RAISE EXCEPTION 'Los puntos deben estar entre 1 y 5000'; END IF;
 IF p_match_type NOT IN ('DIRECT','INSTANT') THEN RAISE EXCEPTION 'Tipo de reto inválido'; END IF;
 -- >>> NUEVO: anti-duplicados
 IF EXISTS (
   SELECT 1 FROM public.challenges c
   JOIN public.challenge_invitations i ON i.challenge_id=c.id
   WHERE c.creator_id=auth.uid() AND c.status='open' AND c.sport_id=p_sport_id
     AND i.invitee_id=p_challenged_id
     AND c.scheduled_at IS NOT DISTINCT FROM p_match_date
 ) THEN RAISE EXCEPTION 'Ya enviaste este reto'; END IF;
 -- <<< fin de lo nuevo
 INSERT INTO public.challenges(sport_id,creator_id,title,description,status,challenge_type,scheduled_at,location_name,metadata)
 VALUES(p_sport_id,auth.uid(),'Reto Dynasty',NULL,'open','match',p_match_date,NULL,jsonb_build_object('match_type',p_match_type,'points',p_points,'club_id',p_club_id)) RETURNING id INTO v_id;
 PERFORM public.create_challenge_invitation(v_id,p_challenged_id,NULL,coalesce(p_match_date,now()+interval '7 days'));
 RETURN v_id;
END; $function$;
