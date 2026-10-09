import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// CHALLENGE DYNASTY -- Wompi payment webhook (platform-wide).
//
// Receives the event Wompi posts after a transaction changes state and routes by the
// `dyn:<domain>:<row_id>` reference convention set by lib/dynasty/wompi.ts when the widget
// is opened (see components/WompiCheckoutButton.tsx). Mirrors
// supabase/functions/epayco-webhook in shape and hardening -- same reference convention,
// same per-domain RPC routing -- just re-pointed at Wompi's own event/field names.
//
// Needs two Supabase Edge Function secrets, both from the Wompi merchant dashboard
// (comercios.wompi.co) under "Desarrolladores" / "Secretos para integracion tecnica" --
// NOT the same as the checkout public/private keys:
//   WOMPI_EVENTS_SECRET  -- "Eventos" secret, used to verify the event checksum below.
//   WOMPI_PUBLIC_KEY     -- the merchant public key (same value as the client-side
//                           NEXT_PUBLIC_WOMPI_PUBLIC_KEY), used as a Bearer token to ask
//                           Wompi's own API for the transaction's real state.
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are injected automatically.
//
// HARDENING (matches epayco-webhook's approach):
//   * Checksum verification (X-Event-Checksum / signature.checksum): per Wompi's docs the
//     checksum is sha256(concat of the values at signature.properties, in order) + timestamp
//     + Events secret). The property list is read from the event itself, never hardcoded,
//     because Wompi says it can change.
//   * SERVER-SIDE VERIFICATION: after the checksum passes, this still asks Wompi's own API
//     (GET /v1/transactions/{id}) for the transaction and acts on ITS status/amount/
//     reference/currency -- never the ones in the posted body -- exactly like
//     epayco-webhook's fetchVerifiedTransaction step. Fails closed: if Wompi's API can't
//     confirm the transaction, nothing is marked paid and Wompi is asked to retry later.
//   * Only COP is accepted.
//   * Billing: the invoice amount is compared with the payment, and an invoice already
//     marked paid is never overwritten by a later/duplicate event.
//
// For the `booking` domain this calls `apply_payment_result` (p_provider: "wompi"), the
// same hardened SECURITY DEFINER RPC the ePayco webhook uses, which validates the amount
// against `bookings` directly. Other domains call their own hardened confirm_* RPC where
// one exists (shop, marketplace, tournament); `billing` has no dedicated RPC yet, so it
// keeps a direct table update for that domain -- identical to epayco-webhook.

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

// Wompi's four terminal/non-terminal transaction states -> this platform's payment_records
// status vocabulary (same vocabulary apply_payment_result enforces for every provider).
function normalizeStatus(wompiStatus: string): "pending" | "paid" | "failed" | "cancelled" {
  switch (wompiStatus) {
    case "APPROVED":
      return "paid";
    case "DECLINED":
    case "ERROR":
      return "failed";
    case "VOIDED":
      // A void reverses a transaction that was never actually settled -- closer to a
      // cancellation than a refund (which implies money was collected and given back).
      return "cancelled";
    case "PENDING":
    default:
      return "pending";
  }
}

// Reads a dot path like "transaction.id" off the event's own `data` object -- the
// signature.properties list is never hardcoded (Wompi's docs say it can change), so this
// just follows whatever path each listed property names.
function readPath(obj: unknown, path: string): string {
  const parts = path.split(".");
  let cur: unknown = obj;
  for (const part of parts) {
    if (cur === null || typeof cur !== "object") return "";
    cur = (cur as Record<string, unknown>)[part];
  }
  return cur === undefined || cur === null ? "" : String(cur);
}

type WompiEvent = {
  event?: string;
  data?: { transaction?: Record<string, unknown> };
  sent_at?: string;
  signature?: { checksum?: string; properties?: string[]; timestamp?: number };
  timestamp?: number;
};

type VerifiedTransaction = {
  id: string;
  reference: string;
  status: string;
  amount_in_cents: number;
  currency: string;
};

// Asks Wompi itself for the transaction, so the state/amount/reference/currency we act on
// come from Wompi's servers and not from the posted body. The public key works as a Bearer
// token for this read-only lookup (per docs.wompi.co); sandbox vs production is picked from
// the key's own prefix, same as the checkout widget would use for that same key.
async function fetchVerifiedTransaction(transactionId: string, publicKey: string): Promise<VerifiedTransaction | null> {
  const base = publicKey.startsWith("pub_test_") ? "https://sandbox.wompi.co/v1" : "https://production.wompi.co/v1";
  try {
    const res = await fetch(`${base}/transactions/${encodeURIComponent(transactionId)}`, {
      headers: { Authorization: `Bearer ${publicKey}`, Accept: "application/json" },
    });
    if (!res.ok) return null;
    const body = await res.json().catch(() => null) as { data?: Record<string, unknown> } | null;
    const data = body?.data;
    if (!data || typeof data !== "object") return null;
    const id = String(data.id ?? "");
    const reference = String(data.reference ?? "");
    const status = String(data.status ?? "");
    const amountInCents = Number(data.amount_in_cents);
    const currency = String(data.currency ?? "");
    if (!id || !reference || !status || !Number.isFinite(amountInCents)) return null;
    return { id, reference, status, amount_in_cents: amountInCents, currency };
  } catch (err) {
    console.error("wompi-webhook: validation lookup failed", err instanceof Error ? err.message : err);
    return null;
  }
}

const SAME_AMOUNT = (a: number, b: number) => a === b && Number.isFinite(a) && Number.isFinite(b);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  const eventsSecret = Deno.env.get("WOMPI_EVENTS_SECRET");
  const publicKey = Deno.env.get("WOMPI_PUBLIC_KEY");
  if (!eventsSecret) return json({ error: "WOMPI_EVENTS_SECRET_MISSING" }, 500);
  if (!publicKey) return json({ error: "WOMPI_PUBLIC_KEY_MISSING" }, 500);

  const bodyText = await req.text();
  let payload: WompiEvent | null = null;
  try {
    payload = JSON.parse(bodyText) as WompiEvent;
  } catch {
    return json({ error: "INVALID_JSON" }, 400);
  }
  if (!payload || typeof payload !== "object") return json({ error: "INVALID_JSON" }, 400);

  const headerChecksum = req.headers.get("x-event-checksum") ?? "";
  const providedChecksum = (payload.signature?.checksum || headerChecksum || "").toLowerCase();
  const properties = payload.signature?.properties ?? [];
  const timestamp = payload.signature?.timestamp ?? payload.timestamp;

  if (!providedChecksum || properties.length === 0 || timestamp === undefined) {
    return json({ error: "MISSING_SIGNATURE_FIELDS" }, 400);
  }

  // Documented Wompi event checksum: sha256(concat of signature.properties values, in the
  // listed order, taken from `data`) + timestamp + Events secret.
  const concatenated = properties.map((p) => readPath(payload!.data, p)).join("") + String(timestamp) + eventsSecret;
  const computedChecksum = await sha256Hex(concatenated);

  if (!timingSafeEqual(computedChecksum, providedChecksum)) {
    console.error("wompi-webhook: checksum mismatch", { event: payload.event });
    return json({ error: "INVALID_SIGNATURE" }, 401);
  }

  const transaction = payload.data?.transaction;
  const transactionId = transaction?.id ? String(transaction.id) : "";
  if (!transactionId) {
    // nequi_token.updated / bancolombia_transfer_token.updated and any future event types
    // with no transaction to reconcile -- nothing for this webhook to do.
    return json({ ok: true, ignored: payload.event ?? "NO_TRANSACTION" });
  }

  // Server-side verification (see HARDENING above). Fail closed: if Wompi can't confirm the
  // transaction we answer 502 so Wompi retries later, and nothing is marked paid.
  const verified = await fetchVerifiedTransaction(transactionId, publicKey);
  if (!verified) return json({ error: "VERIFICATION_UNAVAILABLE" }, 502);

  if ((verified.currency || "COP").toUpperCase() !== "COP") {
    console.error("wompi-webhook: unsupported currency", verified.currency);
    return json({ ok: true, ignored: "UNSUPPORTED_CURRENCY" });
  }

  const reference = verified.reference;
  const refParts = reference.split(":");
  if (refParts.length !== 3 || refParts[0] !== "dyn") {
    console.error("wompi-webhook: unrecognized reference format", reference);
    return json({ ok: true, unrouted: reference });
  }
  const domain = refParts[1] as Domain;
  const rowId = refParts[2];

  const amount = verified.amount_in_cents / 100;
  const currencyCode = "COP";
  const status = normalizeStatus(verified.status);
  const providerPaymentId = verified.id;
  // Wompi doesn't hand out a separate per-delivery notification id -- derive a
  // stable-per-status event id (same approach as epayco-webhook) so identical retries of
  // the same status are idempotent while a genuine status change still registers as new.
  const providerEventId = `${verified.id}:${verified.status}`;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return json({ error: "SUPABASE_CONFIG_MISSING" }, 500);
  const supabase = createClient(supabaseUrl, serviceKey);

  const rawPayload = payload as unknown as Record<string, unknown>;

  try {
    switch (domain) {
      case "booking": {
        const { error } = await supabase.rpc("apply_payment_result", {
          p_provider: "wompi",
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
          p_provider: "wompi",
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
          p_provider: "wompi",
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
        // No dedicated confirm_* RPC exists yet for billing invoices (same as epayco-webhook):
        // compare the amount with the invoice and never overwrite an already-paid invoice.
        const { data: invoice, error: invErr } = await supabase
          .from("billing_invoices")
          .select("id, status, amount_due, currency_code")
          .eq("id", rowId)
          .maybeSingle();
        if (invErr) throw invErr;
        if (!invoice) return json({ ok: true, unrouted: reference });
        if (invoice.status === "paid") break; // late/duplicate events never change a paid invoice.
        if (status === "paid") {
          if (!SAME_AMOUNT(Number(invoice.amount_due), amount) || (invoice.currency_code ?? "COP").toUpperCase() !== "COP") {
            console.error("wompi-webhook: billing amount mismatch", rowId, invoice.amount_due, amount);
            return json({ error: "AMOUNT_MISMATCH" }, 422);
          }
        }
        const { error } = await supabase
          .from("billing_invoices")
          .update({
            status: status === "paid" ? "paid" : status === "failed" ? "failed" : "open",
            amount_paid: status === "paid" ? amount : 0,
            provider_name: "wompi",
            provider_invoice_reference: providerPaymentId,
            paid_at: status === "paid" ? new Date().toISOString() : null,
          })
          .eq("id", rowId)
          .neq("status", "paid");
        if (error) throw error;
        break;
      }
      default:
        console.error("wompi-webhook: unknown reference domain", domain, reference);
        return json({ ok: true, unrouted: reference });
    }
  } catch (err) {
    console.error("wompi-webhook: RPC/DB update failed", domain, rowId, err instanceof Error ? err.message : err);
    return json({ error: "DB_UPDATE_FAILED" }, 500);
  }

  return json({ ok: true });
});
