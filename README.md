# CHALLENGE DYNASTY — MONTAJE SIMPLE

Esta es la versión consolidada y simplificada para montar CHALLENGE DYNASTY.

## Qué tienes que hacer tú

Solo 4 cosas:

1. Crear una cuenta/proyecto gratuito en Supabase.
2. En Supabase → SQL Editor, pegar y ejecutar **una sola vez**: `supabase/schema_master.sql`.
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

Usa únicamente `supabase/schema_master.sql`.

## Producción

Primero prueba localmente. Cuando ya funcione, puedes desplegar este mismo proyecto en Vercel y añadir las mismas 2 variables de entorno.

El auto-confirmado de resultados de 12 horas queda preparado en SQL como:

```sql
select public.auto_confirm_due_matches();
```

Para producción se programa en Supabase cuando ya estemos usando resultados reales.

## CORE FUNCTIONAL 5
Esta iteración agrega settings/pasaporte, búsqueda, historial competitivo, Skill Challenges completos, cancelación de retos, rating ELO con historial, bloqueos, reportes y límites básicos de abuso. Ejecuta `npm run check-routes`, `npm run check-sql`, `npm run check-core-flow` y `node scripts/check-hardening.mjs` antes de desplegar.

## Certificación técnica

Consulta `CERTIFICACION_TECNICA_7.txt` para ver qué validaciones fueron ejecutadas y cuáles permanecen bloqueadas por la disponibilidad del entorno de npm.
