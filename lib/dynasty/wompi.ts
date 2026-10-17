// Server-only helpers for the Wompi checkout entrypoint (Web Checkout widget / widget.js).
// Only ever import this from a server file (a Route Handler, a Server Action).
//
// Uses the `dyn:<domain>:<row_id>:<nonce>` reference convention (see
// lib/dynasty/checkout-resolvers.ts and supabase/functions/wompi-webhook) so the same
// server-side resolvers and confirm_*/apply_payment_result RPCs stay provider-agnostic -- the
// `p_provider` value passed to them is "wompi". (The previous ePayco provider used the same
// convention with p_provider "epayco"; its code was deleted 2026-10-16, see the history note
// in checkout-resolvers.ts.)
//
// Unlike ePayco's classic handler.open({...}), Wompi's Web Checkout widget needs a signed
// "signature:integrity" computed from reference + amount + currency + a secret the browser
// must never see (WOMPI_INTEGRITY_SECRET). That signature can only be produced here, on the
// server -- which means a tampered client-side amount can never even open a valid widget,
// not just get caught after the fact by the webhook (as with the old ePayco flow).
//
// 2026-10-09: Wompi (re)introduced as the platform's payment provider, with a new merchant
// account. (A previous Wompi integration existed and was removed 2026-09-29 over a Camara
// de Comercio renewal problem with the old account -- see the history note at the top of
// checkout-resolvers.ts. ePayco's code was left in place, unused, as a fallback, until it
// was deleted 2026-10-16.)
//
// 2026-10-13: Wompi's own docs are explicit that a reference "will not be possible to use
// again" once it has been used for a payment on the merchant account
// (docs.wompi.co/en/docs/colombia/widget-checkout-web, step 2). buildWompiReference used to
// return the exact same string (`dyn:<domain>:<rowId>`) for every checkout attempt on the
// same row, so a user whose card was declined (or who just closed the widget) would get an
// already-used reference on retry. Each call now appends a short random nonce so the
// reference is unique per attempt while the domain/rowId routing stays unchanged. The
// webhook (supabase/functions/wompi-webhook/index.ts) parses and discards that 4th segment --
// it is never looked up against anything, it only keeps Wompi happy.

import { createHash, randomBytes } from "node:crypto";

export type WompiDomain = "booking" | "tournament" | "marketplace" | "billing";

export interface WompiCheckoutConfig {
  amountInCents: number;
  currency: string;
  reference: string;
  redirectUrl: string;
  publicKey: string;
  signature: string;
}

/** Random per-attempt suffix: short enough to keep the reference readable, long enough
 *  (36 bits) that two concurrent checkout attempts on the same row never collide. */
function checkoutNonce(): string {
  return randomBytes(5).toString("hex");
}

export function buildWompiReference(domain: WompiDomain, rowId: string): string {
  return `dyn:${domain}:${rowId}:${checkoutNonce()}`;
}

export interface BuildWompiCheckoutParams {
  domain: WompiDomain;
  rowId: string;
  /** Amount in the currency's major unit (e.g. pesos), NOT cents. */
  amount: number;
  currencyCode: string;
  /** Path (e.g. "/bookings/<id>") resolved against `origin` for the post-payment redirect. */
  redirectPath: string;
  origin: string;
}

/**
 * Computes the checkout config the client needs to open Wompi's Web Checkout widget,
 * including the server-computed integrity signature. (Previously mirrored
 * buildEpaycoCheckout's shape and validation in lib/dynasty/epayco.ts, plus the signature
 * step ePayco didn't need -- that file was deleted 2026-10-16.)
 */
export function buildWompiCheckout(params: BuildWompiCheckoutParams): WompiCheckoutConfig {
  const currency = (params.currencyCode || "COP").toUpperCase();
  if (currency !== "COP") {
    // Wompi Colombia only settles in COP for this merchant account.
    throw new Error("UNSUPPORTED_CURRENCY");
  }

  const amount = params.amount;
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error("INVALID_AMOUNT");
  }

  const publicKey = process.env.NEXT_PUBLIC_WOMPI_PUBLIC_KEY;
  const integritySecret = process.env.WOMPI_INTEGRITY_SECRET;
  if (!publicKey || !integritySecret) {
    throw new Error("PAYMENT_PROVIDER_NOT_CONFIGURED");
  }

  // Wompi wants an integer amount_in_cents, not the decimal major-unit amount every
  // resolver returns (e.g. apply_payment_result compares against bookings.amount in pesos).
  // Rounded, not truncated, so a resolver value with a stray fractional cent never loses
  // money off the charged amount.
  const amountInCents = Math.round(amount * 100);

  const reference = buildWompiReference(params.domain, params.rowId);
  const redirectUrl = new URL(params.redirectPath, params.origin).toString();

  // Documented Wompi integrity formula (docs.wompi.co, Colombia > Widget y Web Checkout):
  // sha256(reference + amountInCents + currency + integritySecret) -- a plain concatenated
  // hash, not an HMAC. Computed here, server-side, so the integrity secret never reaches
  // the browser (Wompi's own docs recommend this).
  const signature = createHash("sha256")
    .update(`${reference}${amountInCents}${currency}${integritySecret}`)
    .digest("hex");

  return {
    amountInCents,
    currency,
    reference,
    redirectUrl,
    publicKey,
    signature,
  };
}
