# Registro maestro de cuentas de pago (Wompi y otras)

Este archivo es el "centro maestro" de cuentas de pago del ecosistema DINASTY/Padelito.
Objetivo: que nunca dos plataformas compartan el mismo comercio/llaves de una pasarela de
pago sin querer (eso rompe el webhook del otro, porque cada comercio Wompi solo admite UNA
URL de eventos). Cada vez que se abra o cambie una cuenta de pago para cualquier proyecto,
este archivo se actualiza en el mismo momento.

No contiene valores reales de llaves/secretos -- solo qué cuenta existe, para qué
plataforma, dónde vive la credencial (nombre de la variable y dónde está guardada) y en
qué estado (prueba/producción).

---

## 1. Padelito Shop (Shopify) -- comercio Wompi #1

- **Plataforma:** tienda Shopify, sup0y9-t3.myshopify.com
- **Dónde se configura:** Shopify Admin -> Configuración -> Pagos -> Wompi (app nativa de
  Shopify, no vive en ningún repo de código)
- **Webhook de eventos:** gestionado internamente por la integración de Shopify con Wompi;
  no es un endpoint nuestro, no lo tocamos desde fuera de Shopify
- **Estado:** PRODUCCIÓN (modo de prueba desactivado el 2026-10-12)
- **Métodos habilitados:** Visa, Mastercard, American Express, Bancolombia, Nequi,
  DaviPlata, PSE
- **Comisión:** 2% cargo de Shopify por proveedor externo + comisiones propias de Wompi
- Otro proveedor en la misma tienda: PayPal, con "Configuración incompleta" (pendiente,
  sin relación con Wompi)

## 2. Challenge Dynasty (Next.js + Supabase) -- comercio Wompi #2 (separado del #1)

- **Plataforma:** app Challenge Dynasty, repo 9dstoreco-wq/challenge-dynasty, proyecto
  Vercel challenge-dynasty-final-2026
- **Checkout (cliente + firma de integridad):**
  - `NEXT_PUBLIC_WOMPI_PUBLIC_KEY` -- Vercel env var (Production/Preview/Development)
  - `WOMPI_INTEGRITY_SECRET` -- Vercel env var, server-only (nunca con prefijo
    NEXT_PUBLIC_)
  - Código: `lib/dynasty/wompi.ts`, `app/api/checkout/wompi/route.ts`,
    `components/WompiCheckoutButton.tsx`
- **Webhook de eventos:** función de Supabase Edge Function `wompi-webhook` (proyecto
  Supabase "Challenge Dynasty", ref ggkthvewxmsmtupjzfnk) -- URL propia, nada que ver con
  la de Shopify
  - `WOMPI_EVENTS_SECRET` -- Supabase Edge Function secret (verifica el checksum del
    evento)
  - `WOMPI_PUBLIC_KEY` -- Supabase Edge Function secret (mismo valor que la llave pública
    del checkout, se usa como Bearer token para confirmar la transacción contra la API de
    Wompi)
  - Código: `supabase/functions/wompi-webhook/index.ts`
- **Dominios cubiertos por este webhook:** shop, booking, tournament, marketplace, billing
  (convención de referencia `dyn:<domain>:<row_id>`)
- **Estado actual (verificado 2026-10-12):** SANDBOX/PRUEBA -- `NEXT_PUBLIC_WOMPI_PUBLIC_KEY`
  en Vercel está anotada explícitamente como "sandbox/test... swap to pub_prod_... once
  tested and Luis approves going live". NINGÚN cobro real se procesa todavía en Challenge
  Dynasty.
- **Antes de pasar a producción aquí:** (1) confirmar que este comercio Wompi es distinto
  al de Shopify (NIT puede ser el mismo negocio, pero comercio/llaves diferentes); (2)
  probar el flujo completo en sandbox (checkout + webhook recibido + estado actualizado en
  Supabase) con Luis presente; (3) solo entonces reemplazar las 4 credenciales de
  sandbox por las de producción (`pub_prod_...` etc.), nunca antes.
- **Nota histórica:** hubo una integración Wompi anterior, retirada el 2026-09-29 por un
  problema de renovación de Cámara de Comercio con esa cuenta vieja. La actual (desde
  2026-10-09) es un comercio nuevo. El código de ePayco (proveedor anterior) se dejó en el
  repo sin usar, como respaldo (`lib/dynasty/epayco.ts`,
  `app/api/checkout/epayco/route.ts`, `supabase/functions/epayco-webhook`).

## Regla general (para cualquier cuenta de pago futura)

1. Cada plataforma nueva (app, tienda, landing) que cobre con Wompi necesita su **propio
   comercio** -- nunca reutilizar las llaves de otra plataforma, aunque sea el mismo NIT.
2. Antes de activar cobros reales en cualquier plataforma, probar el flujo completo en modo
   sandbox/prueba y confirmar con Luis explícitamente.
3. Actualizar esta tabla el mismo día que se abra, cambie o active una cuenta.
