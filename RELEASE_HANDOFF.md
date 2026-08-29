# CHALLENGE DYNASTY — RELEASE HANDOFF

## Objetivo
Tomar el release candidate local y convertirlo en deployment real.

## Lo que ya está verificado
- 41 rutas
- 5/5 checks locales: routes, SQL contract, core flow, production, hardening
- 13/13 invariantes de base de datos PASS
- 16/16 RPC usados por UI existen en Supabase
- 23/23 tablas principales existen en Supabase
- 83+ archivos TS/TSX auditados sin errores de sintaxis (última pasada)
- inventario/POS/Marketplace/Tournaments/Partners/Skills/AI context endurecidos

## Variables de entorno
### Públicas
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY

### Secretas opcionales según módulo
DYNASTY_AI_PROVIDER_API_KEY

Nunca colocar secretos de servidor en variables NEXT_PUBLIC_*.

## Orden de release
1. Sincronizar el contenido de este ZIP con el repositorio `9dstoreco-wq/challenge-dynasty`.
2. Verificar que exista `.github/workflows/production-gate.yml`.
3. Verificar las variables de entorno en Vercel Preview y Production.
4. Ejecutar `npm install --no-audit --no-fund`.
5. Ejecutar `npm run verify:release`.
6. Ejecutar autenticación y E2E sobre un entorno de prueba.
7. Configurar proveedor de pagos y webhooks en sandbox.
8. Hacer deploy a Vercel.
9. Ejecutar smoke test de rutas públicas y autenticadas.
10. Solo después marcar Production Ready.

## Bloqueos conocidos de esta sesión
- La integración GitHub devuelve HTTP 403 en operaciones de escritura, aunque el repositorio reporte permisos de push.
- La cuenta/equipo Vercel conectado no expone un proyecto Dynasty visible.
- Esta sesión no pudo completar una instalación fresca de npm por timeout de resolución de dependencias.
- No se han conectado webhooks de un proveedor de pagos real.
- No se ha completado E2E autenticado con identidades de prueba reales.
- La excepción administrada de PostGIS `spatial_ref_sys` permanece abierta.

## Regla
No declarar producción certificada hasta que los bloqueos anteriores estén resueltos y verificables.

## RELEASE DOCTOR
Run from the project root:
`npm run release-doctor`

Behavior:
- validates Node 20+ (CI remains pinned to Node 20)
- validates npm
- validates NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY
- validates release scripts/workflow
- requires node_modules or package-lock.json
- runs routes, SQL, core flow, production, hardening, typecheck and build
- fails fast with an explicit reason

Current session result:
Node/npm PASS; environment variables unavailable, so the doctor correctly stopped before dependency/build steps.
