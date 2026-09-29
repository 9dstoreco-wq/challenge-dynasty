import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// CHALLENGE DYNASTY -- ePayco payment webhook (platform-wide).
//
// This is the platform's payment webhook. Mercado Pago was replaced by ePayco as the
// platform's payment provider (2026-09-29). Receives the "confirmation" callback ePayco
// posts after a transaction settles and routes by the `dyn:<domain>:<row_id>` reference
// convention set as both `invoice` and `extra1` when the checkout widget is opened (see
// components/EpaycoCheckoutButton.tsx / lib/dynasty/epayco.ts). Unlike Mercado Pago's
// webhook (which only carries a payment id and requires a follow-up GET to fetch the real
// status), ePayco's confirmation POST carries the full transaction data directly, signed
// with `x_signature` -- no follow-up API call needed to trust it.
//
// Needs two Supabase Edge Function secrets, both from the ePayco dashboard's "Mi ePayco"
// page (NOT the same as the checkout public key):
//   EPAYCO_P_CUST_ID_CLIENTE  -- "Identificacion del cliente" / customer id shown there.
//   EPAYCO_P_KEY              -- the "P_KEY" / llave secreta shown on the same page.
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are injected automatically.
//
// For the `booking` domain this calls `apply_payment_result`, the hardened SECURITY
// DEFINER RPC that validates the amount against `bookings` directly (see the comment on
// resolveBooking in lib/dynasty/checkout-resolvers.ts for why it reads from `bookings` and
// not `booking_payment_records`). Other domains call their own hardened confirm_* RPC
// where one exists (shop, marketplace, tournament); `billing` has no dedicated RPC yet, so
// it keeps a direct table update for that domain -- same shape as the previous Mercado
// Pago webhook used for all of the above, just re-pointed at ePayco's own field names.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

async function sha256Hex(message: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(message));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

type Domain = "shop" | "booking" | "tournament" | "marketplace" | "billing";

// ePayco sends both a numeric `x_cod_response` (1 Aceptada / 2 Rechazada / 3 Pendiente /
// 4 Fallida) and a localized `x_response` text -- prefer the numeric code, fall back to
// matching the text when the code is missing/unrecognized.
function normalizeStatus(codResponse: string, responseText: string): "paid" | "pending" | "failed" | "refunded" {
  const code = codResponse.trim();
  if (code === "1") return "paid";
  if (code === "2") return "failed";
  if (code === "3") return "pending";
  if (code === "4") return "failed";

  const text = responseText.toLowerCase();
  if (text.includes("aceptada") || text.includes("accepted") || text.includes("approved")) return "paid";
  if (text.includes("reembols") || text.includes("refund")) return "refunded";
  if (text.includes("rechazada") || text.includes("rejected") || text.includes("fallida") || text.includes("failed")) {
    return "failed";
  }
  return "pending";
}

// Parses either a classic ePayco `application/x-www-form-urlencoded` confirmation POST or a
// JSON body, returning a flat string map either way.
async function parseFields(req: Request): Promise<Record<string, string>> {
  const contentType = req.headers.get("content-type") ?? "";
  if (contentType.includes("application/json")) {
    const body = await req.json().catch(() => ({}));
    const out: Record<string, string> = {};
    if (body && typeof body === "object") {
      for (const [k, v] of Object.entries(body as Record<string, unknown>)) out[k] = String(v ?? "");
    }
    return out;
  }
  const text = await req.text();
  const params = new URLSearchParams(text);
  const out: Record<string, string> = {};
  for (const [k, v] of params.entries()) out[k] = v;
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  const custIdCliente = Deno.env.get("EPAYCO_P_CUST_ID_CLIENTE");
  const pKey = Deno.env.get("EPAYCO_P_KEY");
  if (!custIdCliente) return json({ error: "EPAYCO_P_CUST_ID_CLIENTE_MISSING" }, 500);
  if (!pKey) return json({ error: "EPAYCO_P_KEY_MISSING" }, 500);

  const fields = await parseFields(req);

  const refPayco = fields["x_ref_payco"] ?? "";
  const transactionId = fields["x_transaction_id"] ?? "";
  const amountRaw = fields["x_amount"] ?? fields["x_amount_ok"] ?? "";
  const currencyCode = (fields["x_currency_code"] ?? "COP").toUpperCase();
  const providedSignature = fields["x_signature"] ?? "";
  const codResponse = fields["x_cod_response"] ?? fields["x_cod_transaction_state"] ?? "";
  const responseText = fields["x_response"] ?? fields["x_transaction_state"] ?? "";
  const invoice = fields["x_id_invoice"] ?? fields["x_extra1"] ?? "";

  if (!refPayco || !transactionId || !amountRaw || !providedSignature) {
    return json({ error: "MISSING_REQUIRED_FIELDS" }, 400);
  }

  // Documented ePayco signature formula: sha256(p_cust_id_cliente^p_key^x_ref_payco^
  // x_transaction_id^x_amount^x_currency_code) -- a plain hash over the shared secret and
  // the transaction fields, not an HMAC.
  const manifest = `${custIdCliente}^${pKey}^${refPayco}^${transactionId}^${amountRaw}^${currencyCode}`;
  const computedSignature = await sha256Hex(manifest);

  if (!timingSafeEqual(computedSignature, providedSignature.toLowerCase())) {
    console.error("epayco-webhook: signature mismatch", { refPayco, transactionId });
    return json({ error: "INVALID_SIGNATURE" }, 401);
  }

  const reference = invoice;
  const refParts = reference.split(":");
  if (refParts.length !== 3 || refParts[0] !== "dyn") {
    console.error("epayco-webhook: unrecognized reference format", reference);
    return json({ ok: true, unrouted: reference });
  }
  const domain = refParts[1] as Domain;
  const rowId = refParts[2];

  const amount = Number(amountRaw);
  const status = normalizeStatus(codResponse, responseText);
  const providerPaymentId = refPayco;
  // No separate per-delivery notification id is documented for ePayco (unlike Mercado
  // Pago's own top-level webhook `id`) -- derive a stable-per-status event id instead, so
  // identical retries of the same status are idempotent while a genuine status change
  // (pending -> paid) still registers as a new event.
  const providerEventId = `${refPayco}:${transactionId}:${codResponse || responseText}`;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return json({ error: "SUPABASE_CONFIG_MISSING" }, 500);
  const supabase = createClient(supabaseUrl, serviceKey);

  const rawPayload = fields;

  try {
    switch (domain) {
      case "booking": {
        const { error } = await supabase.rpc("apply_payment_result", {
          p_provider: "epayco",
          p_provider_payment_id: providerPaymentId,
          p_provider_event_id: providerEventId,
          p_booking_id: rowId,
          p_amount: amount,
          p_currency_code: currencyCode,
          p_status: status,
          p_raw_payload: rawPayload,
        });
        if (error) throw error;
        break;
      }
      case "shop": {
        if (status !== "paid") break; // confirm_shop_order_payment is success-only.
        const { error } = await supabase.rpc("confirm_shop_order_payment", {
          p_order_id: rowId,
          p_provider: "epayco",
          p_provider_payment_id: providerPaymentId,
          p_provider_event_id: providerEventId,
          p_amount: amount,
          p_currency_code: currencyCode,
          p_raw_payload: rawPayload,
        });
        if (error) throw error;
        break;
      }
      case "marketplace": {
        if (status !== "paid") break; // confirm_marketplace_payment is success-only.
        const { error } = await supabase.rpc("confirm_marketplace_payment", {
          p_order_id: rowId,
          p_provider: "epayco",
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
            provider_name: "epayco",
            provider_invoice_reference: providerPaymentId,
            paid_at: status === "paid" ? new Date().toISOString() : null,
          })
          .eq("id", rowId);
        if (error) throw error;
        break;
      }
      default:
        console.error("epayco-webhook: unknown reference domain", domain, reference);
        return json({ ok: true, unrouted: reference });
    }
  } catch (err) {
    console.error("epayco-webhook: RPC/DB update failed", domain, rowId, err instanceof Error ? err.message : err);
    return json({ error: "DB_UPDATE_FAILED" }, 500);
  }

  return json({ ok: true });
});
