import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// CHALLENGE DYNASTY -- Mercado Pago payment webhook (platform-wide).
//
// This is the platform's single payment webhook: Wompi was removed (merchant account
// blocked on a Camara de Comercio renewal that wasn't worth chasing), so Mercado Pago is
// the only payment provider now. Receives payment notifications for every domain and
// routes by the `dyn:<domain>:<row_id>` reference convention set as `external_reference`
// when the preference is created (see lib/dynasty/mercadopago.ts). The webhook body only
// carries a payment id -- the actual status has to be fetched from /v1/payments/{id}.
//
// Needs two Supabase Edge Function secrets set from the Mercado Pago developer panel
// (Tus integraciones > <app> > Webhooks):
//   MERCADOPAGO_ACCESS_TOKEN    -- same access token used to create preferences; also used
//                                  here to authenticate the GET /v1/payments/{id} call.
//   MERCADOPAGO_WEBHOOK_SECRET  -- the per-application "Clave secreta" shown on that same
//                                  Webhooks screen. NOT the access token -- a separate value.
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are injected automatically.
//
// For the `booking` domain this calls `apply_payment_result`, the hardened SECURITY
// DEFINER RPC that validates the amount against `bookings` directly (see the comment on
// resolveBooking in lib/dynasty/checkout-resolvers.ts for why it reads from `bookings` and
// not `booking_payment_records`). Other domains call their own hardened confirm_* RPC
// where one exists (shop, marketplace, tournament); `billing` has no dedicated RPC yet, so
// it keeps a direct table update for that domain.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, x-signature, x-request-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

type Domain = "shop" | "booking" | "tournament" | "marketplace" | "billing";

// Mercado Pago's own vocabulary (approved/rejected/in_process/pending/authorized/
// cancelled/refunded/charged_back) collapsed to the subset every downstream RPC/CHECK
// constraint actually allows. Deliberately never emits 'cancelled': apply_payment_result's
// non-paid branch does `bookings.payment_status = p_status` for 'failed' or 'cancelled',
// but bookings_payment_status_check has no 'cancelled' value -- only this function's own
// vocabulary keeps that call from ever violating that constraint.
function normalizeStatus(mpStatus: string): "paid" | "pending" | "failed" | "refunded" {
  if (mpStatus === "approved") return "paid";
  if (mpStatus === "refunded" || mpStatus === "charged_back") return "refunded";
  if (mpStatus === "rejected" || mpStatus === "cancelled") return "failed";
  return "pending"; // in_process, pending, authorized, in_mediation, ...
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  const webhookSecret = Deno.env.get("MERCADOPAGO_WEBHOOK_SECRET");
  const accessToken = Deno.env.get("MERCADOPAGO_ACCESS_TOKEN");
  if (!webhookSecret) return json({ error: "MERCADOPAGO_WEBHOOK_SECRET_MISSING" }, 500);
  if (!accessToken) return json({ error: "MERCADOPAGO_ACCESS_TOKEN_MISSING" }, 500);

  const url = new URL(req.url);
  const body = await req.json().catch(() => null);
  if (!body || typeof body !== "object") return json({ error: "INVALID_JSON" }, 400);

  // Mercado Pago sends the resource id both as a `data.id` query param and in the JSON
  // body's `data.id` -- the signature manifest is defined over the query-param form.
  const dataIdRaw = url.searchParams.get("data.id") ?? (body?.data as Record<string, unknown> | undefined)?.id;
  const dataId = typeof dataIdRaw === "string" ? dataIdRaw : String(dataIdRaw ?? "");
  const topic = url.searchParams.get("type") ?? url.searchParams.get("topic") ?? String(body?.type ?? "");

  const signatureHeader = req.headers.get("x-signature") ?? "";
  const requestId = req.headers.get("x-request-id") ?? "";
  if (!signatureHeader || !dataId) return json({ error: "MISSING_SIGNATURE_OR_DATA_ID" }, 400);

  const parts = Object.fromEntries(
    signatureHeader.split(",").map((kv) => {
      const [k, ...rest] = kv.trim().split("=");
      return [k, rest.join("=")];
    })
  );
  const ts = parts["ts"] ?? "";
  const providedV1 = parts["v1"] ?? "";
  if (!ts || !providedV1) return json({ error: "MALFORMED_SIGNATURE_HEADER" }, 400);

  // Manifest per Mercado Pago's documented template: id:<data.id>;request-id:<x-request-id>;ts:<ts>;
  // data.id must be lowercased when it's an alphanumeric (not purely numeric) id.
  const normalizedDataId = /^[0-9]+$/.test(dataId) ? dataId : dataId.toLowerCase();
  const manifest = `id:${normalizedDataId};request-id:${requestId};ts:${ts};`;
  const computedV1 = await hmacSha256Hex(webhookSecret, manifest);

  if (!timingSafeEqual(computedV1, providedV1)) {
    console.error("mercadopago-webhook: signature mismatch", { manifest });
    return json({ error: "INVALID_SIGNATURE" }, 401);
  }

  if (topic !== "payment") {
    // Acknowledge everything else (merchant_order, point_integration_wh, ...) so Mercado
    // Pago doesn't retry it, but there's nothing to route yet.
    return json({ ok: true, ignored: topic || "unknown" });
  }

  const paymentRes = await fetch(`https://api.mercadopago.com/v1/payments/${encodeURIComponent(dataId)}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!paymentRes.ok) {
    console.error("mercadopago-webhook: payment lookup failed", paymentRes.status);
    return json({ error: "PAYMENT_LOOKUP_FAILED" }, 502);
  }
  const payment = await paymentRes.json();

  const reference = String(payment?.external_reference ?? "");
  const mpStatus = String(payment?.status ?? "");
  const providerPaymentId = String(payment?.id ?? dataId);
  const amount = Number(payment?.transaction_amount ?? 0);
  const currencyCode = String(payment?.currency_id ?? "COP").toUpperCase();
  const status = normalizeStatus(mpStatus);

  const refParts = reference.split(":");
  if (refParts.length !== 3 || refParts[0] !== "dyn") {
    console.error("mercadopago-webhook: unrecognized reference format", reference);
    return json({ ok: true, unrouted: reference });
  }
  const domain = refParts[1] as Domain;
  const rowId = refParts[2];

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return json({ error: "SUPABASE_CONFIG_MISSING" }, 500);
  const supabase = createClient(supabaseUrl, serviceKey);

  // Every delivery Mercado Pago sends carries its own top-level `id` -- use that (not the
  // payment id, which stays the same across retried deliveries for the same payment) as the
  // idempotency key the hardened RPCs de-dupe on.
  const providerEventId = String((body as Record<string, unknown>)?.id ?? `${dataId}:${ts}`);

  try {
    switch (domain) {
      case "booking": {
        const { error } = await supabase.rpc("apply_payment_result", {
          p_provider: "mercadopago",
          p_provider_payment_id: providerPaymentId,
          p_provider_event_id: providerEventId,
          p_booking_id: rowId,
          p_amount: amount,
          p_currency_code: currencyCode,
          p_status: status === "refunded" ? "refunded" : status,
          p_raw_payload: payment,
        });
        if (error) throw error;
        break;
      }
      case "shop": {
        if (status !== "paid") break; // confirm_shop_order_payment is success-only.
        const { error } = await supabase.rpc("confirm_shop_order_payment", {
          p_order_id: rowId,
          p_provider: "mercadopago",
          p_provider_payment_id: providerPaymentId,
          p_provider_event_id: providerEventId,
          p_amount: amount,
          p_currency_code: currencyCode,
          p_raw_payload: payment,
        });
        if (error) throw error;
        break;
      }
      case "marketplace": {
        if (status !== "paid") break; // confirm_marketplace_payment is success-only.
        const { error } = await supabase.rpc("confirm_marketplace_payment", {
          p_order_id: rowId,
          p_provider: "mercadopago",
          p_provider_payment_id: providerPaymentId,
          p_provider_event_id: providerEventId,
          p_amount: amount,
          p_currency_code: currencyCode,
        });
        if (error) throw error;
        break;
      }
      case "tournament": {
        if (status !== "paid") break; // confirm_tournament_registration_payment is success-only.
        const { error } = await supabase.rpc("confirm_tournament_registration_payment", {
          p_entry_id: rowId,
          p_amount_paid: amount,
        });
        if (error) throw error;
        break;
      }
      case "billing": {
        // No dedicated confirm_* RPC exists yet for billing invoices -- direct table
        // update for this domain until one exists.
        const { error } = await supabase
          .from("billing_invoices")
          .update({
            status: status === "paid" ? "paid" : status === "failed" ? "failed" : "open",
            amount_paid: status === "paid" ? amount : 0,
            provider_name: "mercadopago",
            provider_invoice_reference: providerPaymentId,
            paid_at: status === "paid" ? new Date().toISOString() : null,
          })
          .eq("id", rowId);
        if (error) throw error;
        break;
      }
      default:
        console.error("mercadopago-webhook: unknown reference domain", domain, reference);
        return json({ ok: true, unrouted: reference });
    }
  } catch (err) {
    console.error("mercadopago-webhook: RPC/DB update failed", domain, rowId, err instanceof Error ? err.message : err);
    return json({ error: "DB_UPDATE_FAILED" }, 500);
  }

  return json({ ok: true });
});
