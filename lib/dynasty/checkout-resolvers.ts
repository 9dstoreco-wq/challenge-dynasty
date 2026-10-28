// Shared row-resolution logic for every "pay for X" checkout entrypoint (Wompi, and any
// future provider). Each provider's own route handler (e.g. app/api/checkout/wompi/route.ts)
// imports this so the "which row is this payment for, how much is owed, does this user own
// it" logic is written exactly once and can't drift between providers.
//
// Provider history (F11, Auditoria_Challenge_Dynasty_2026-10-12.md -- this comment block was
// stale and said ePayco was "the only provider now"; corrected 2026-10-14 after confirming
// against the live code, not just this comment; updated again 2026-10-16 after the unused
// ePayco code itself was deleted from the repo, see below):
//   2026-09-29: Wompi was removed from the platform (merchant account blocked on Camara de
//   Comercio renewal, decided not worth chasing), replaced by Mercado Pago -- and the same day,
//   Mercado Pago was itself replaced by ePayco (product decision).
//   2026-10-09: Luis activated a new Wompi merchant account and Wompi came BACK, replacing
//   ePayco (see /areas/payment accounts notes). Wompi has been the only live provider since:
//   WompiCheckoutButton is the one actually rendered (components/BookingControlCenter.tsx),
//   and NEXT_PUBLIC_WOMPI_PUBLIC_KEY/WOMPI_INTEGRITY_SECRET are the only payment-provider env
//   vars set in Vercel.
//   2026-10-16: the unused ePayco code (components/EpaycoCheckoutButton.tsx,
//   app/api/checkout/epayco/route.ts, lib/dynasty/epayco.ts, and
//   supabase/functions/epayco-webhook/) was deleted at Luis's request -- it was never
//   rendered/deployed (NEXT_PUBLIC_EPAYCO_PUBLIC_KEY was never set; the Edge Function was
//   never in the live list), so nothing live depended on it. The old mercadopago-webhook Edge
//   Function is still deployed (ACTIVE) with elevated (service-role-level) database access,
//   but nothing in the current app can build the dyn:mercadopago:... reference it expects --
//   orphaned infrastructure from the 2026-09-29 swap, not cleaned up when Mercado Pago was
//   replaced. See Challenge_Dynasty_F11_entrega.md for the full inventory and recommendation.
//
// IMPORTANT (2026-09-29 audit): `resolveBooking` reads amount/currency/payment_status
// directly off `bookings`, NOT `booking_payment_records`. `create_atomic_booking` (the only
// RPC that creates bookings) never writes a `booking_payment_records` row -- that table is
// populated by a separate provider-payout/deposit-tracking flow and is empty for every
// booking created through the normal reserve flow today. The previous version of this
// resolver read from `booking_payment_records` and would have thrown
// BOOKING_PAYMENT_NOT_FOUND for every real booking. `bookings.amount` /
// `bookings.currency_code` / `bookings.payment_status` are populated correctly by
// create_atomic_booking and are also exactly what `apply_payment_result` (the RPC the
// payment webhooks call to confirm a booking payment) validates the payment against and
// updates -- so reading from `bookings` here keeps the checkout-init amount and the
// webhook's confirmation amount pinned to the same source of truth.

import { createClient } from "@/lib/supabase/server";

export type CheckoutDomain = "booking" | "tournament" | "marketplace" | "billing";

export const ALLOWED_CHECKOUT_DOMAINS = new Set<CheckoutDomain>([
  "booking",
  "tournament",
  "marketplace",
  "billing",
]);

export type ResolvedCheckoutRow = { amount: number; currencyCode: string; redirectPath: string };

export class CheckoutError extends Error {
  status: number;
  constructor(code: string, status: number) {
    super(code);
    this.status = status;
  }
}

export type SupabaseServerClient = Awaited<ReturnType<typeof createClient>>;

async function resolveBooking(supabase: SupabaseServerClient, userId: string, rowId: string): Promise<ResolvedCheckoutRow> {
  const { data: booking, error: bookingError } = await supabase
    .from("bookings")
    .select("id, booked_by, amount, currency_code, payment_status, status")
    .eq("id", rowId)
    .maybeSingle();
  if (bookingError || !booking) throw new CheckoutError("BOOKING_NOT_FOUND", 404);
  if (booking.booked_by !== userId) throw new CheckoutError("FORBIDDEN", 403);
  if (booking.status === "cancelled") throw new CheckoutError("BOOKING_CANCELLED", 409);
  // F05 (Auditoria_Challenge_Dynasty_2026-10-12.md): this used to only reject "cancelled" --
  // "expired" (expire_pending_booking_offers, 15 min hold by default), "completed",
  // "no_show" and "waitlisted" fell through and could still have a brand-new checkout
  // initiated against them, even though none of them should ever accept a new payment.
  // "pending" (awaiting its first payment) and "confirmed" (already holding its slot,
  // possibly still awaiting payment after an admin override) are the only payable states.
  if (booking.status !== "pending" && booking.status !== "confirmed") {
    throw new CheckoutError("BOOKING_NOT_PAYABLE", 409);
  }
  if (booking.payment_status === "paid") throw new CheckoutError("ALREADY_PAID", 409);
  if (booking.payment_status === "not_required" || Number(booking.amount) <= 0) {
    throw new CheckoutError("PAYMENT_NOT_REQUIRED", 409);
  }
  return { amount: Number(booking.amount), currencyCode: booking.currency_code ?? "COP", redirectPath: `/bookings/${rowId}` };
}

async function resolveTournament(supabase: SupabaseServerClient, userId: string, rowId: string): Promise<ResolvedCheckoutRow> {
  const { data: entry, error: entryError } = await supabase
    .from("tournament_entries")
    .select("id, captain_profile_id, tournament_id")
    .eq("id", rowId)
    .maybeSingle();
  if (entryError || !entry) throw new CheckoutError("ENTRY_NOT_FOUND", 404);
  if (entry.captain_profile_id !== userId) throw new CheckoutError("FORBIDDEN", 403);

  const { data: payment, error: paymentError } = await supabase
    .from("tournament_registration_payments")
    .select("amount_due, amount_paid, currency_code, status")
    .eq("entry_id", rowId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (paymentError || !payment) throw new CheckoutError("ENTRY_PAYMENT_NOT_FOUND", 404);
  if (payment.status === "paid") throw new CheckoutError("ALREADY_PAID", 409);
  // F12: quote the remaining balance, not the full amount_due. confirm_tournament_registration_
  // payment (the RPC the payment webhooks call) now sums distinct provider events into
  // amount_paid instead of replacing it, but that fix is useless if checkout keeps asking the
  // player to pay the FULL amount_due on every attempt -- a player who already paid a partial
  // $50.000 of a $100.000 entry and tries to pay again from the app would be charged $100.000
  // again instead of the $50.000 actually owed, overpaying by the amount already settled.
  const remaining = Number(payment.amount_due) - Number(payment.amount_paid ?? 0);
  if (remaining <= 0) throw new CheckoutError("ALREADY_PAID", 409);
  return {
    amount: remaining,
    currencyCode: payment.currency_code ?? "COP",
    redirectPath: `/competitions/${entry.tournament_id}`,
  };
}

async function resolveMarketplace(supabase: SupabaseServerClient, userId: string, rowId: string): Promise<ResolvedCheckoutRow> {
  // marketplace_orders has exactly one RLS policy for `authenticated`:
  // deny_all_authenticated_marketplace_orders (USING false / WITH CHECK false, for ALL). A raw
  // .from("marketplace_orders").select() under the user's own session -- like the old version of
  // this function -- was ALWAYS blocked by it, so marketplace checkout returned ORDER_NOT_FOUND
  // for every real order. The rest of the app already avoids this (see get_my_marketplace_orders,
  // used by app/marketplace/orders/page.tsx); this routes through the same security-definer
  // pattern, scoped to one order id (see supabase/migrations/20261022140000_*.sql).
  type MarketplaceCheckoutOrder = {
    id: string
    total_amount: number
    currency_code: string
    buyer_id: string
    status: string
  }
  const { data, error } = (await supabase
    .rpc("resolve_marketplace_order_for_checkout", { p_order_id: rowId })
    .maybeSingle()) as { data: MarketplaceCheckoutOrder | null; error: unknown }
  if (error || !data) throw new CheckoutError("ORDER_NOT_FOUND", 404);
  if (data.buyer_id !== userId) throw new CheckoutError("FORBIDDEN", 403);
  if (data.status === "paid") throw new CheckoutError("ALREADY_PAID", 409);
  return { amount: Number(data.total_amount), currencyCode: data.currency_code ?? "COP", redirectPath: `/marketplace/orders/${rowId}` };
}

async function resolveBilling(supabase: SupabaseServerClient, userId: string, rowId: string): Promise<ResolvedCheckoutRow> {
  const { data, error } = await supabase
    .from("billing_invoices")
    .select("amount_due, currency_code, profile_id, organization_id, seller_profile_id, status, metadata")
    .eq("id", rowId)
    .maybeSingle();
  if (error || !data) throw new CheckoutError("INVOICE_NOT_FOUND", 404);
  if (data.status === "paid") throw new CheckoutError("ALREADY_PAID", 409);

  let owns = data.profile_id === userId;

  if (!owns && data.organization_id) {
    const { data: membership } = await supabase
      .from("organization_memberships")
      .select("status")
      .eq("organization_id", data.organization_id)
      .eq("profile_id", userId)
      .eq("status", "active")
      .maybeSingle();
    owns = Boolean(membership);
  }

  if (!owns && data.seller_profile_id) {
    const { data: seller } = await supabase
      .from("marketplace_seller_profiles")
      .select("owner_id")
      .eq("id", data.seller_profile_id)
      .maybeSingle();
    owns = seller?.owner_id === userId;
  }

  if (!owns) throw new CheckoutError("FORBIDDEN", 403);
  // create_subscription_invoice (supabase/migrations/20261028160000_*.sql) stamps the invoice's
  // own metadata.redirect_path with where the buyer should land after paying (their club's
  // manage page, or the tournament organizer page) -- fall back to /business for older invoices
  // created before that metadata existed (e.g. marketplace seller invoices).
  const metadata = (data as { metadata?: Record<string, unknown> | null }).metadata;
  const redirectPath = typeof metadata?.redirect_path === "string" ? metadata.redirect_path : "/business";
  return { amount: Number(data.amount_due), currencyCode: data.currency_code ?? "COP", redirectPath };
}

export const CHECKOUT_RESOLVERS: Record<
  CheckoutDomain,
  (supabase: SupabaseServerClient, userId: string, rowId: string) => Promise<ResolvedCheckoutRow>
> = {
  booking: resolveBooking,
  tournament: resolveTournament,
  marketplace: resolveMarketplace,
  billing: resolveBilling,
};
