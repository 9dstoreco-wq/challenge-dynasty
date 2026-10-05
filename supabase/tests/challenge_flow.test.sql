-- Challenge Dynasty — prueba del flujo de retos contra la base de datos real.
--
-- COMO CORRERLA: pega todo el archivo en el editor SQL de Supabase y ejecutalo.
-- Es SEGURA: al final lanza un error a proposito ("RESULTADOS ...") y eso deshace todo lo que la prueba
-- creo (retos, resultados, cartas, notificaciones). No queda ningun dato.
-- Lo que importa es el texto del error: cada linea empieza con OK, FALLO o INFO.
-- Si aparece alguna linea FALLO, algo del flujo se rompio.
--
-- Necesita al menos 3 perfiles y 1 deporte en la base. Usa los perfiles mas antiguos.
-- Simula a cada jugador cambiando auth.uid() y el rol "authenticated", igual que la app.

do $$
declare
  ids uuid[];
  a uuid; b uuid; c uuid;
  sp uuid;
  ch1 uuid; ch2 uuid; ch3 uuid;
  m1 uuid; r1 uuid;
  res text := '';
  fails int := 0;
  v text; n1 int; n2 int; ok boolean;
  fut timestamptz := now() + interval '3 days';
begin
  select array_agg(id) into ids from (select id from public.profiles order by created_at limit 3) p;
  if coalesce(array_length(ids,1),0) < 3 then raise exception 'La prueba necesita al menos 3 perfiles'; end if;
  a := ids[1]; b := ids[2]; c := ids[3];
  select id into sp from public.sports order by name limit 1;
  if sp is null then raise exception 'La prueba necesita al menos 1 deporte'; end if;

  ------------------------------------------------------------------ validaciones al crear
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role','authenticated')::text, true);
  set local role authenticated;

  begin perform public.create_challenge(a, sp, fut); v := null;
  exception when others then v := sqlerrm; end;
  if v = 'Rival inválido' then res := res || E'OK    01 no puedes retarte a ti mismo\n';
  else res := res || E'FALLO 01 retarse a si mismo: ' || coalesce(v,'lo permitio') || E'\n'; fails := fails + 1; end if;

  begin perform public.create_challenge(b, sp, now() - interval '1 day'); v := null;
  exception when others then v := sqlerrm; end;
  if v = 'La fecha del reto debe ser futura' then res := res || E'OK    02 fecha pasada rechazada\n';
  else res := res || E'FALLO 02 fecha pasada: ' || coalesce(v,'la permitio') || E'\n'; fails := fails + 1; end if;

  begin perform public.create_challenge(b, sp, fut, null, 'DIRECT', 0); v := null;
  exception when others then v := sqlerrm; end;
  if v = 'Los puntos deben estar entre 1 y 5000' then res := res || E'OK    03 puntos fuera de rango rechazados\n';
  else res := res || E'FALLO 03 puntos 0: ' || coalesce(v,'los permitio') || E'\n'; fails := fails + 1; end if;

  begin perform public.create_challenge(b, sp, fut, null, 'DIRECT', 999999); v := null;
  exception when others then v := sqlerrm; end;
  if v = 'Los puntos deben estar entre 1 y 5000' then res := res || E'OK    04 puntos demasiado altos rechazados\n';
  else res := res || E'FALLO 04 puntos 999999: ' || coalesce(v,'los permitio') || E'\n'; fails := fails + 1; end if;

  begin perform public.create_challenge(gen_random_uuid(), sp, fut); v := null;
  exception when others then v := sqlerrm; end;
  if v = 'Rival no encontrado' then res := res || E'OK    05 rival inexistente rechazado\n';
  else res := res || E'FALLO 05 rival inexistente: ' || coalesce(v,'lo permitio') || E'\n'; fails := fails + 1; end if;

  ------------------------------------------------------------------ crear reto y permisos
  ch1 := public.create_challenge(b, sp, fut);
  ch2 := public.create_challenge(b, sp, fut + interval '1 day');
  reset role;

  select count(*) into n1 from public.challenge_invitations where challenge_id = ch1 and invitee_id = b and status = 'pending';
  select status into v from public.challenges where id = ch1;
  if n1 = 1 and v = 'open' then res := res || E'OK    06 reto creado abierto con una invitacion pendiente para el rival\n';
  else res := res || E'FALLO 06 creacion: estado=' || coalesce(v,'?') || ', invitaciones=' || n1 || E'\n'; fails := fails + 1; end if;

  -- el creador y un tercero no pueden responder la invitacion
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role','authenticated')::text, true);
  set local role authenticated;
  begin perform public.respond_to_challenge(ch1, 'ACCEPTED'); v := null; exception when others then v := sqlerrm; end;
  reset role;
  if v like 'No hay una invitación pendiente%' then res := res || E'OK    07 el creador no puede aceptar su propio reto\n';
  else res := res || E'FALLO 07 creador acepta su reto: ' || coalesce(v,'lo permitio') || E'\n'; fails := fails + 1; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role','authenticated')::text, true);
  set local role authenticated;
  begin perform public.respond_to_challenge(ch1, 'ACCEPTED'); v := null; exception when others then v := sqlerrm; end;
  reset role;
  if v like 'No hay una invitación pendiente%' then res := res || E'OK    08 un tercero no puede aceptar el reto\n';
  else res := res || E'FALLO 08 tercero acepta: ' || coalesce(v,'lo permitio') || E'\n'; fails := fails + 1; end if;

  -- solo el creador cancela
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role','authenticated')::text, true);
  set local role authenticated;
  begin perform public.cancel_challenge(ch2); v := null; exception when others then v := sqlerrm; end;
  reset role;
  if v = 'No autorizado' then res := res || E'OK    09 el rival no puede cancelar el reto de otro\n';
  else res := res || E'FALLO 09 cancelar ajeno: ' || coalesce(v,'lo permitio') || E'\n'; fails := fails + 1; end if;

  -- cancelar de verdad
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role','authenticated')::text, true);
  set local role authenticated;
  perform public.cancel_challenge(ch2);
  reset role;
  select status into v from public.challenges where id = ch2;
  select count(*) into n1 from public.challenge_invitations where challenge_id = ch2 and status = 'cancelled';
  if v = 'cancelled' and n1 = 1 then res := res || E'OK    10 cancelar deja el reto y su invitacion en "cancelado"\n';
  else res := res || E'FALLO 10 cancelar: reto=' || coalesce(v,'?') || ', invitaciones canceladas=' || n1 || E'\n'; fails := fails + 1; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role','authenticated')::text, true);
  set local role authenticated;
  begin perform public.respond_to_challenge(ch2, 'ACCEPTED'); v := null; exception when others then v := sqlerrm; end;
  reset role;
  if v is not null then res := res || E'OK    11 no se puede aceptar un reto cancelado\n';
  else res := res || E'FALLO 11 acepto un reto cancelado\n'; fails := fails + 1; end if;

  ------------------------------------------------------------------ aceptar y partido
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role','authenticated')::text, true);
  set local role authenticated;
  perform public.respond_to_challenge(ch1, 'ACCEPTED');
  reset role;

  select count(*) into n1 from public.challenge_participants where challenge_id = ch1 and status = 'accepted';
  select id into m1 from public.matches where challenge_id = ch1 limit 1;
  if n1 = 2 and m1 is not null then res := res || E'OK    12 al aceptar hay 2 participantes y se crea el partido\n';
  else res := res || E'FALLO 12 aceptar: participantes=' || n1 || ', partido=' || coalesce(m1::text,'no existe') || E'\n'; fails := fails + 1; end if;

  ------------------------------------------------------------------ resultado
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role','authenticated')::text, true);
  set local role authenticated;
  begin perform public.submit_match_result(ch1, '6-4', '6-3', null, c); v := null; exception when others then v := sqlerrm; end;
  reset role;
  if v is not null then res := res || E'OK    13 alguien ajeno al reto no puede enviar resultado\n';
  else res := res || E'FALLO 13 un ajeno envio resultado\n'; fails := fails + 1; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role','authenticated')::text, true);
  set local role authenticated;
  begin perform public.submit_match_result(ch1, '6-4', '6-3', null, c); v := null; exception when others then v := sqlerrm; end;
  if v = 'Winner must be a participant' then res := res || E'OK    14 el ganador debe ser uno de los dos jugadores\n';
  else res := res || E'FALLO 14 ganador ajeno: ' || coalesce(v,'lo permitio') || E'\n'; fails := fails + 1; end if;

  r1 := public.submit_match_result(ch1, '6-4', '6-3', null, a);
  reset role;
  select status into v from public.match_results where id = r1;
  if v = 'pending' then res := res || E'OK    15 el resultado enviado queda pendiente de confirmar\n';
  else res := res || E'FALLO 15 estado del resultado: ' || coalesce(v,'?') || E'\n'; fails := fails + 1; end if;

  select count(*) into n1 from public.notifications where profile_id = b and type = 'match_result_submitted' and source_id = m1;
  if n1 >= 1 then res := res || E'OK    16 el rival recibe notificacion del resultado\n';
  else res := res || E'FALLO 16 sin notificacion de resultado para el rival\n'; fails := fails + 1; end if;

  -- quien envia no puede confirmar su propio resultado
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role','authenticated')::text, true);
  set local role authenticated;
  begin perform public.confirm_match(m1); v := null; exception when others then v := sqlerrm; end;
  if v = 'Submitter cannot review own result' then res := res || E'OK    17 quien reporta no puede confirmar su propio resultado\n';
  else res := res || E'FALLO 17 autoconfirmacion: ' || coalesce(v,'la permitio') || E'\n'; fails := fails + 1; end if;

  begin perform public.cancel_challenge(ch1); v := null; exception when others then v := sqlerrm; end;
  reset role;
  if v like 'El reto ya tiene un resultado%' then res := res || E'OK    18 un reto con resultado no se puede cancelar\n';
  else res := res || E'FALLO 18 cancelar con resultado: ' || coalesce(v,'lo permitio') || E'\n'; fails := fails + 1; end if;

  -- disputa y reenvio por el rival
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role','authenticated')::text, true);
  set local role authenticated;
  perform public.review_challenge_result(r1, false);
  reset role;
  select status into v from public.match_results where id = r1;
  if v = 'disputed' then res := res || E'OK    19 el rival puede disputar el resultado\n';
  else res := res || E'FALLO 19 disputa: ' || coalesce(v,'?') || E'\n'; fails := fails + 1; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role','authenticated')::text, true);
  set local role authenticated;
  perform public.submit_match_result(ch1, '4-6', '3-6', null, b);
  reset role;
  select status into v from public.match_results where id = r1;
  if v = 'pending' then res := res || E'OK    20 tras la disputa el rival puede enviar el marcador que cree correcto\n';
  else res := res || E'FALLO 20 reenvio tras disputa: ' || coalesce(v,'?') || E'\n'; fails := fails + 1; end if;

  ------------------------------------------------------------------ confirmar y premio
  select count(*) into n1 from public.dynasty_cards;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role','authenticated')::text, true);
  set local role authenticated;
  perform public.confirm_match(m1);
  reset role;
  select count(*) into n2 from public.dynasty_cards;

  select status into v from public.challenges where id = ch1;
  if v = 'completed' then res := res || E'OK    21 al confirmar el reto queda completado\n';
  else res := res || E'FALLO 21 estado final del reto: ' || coalesce(v,'?') || E'\n'; fails := fails + 1; end if;

  if n2 = n1 + 1 then res := res || E'OK    22 al confirmar se entrega exactamente 1 carta nueva (' || n1 || ' -> ' || n2 || E')\n';
  else res := res || E'FALLO 22 cartas antes=' || n1 || ', despues=' || n2 || E' (se esperaba +1)\n'; fails := fails + 1; end if;

  select count(*) into n1 from public.notifications where source_id = m1 and type = 'match_result_confirmed';
  if n1 >= 2 then res := res || E'OK    23 los dos jugadores reciben aviso de resultado confirmado\n';
  else res := res || E'FALLO 23 avisos de confirmacion=' || n1 || E'\n'; fails := fails + 1; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role','authenticated')::text, true);
  set local role authenticated;
  begin perform public.submit_match_result(ch1, '6-0', '6-0', null, b); v := null; exception when others then v := sqlerrm; end;
  reset role;
  if v is not null then res := res || E'OK    24 un resultado confirmado no se puede reescribir\n';
  else res := res || E'FALLO 24 reescribio un resultado confirmado\n'; fails := fails + 1; end if;

  ------------------------------------------------------------------ informativo
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role','authenticated')::text, true);
  set local role authenticated;
  ch3 := public.create_challenge(b, sp, fut);
  begin perform public.create_challenge(b, sp, fut); v := 'permite duplicados';
  exception when others then v := 'bloquea duplicados (' || sqlerrm || ')'; end;
  reset role;
  res := res || E'INFO  25 retos duplicados abiertos con el mismo rival y fecha: ' || v || E'\n';

  res := res || E'\nRESUMEN: ' || case when fails = 0 then 'TODO OK' else fails || ' FALLO(S)' end || E'\n';
  raise exception E'RESULTADOS\n%', res;   -- deshace todo a proposito
end $$;
