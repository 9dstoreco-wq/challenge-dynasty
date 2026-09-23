// Server-only helpers for creating a Wompi (Colombia) checkout. Only ever import this from
// a server file (a Route Handler, a Server Action) — WOMPI_INTEGRITY_SECRET must never
// reach the browser bundle.
//
// Reference convention (shared with supabase/functions/wompi-webhook/index.ts, which
// reconciles payment status back onto each domain's row once Wompi confirms the charge):
//
//   dyn:<domain>:<row_id>
//
//   domain      row_id matches...
//   shop        shop_orders.id            (shop_order_payments.order_id)
//   booking     bookings.id               (booking_payment_records.booking_id)
//   tournament  tournament_entries.id     (tournament_registration_payments.entry_id)
//   marketplace marketplace_orders.id     (marketplace_order_payments.order_id)
//   billing     billing_invoices.id       (billing_invoices.id directly)

export type WompiDomain = "shop" | "booking" | "tournament" | "marketplace" | "billing";

export interface WompiCheckoutConfig {
  publicKey: string;
  currency: string;
  amountInCents: number;
  reference: string;
  signatureIntegrity: string;
  redirectUrl: string;
}

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function buildWompiReference(domain: WompiDomain, rowId: string): string {
  return `dyn:${domain}:${rowId}`;
}

export interface BuildWompiCheckoutParams {
  domain: WompiDomain;
  rowId: string;
  /** Amount in the currency's major unit (e.g. pesos), NOT cents. */
  amount: number;
  currencyCode: string;
  /** Path (e.g. "/shop/orders/<id>") resolved against `origin` for the post-payment redirect. */
  redirectPath: string;
  origin: string;
}

/**
 * Builds the signed config the Wompi Web Checkout widget needs. The integrity signature is
 * SHA256(reference + amountInCents + currency + WOMPI_INTEGRITY_SECRET), computed here
 * (server-side) per Wompi's docs (docs.wompi.co, Web Checkout widget) — never in the browser.
 */
export async function buildWompiCheckoutConfig(
  params: BuildWompiCheckoutParams
): Promise<WompiCheckoutConfig> {
  const publicKey = process.env.WOMPI_PUBLIC_KEY;
  const integritySecret = process.env.WOMPI_INTEGRITY_SECRET;
  if (!publicKey) throw new Error("WOMPI_PUBLIC_KEY_MISSING");
  if (!integritySecret) throw new Error("WOMPI_INTEGRITY_SECRET_MISSING");

  const currency = (params.currencyCode || "COP").toUpperCase();
  if (currency !== "COP") {
    // Wompi's Web Checkout widget currently only supports COP.
    throw new Error("UNSUPPORTED_CURRENCY");
  }

  const amountInCents = Math.round(params.amount * 100);
  if (!Number.isFinite(amountInCents) || amountInCents <= 0) {
    throw new Error("INVALID_AMOUNT");
  }

  const reference = buildWompiReference(params.domain, params.rowId);
  const redirectUrl = new URL(params.redirectPath, params.origin).toString();

  // Wompi's documented concatenation order: <Reference><AmountInCents><Currency><IntegritySecret>
  const signatureIntegrity = await sha256Hex(`${reference}${amountInCents}${currency}${integritySecret}`);

  return { publicKey, currency, amountInCents, reference, signatureIntegrity, redirectUrl };
}
