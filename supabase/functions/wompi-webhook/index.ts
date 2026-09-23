import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// CHALLENGE DYNASTY — Wompi payment webhook (platform-wide).
//
// This is the single receiving endpoint for every domain that can take a Wompi payment:
// Dynasty Shop, court/resource bookings, tournament entry fees, marketplace orders, and
// billing subscriptions. Each domain has its own payment table (confirmed via
// information_schema against the live schema on 2026-09-22), so routing is done by a
// convention on the Wompi `reference` string set when the checkout is created:
//
//   dyn:<domain>:<row_id>
//   domain ∈ { shop, booking, tournament, marketplace, billing }
//   row_id  = the id of the row in that domain's *_orders / bookings / tournament_entries /
//             billing_invoices table that this payment is for.
//
// Nothing calls this yet — the checkout-creation side (building the reference + the
// server-side integrity signature required by Wompi's Web Checkout widget) is a separate,
// still-to-build piece per domain. This function only needs WOMPI_EVENTS_SECRET, set as a
// Supabase Edge Function secret from Wompi's dashboard (My account > Secrets of technical
// integration > Events). SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are injected automatically.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function getByPath(obj: unknown, path: string): unknown {
  return path.split(".").reduce<unknown>((acc, key) => {
    if (acc == null || typeof acc !== "object") return undefined;
    return (acc as Record<string, unknown>)[key];
  }, obj);
}

type Domain = "shop" | "booking" | "tournament" | "marketplace" | "billing";

function normalizeStatus(wompiStatus: string): "paid" | "failed" | "voided" | "pending" {
  if (wompiStatus === "APPROVED") return "paid";
  if (wompiStatus === "DECLINED" || wompiStatus === "ERROR") return "failed";
  if (wompiStatus === "VOIDED") return "voided";
  return "pending";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  const eventsSecret = Deno.env.get("WOMPI_EVENTS_SECRET");
  if (!eventsSecret) return json({ error: "WOMPI_EVENTS_SECRET_MISSING" }, 500);

  const body = await req.json().catch(() => null);
  if (!body || typeof body !== "object") return json({ error: "INVALID_JSON" }, 400);

  // Wompi tells us, per event, exactly which fields (and in what order) it hashed into the
  // checksum, plus the timestamp it used — so we recompute from that instead of hardcoding
  // an assumed field list, which would silently break if Wompi changes it per event type.
  const properties: string[] = Array.isArray(body?.signature?.properties) ? body.signature.properties : [];
  const providedChecksum: string = typeof body?.signature?.checksum === "string" ? body.signature.checksum : "";
  const timestamp = body?.timestamp ?? "";

  if (!properties.length || !providedChecksum) {
    return json({ error: "MISSING_SIGNATURE" }, 400);
  }

  const concatenated = properties.map((p) => String(getByPath(body, p) ?? "")).join("") + String(timestamp) + eventsSecret;
  const computedChecksum = await sha256Hex(concatenated);

  if (computedChecksum.toUpperCase() !== providedChecksum.toUpperCase()) {
    console.error("wompi-webhook: checksum mismatch", { computedChecksum, providedChecksum });
    return json({ error: "INVALID_CHECKSUM" }, 401);
  }

  const eventType = typeof body?.event === "string" ? body.event : "";
  const tx = body?.data?.transaction as Record<string, unknown> | undefined;

  if (eventType !== "transaction.updated" || !tx) {
    // Acknowledge everything else (nequi_token.updated, bancolombia_transfer_token.updated, ...)
    // so Wompi doesn't retry it, but there's nothing to route yet.
    return json({ ok: true, ignored: eventType || "unknown" });
  }

  const reference = String(tx.reference ?? "");
  const wompiStatus = String(tx.status ?? "");
  const providerPaymentId = String(tx.id ?? "");
  const amountInCents = Number(tx.amount_in_cents ?? 0);
  const amount = amountInCents / 100;
  const status = normalizeStatus(wompiStatus);

  const parts = reference.split(":");
  if (parts.length !== 3 || parts[0] !== "dyn") {
    console.error("wompi-webhook: unrecognized reference format", reference);
    return json({ ok: true, unrouted: reference });
  }
  const domain = parts[1] as Domain;
  const rowId = parts[2];

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return json({ error: "SUPABASE_CONFIG_MISSING" }, 500);
  const supabase = createClient(supabaseUrl, serviceKey);

  try {
    switch (domain) {
      case "shop": {
        const { error } = await supabase
          .from("shop_order_payments")
          .update({ status, provider: "wompi", provider_payment_id: providerPaymentId, provider_event_id: eventType, amount })
          .eq("order_id", rowId);
        if (error) throw error;
        break;
      }
      case "booking": {
        const { error } = await supabase
          .from("booking_payment_records")
          .update({ payment_status: status, amount_paid: status === "paid" ? amount : undefined })
          .eq("booking_id", rowId);
        if (error) throw error;
        break;
      }
      case "tournament": {
        const { error } = await supabase
          .from("tournament_registration_payments")
          .update({ status, amount_paid: status === "paid" ? amount : undefined })
          .eq("entry_id", rowId);
        if (error) throw error;
        break;
      }
      case "marketplace": {
        const { error } = await supabase
          .from("marketplace_order_payments")
          .update({ status, provider: "wompi", provider_payment_id: providerPaymentId, provider_event_id: eventType })
          .eq("order_id", rowId);
        if (error) throw error;
        break;
      }
      case "billing": {
        const { error } = await supabase
          .from("billing_invoices")
          .update({
            status: status === "paid" ? "paid" : status === "failed" ? "failed" : "open",
            amount_paid: status === "paid" ? amount : 0,
            provider_name: "wompi",
            provider_invoice_reference: providerPaymentId,
            paid_at: status === "paid" ? new Date().toISOString() : null,
          })
          .eq("id", rowId);
        if (error) throw error;
        // NOTE: activating billing_entitlements from a paid invoice (copying rows from
        // billing_plan_features for the invoice's plan) is the next piece once billing_plans
        // has real data -- intentionally not wired here yet, see the audit notes.
        break;
      }
      default:
        console.error("wompi-webhook: unknown reference domain", domain, reference);
        return json({ ok: true, unrouted: reference });
    }
  } catch (err) {
    console.error("wompi-webhook: DB update failed", domain, rowId, err instanceof Error ? err.message : err);
    return json({ error: "DB_UPDATE_FAILED" }, 500);
  }

  return json({ ok: true });
});
