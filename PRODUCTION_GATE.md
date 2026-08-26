# CHALLENGE DYNASTY — PRODUCTION GATE

## Objetivo
Cerrar la certificación de producción en un entorno con acceso completo a npm.

## Orden obligatorio
1. `npm install`
2. `npm run typecheck`
3. `npm run build`
4. `npm run check-routes`
5. `npm run check-sql`
6. `npm run check-core-flow`
7. `npm run check-production`
8. `npm run check-hardening`

## Flujos E2E mínimos
- Registro / login
- Onboarding
- Crear reto
- Recibir invitación
- Aceptar/rechazar reto
- Creación automática del match
- Enviar resultado
- Confirmar resultado
- Disputar resultado
- Notificaciones

## Criterio de cierre
La aplicación solo se marca como 100% certificada cuando:
- `typecheck` = PASS
- `build` = PASS
- todos los checks = PASS
- los flujos E2E anteriores funcionan contra Supabase real

## Estado actual
Todos los checks ejecutables en este entorno pasan. La instalación de dependencias/npm impide certificar todavía `typecheck` y `build` en este entorno.
