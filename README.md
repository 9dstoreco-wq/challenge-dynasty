# CHALLENGE DYNASTY — MONTAJE SIMPLE

Esta es la versión consolidada y simplificada para montar CHALLENGE DYNASTY.

## Qué tienes que hacer tú

Solo 4 cosas:

1. Crear una cuenta/proyecto gratuito en Supabase.
2. En Supabase → SQL Editor, pegar y ejecutar **una sola vez**: `supabase/schema_master.sql`.
   Este archivo es una foto exacta de la base de datos en vivo tomada el **2026-10-08**
   (generada por introspección directa de producción, no escrita a mano) — verificado
   corriéndolo completo contra un Postgres limpio antes de entregarlo. Si en
   `supabase/migrations/` hay archivos con fecha **posterior** a esa, hay que correrlos
   también, uno por uno y en orden de fecha, después de `schema_master.sql`.
3. Copiar `.env.example` como `.env.local` y pegar las 2 claves de Supabase.
4. Ejecutar:

```bash
npm install
npm run dev
```

Después abre `http://localhost:3000`.

## Las 2 claves

En Supabase: **Project Settings → API**.

- Project URL → `NEXT_PUBLIC_SUPABASE_URL`
- anon public key → `NEXT_PUBLIC_SUPABASE_ANON_KEY`

**Nunca pongas una service_role key en `.env.local` ni en el navegador.**

## Qué hace la versión

- Multi-deporte desde el núcleo.
- Registro, login y onboarding.
- Perfiles / pasaporte deportivo.
- Crear reto.
- Invitación virtual.
- Aceptar/rechazar reto.
- Resultado y confirmación.
- Ranking por deporte.
- Feed social y post automático de resultado.
- Skills / retos de trucos por deporte.
- Partners y dobles.
- Temporadas, misiones y recompensas.
- Estructura para clubes, competiciones y notificaciones.

## Importante

No ejecutes ninguna migración antigua de V7, V8, V9 o V9.1.

Para un proyecto nuevo, usa `supabase/schema_master.sql` como punto de partida (ver el
encabezado del archivo para el detalle de qué incluye y qué no). Los archivos en
`supabase/migrations/` de ahí en adelante son el historial de cambios *nuevos* — no una forma
alternativa de montar el proyecto desde cero.

## Producción

Primero prueba localmente. Cuando ya funcione, puedes desplegar este mismo proyecto en Vercel y añadir las mismas 2 variables de entorno.

El auto-confirmado de resultados ya corre en producción: `public.expire_stale_challenge_disputes()`
(definida en `supabase/migrations/20261007210000_dispute_timeout_and_card_caps.sql`) auto-confirma
con la última versión registrada cualquier resultado `pending` o `disputed` sin movimiento por más
de 48 horas, y está programada en Supabase como cron job cada 15 minutos (confirmado en vivo:
`select jobname,schedule,active from cron.job`). La función más vieja
`public.auto_confirm_due_match_results()` (ventana de 12 horas, solo cubre `pending`) sigue
existiendo en el esquema pero no está programada — quedó superada por la de arriba, que además
cubre el caso `disputed` (el ciclo de disputa que antes podía quedar atascado para siempre).

## CORE FUNCTIONAL 5
Esta iteración agrega settings/pasaporte, búsqueda, historial competitivo, Skill Challenges completos, cancelación de retos, rating ELO con historial, bloqueos, reportes y límites básicos de abuso. Ejecuta `npm run check-routes`, `npm run check-sql`, `npm run check-core-flow` y `node scripts/check-hardening.mjs` antes de desplegar.

## Certificación técnica

Consulta `CERTIFICACION_TECNICA_7.txt` para ver qué validaciones fueron ejecutadas y cuáles permanecen bloqueadas por la disponibilidad del entorno de npm.

## Release truth

V17 is the only master source. The real Supabase project is the backend source of truth. This bundle does not contain service-role secrets. The final release gate must run in the connected GitHub/Vercel environment because this audit environment cannot complete npm dependency resolution.

See `SUPABASE_REAL_CONTRACT.md` for the live backend contract and the distinction between production truth and bundled offline SQL.
