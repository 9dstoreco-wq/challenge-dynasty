# CHALLENGE DYNASTY — FINAL LOCAL AUDIT 2026-08-28

## Estado
Release candidate corregido a partir del ZIP entregado el 2026-08-28.

## Gates estructurales verificados en este runtime
- Route contract: PASS — 48 rutas.
- SQL/source contract: PASS.
- Core flow: PASS.
- Production structure: PASS.
- Hardening: PASS.
- Import sanity contract: PASS (delegado a typecheck/build; resolver local revisado).

## Correcciones integradas
- Normalización de `params`/`searchParams` como Promises en rutas dinámicas de Next.js 15.
- Correcciones de metadata y tipos en Challenge.
- Correcciones de rutas dinámicas de Shop, usuario, tricks y competitions.
- Restauración de workflows `challenge-dynasty-ci.yml` y `production-gate.yml`.
- Eliminación de marcadores temporales de sesión/build.
- Reparación de texto UTF-8 mojibake en archivos activos.
- Scripts de finalización Windows preparados para ejecutar instalación, verificación, typecheck y build de forma secuencial y fail-fast.

## Typecheck / build en este runtime
NO CERTIFICADOS aquí. El ZIP no contiene `node_modules`; se intentó instalar dependencias con `npm ci`, pero el runtime no pudo descargar todas las dependencias desde npm y agotó el tiempo de ejecución. No se registra ningún falso PASS.

## Cómo cerrar los dos gates locales restantes en Windows
Ejecutar `FINALIZAR_WINDOWS.bat` desde esta carpeta. El script ejecuta, en orden:
1. `npm ci --no-audit --no-fund`
2. `npm run verify-all`
3. `npm run typecheck`
4. `npm run build`

Si cualquiera falla, el script se detiene y no declara el proyecto finalizado.

## Gates externos posteriores
- Push/CI real en GitHub.
- Deployment y verificación en Vercel.
- E2E autenticado con identidades de prueba reales.
- Sandbox/webhooks del proveedor de pagos.
- Fiscal/e-invoicing compliance.
- Verificación final del proyecto Supabase de producción.

## Regla de certificación
Hasta que Windows ejecute correctamente `npm ci`, `verify-all`, `typecheck` y `build`, esta versión debe llamarse **release candidate corregido**, no 100% production-certified.
