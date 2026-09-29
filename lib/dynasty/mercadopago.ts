// Server-only helpers for creating a Mercado Pago (Checkout Pro) preference. Only ever
// import this from a server file (a Route Handler, a Server Action) -- MERCADOPAGO_ACCESS_TOKEN
// must never reach the browser bundle.
//
// Added 2026-09-29, and as of the same week the platform's only payment provider: Wompi
// was dropped (merchant account blocked on a Camara de Comercio renewal that wasn't worth
// chasing), and Mercado Pago's persona natural signup (cedula + NIT only, no Camara de
// Comercio) covers it. Uses the same `dyn:<domain>:<row_id>` reference convention (shared
// with the webhook that reconciles payment status back onto each domain's row) and the same
// env-var-missing error shape as the resolver layer expects (see
// lib/dynasty/checkout-resolvers.ts).
//
//   dyn:<domain>:<row_id>
//
//   domain      row_id matches...
//   shop        shop_orders.id            (shop_order_payments.order_id)
//   booking     bookings.id               (payment_records.booking_id, via apply_payment_result)
//   tournament  tournament_entries.id     (tournament_registration_payments.entry_id)
//   marketplace marketplace_orders.id     (marketplace_order_payments.order_id)
//   billing     billing_invoices.id       (billing_invoices.id directly)

import { MercadoPagoConfig, Preference } from "mercadopago";

export type MercadoPagoDomain = "shop" | "booking" | "tournament" | "marketplace" | "billing";

export interface MercadoPagoCheckoutConfig {
  initPoint: string;
  preferenceId: string;
}

const DOMAIN_TITLES: Record<MercadoPagoDomain, string> = {
  shop: "Dynasty Shop - Pedido",
  booking: "Challenge Dynasty - Reserva de cancha",
  tournament: "Challenge Dynasty - Inscripcion a torneo",
  marketplace: "Dynasty Marketplace - Pedido",
  billing: "Challenge Dynasty - Factura",
};

export function buildMercadoPagoReference(domain: MercadoPagoDomain, rowId: string): string {
  return `dyn:${domain}:${rowId}`;
}

export interface BuildMercadoPagoPreferenceParams {
  domain: MercadoPagoDomain;
  rowId: string;
  /** Amount in the currency's major unit (e.g. pesos), NOT cents. */
  amount: number;
  currencyCode: string;
  /** Path (e.g. "/bookings/<id>") resolved against `origin` for the post-payment redirect. */
  redirectPath: string;
  origin: string;
}

/**
 * Creates a Mercado Pago Checkout Pro preference and returns the URL to redirect the
 * browser to. The integrity of the amount is Mercado Pago's problem once the preference is
 * created (the buyer can't tamper with it in the hosted checkout); what matters here is that
 * `amount`/`currencyCode` came from our own resolver (checkout-resolvers.ts), never from the
 * client request body.
 */
export async function buildMercadoPagoPreference(
  params: BuildMercadoPagoPreferenceParams
): Promise<MercadoPagoCheckoutConfig> {
  const accessToken = process.env.MERCADOPAGO_ACCESS_TOKEN;
  if (!accessToken) throw new Error("MERCADOPAGO_ACCESS_TOKEN_MISSING");

  const currency = (params.currencyCode || "COP").toUpperCase();
  if (currency !== "COP") {
    // Mercado Pago Colombia only settles in COP for this merchant account.
    throw new Error("UNSUPPORTED_CURRENCY");
  }

  // Not rounded: apply_payment_result (the RPC the webhook calls to confirm this payment)
  // compares the confirmed amount against `bookings.amount` for exact equality, so this must
  // be the same numeric value the resolver read off that row, not a rounded approximation.
  const unitPrice = params.amount;
  if (!Number.isFinite(unitPrice) || unitPrice <= 0) {
    throw new Error("INVALID_AMOUNT");
  }

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!supabaseUrl) throw new Error("SUPABASE_URL_MISSING");

  const reference = buildMercadoPagoReference(params.domain, params.rowId);
  const redirectUrl = new URL(params.redirectPath, params.origin).toString();
  const isHttps = redirectUrl.startsWith("https://");

  const client = new MercadoPagoConfig({ accessToken });
  const preference = await new Preference(client).create({
    body: {
      items: [
        {
          id: reference,
          title: DOMAIN_TITLES[params.domain],
          quantity: 1,
          unit_price: unitPrice,
          currency_id: currency,
        },
      ],
      external_reference: reference,
      notification_url: `${supabaseUrl}/functions/v1/mercadopago-webhook`,
      back_urls: {
        success: redirectUrl,
        pending: redirectUrl,
        failure: redirectUrl,
      },
      // auto_return requires a public https success URL; skip it on http (local/dev) origins
      // rather than let Mercado Pago reject preference creation outright.
      ...(isHttps ? { auto_return: "approved" as const } : {}),
    },
  });

  if (!preference.id || !preference.init_point) {
    throw new Error("MERCADOPAGO_PREFERENCE_INCOMPLETE");
  }

  return { initPoint: preference.init_point, preferenceId: preference.id };
}
