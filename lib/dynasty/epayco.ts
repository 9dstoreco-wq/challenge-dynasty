// Server-only helpers for the ePayco checkout entrypoint (Standard Checkout / checkout.js).
// Only ever import this from a server file (a Route Handler, a Server Action).
//
// Unlike the previous Mercado Pago integration -- which locked the amount into a
// server-created "preference" the buyer couldn't tamper with -- ePayco's classic
// handler.open({...}) flow hands the amount to the client as a plain JS object, which a
// determined user COULD alter in devtools before opening the widget. That's fine here
// because the source of truth is the SIGNED confirmation webhook ePayco sends back
// (supabase/functions/epayco-webhook), which re-validates the reported amount against the
// row's own stored amount (via apply_payment_result / confirm_*_payment) before marking
// anything paid. A tampered client-side amount just fails to reconcile -- it can never get
// recorded as paid, because ePayco itself only ever charges (and signs a webhook for)
// whatever amount the buyer actually approved on their hosted widget.
//
// 2026-09-29: switched the platform's payment provider from Mercado Pago to ePayco. Uses
// the same `dyn:<domain>:<row_id>` reference convention as before (see
// lib/dynasty/checkout-resolvers.ts and supabase/functions/epayco-webhook).
//
//   dyn:<domain>:<row_id>
//
//   domain      row_id matches...
//   shop        shop_orders.id            (shop_order_payments.order_id)
//   booking     bookings.id               (payment_records.booking_id, via apply_payment_result)
//   tournament  tournament_entries.id     (tournament_registration_payments.entry_id)
//   marketplace marketplace_orders.id     (marketplace_order_payments.order_id)
//   billing     billing_invoices.id       (billing_invoices.id directly)

export type EpaycoDomain = "shop" | "booking" | "tournament" | "marketplace" | "billing";

export interface EpaycoCheckoutConfig {
  amount: number;
  currencyCode: string;
  description: string;
  invoice: string;
  redirectUrl: string;
}

const DOMAIN_TITLES: Record<EpaycoDomain, string> = {
  shop: "Dynasty Shop - Pedido",
  booking: "Challenge Dynasty - Reserva de cancha",
  tournament: "Challenge Dynasty - Inscripcion a torneo",
  marketplace: "Dynasty Marketplace - Pedido",
  billing: "Challenge Dynasty - Factura",
};

export function buildEpaycoReference(domain: EpaycoDomain, rowId: string): string {
  return `dyn:${domain}:${rowId}`;
}

export interface BuildEpaycoCheckoutParams {
  domain: EpaycoDomain;
  rowId: string;
  /** Amount in the currency's major unit (e.g. pesos), NOT cents. */
  amount: number;
  currencyCode: string;
  /** Path (e.g. "/bookings/<id>") resolved against `origin` for the post-payment redirect. */
  redirectPath: string;
  origin: string;
}

/**
 * Computes the checkout config the client needs to open ePayco's hosted widget. Pure and
 * synchronous -- no network call, unlike buildMercadoPagoPreference's old preference
 * creation -- because ePayco's classic integration doesn't need a server-created session,
 * just the buyer's browser calling handler.open() with these fields plus the public key
 * (NEXT_PUBLIC_EPAYCO_PUBLIC_KEY, read directly in the client component).
 */
export function buildEpaycoCheckout(params: BuildEpaycoCheckoutParams): EpaycoCheckoutConfig {
  const currency = (params.currencyCode || "COP").toUpperCase();
  if (currency !== "COP") {
    // ePayco Colombia only settles in COP for this merchant account.
    throw new Error("UNSUPPORTED_CURRENCY");
  }

  // Not rounded: apply_payment_result (the RPC the webhook calls to confirm this payment)
  // compares the confirmed amount against `bookings.amount` for exact equality, so this must
  // be the same numeric value the resolver read off that row, not a rounded approximation.
  const amount = params.amount;
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error("INVALID_AMOUNT");
  }

  const reference = buildEpaycoReference(params.domain, params.rowId);
  const redirectUrl = new URL(params.redirectPath, params.origin).toString();

  return {
    amount,
    currencyCode: currency,
    description: DOMAIN_TITLES[params.domain],
    invoice: reference,
    redirectUrl,
  };
}
