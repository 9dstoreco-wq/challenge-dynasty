// Shared row-resolution logic for every "pay for X" checkout entrypoint (Wompi, Mercado
// Pago, and any future provider). Each provider's own route handler (e.g.
// app/api/checkout/wompi/route.ts, app/api/checkout/mercadopago/route.ts) imports this so
// the "which row is this payment for, how much is owed, does this user own it" logic is
// written exactly once and can't drift between providers.
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

export type CheckoutDomain = "shop" | "booking" | "tournament" | "marketplace" | "billing";

export const ALLOWED_CHECKOUT_DOMAINS = new Set<CheckoutDomain>([
  "shop",
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

async function resolveShop(supabase: SupabaseServerClient, userId: string, rowId: string): Promise<ResolvedCheckoutRow> {
  const { data, error } = await supabase
    .from("shop_orders")
    .select("total_amount, currency_code, profile_id, payment_status")
    .eq("id", rowId)
    .maybeSingle();
  if (error || !data) throw new CheckoutError("ORDER_NOT_FOUND", 404);
  if (data.profile_id !== userId) throw new CheckoutError("FORBIDDEN", 403);
  if (data.payment_status === "paid") throw new CheckoutError("ALREADY_PAID", 409);
  return { amount: Number(data.total_amount), currencyCode: data.currency_code ?? "COP", redirectPath: `/shop/orders/${rowId}` };
}

async function resolveBooking(supabase: SupabaseServerClient, userId: string, rowId: string): Promise<ResolvedCheckoutRow> {
  const { data: booking, error: bookingError } = await supabase
    .from("bookings")
    .select("id, booked_by, amount, currency_code, payment_status, status")
    .eq("id", rowId)
    .maybeSingle();
  if (bookingError || !booking) throw new CheckoutError("BOOKING_NOT_FOUND", 404);
  if (booking.booked_by !== userId) throw new CheckoutError("FORBIDDEN", 403);
  if (booking.status === "cancelled") throw new CheckoutError("BOOKING_CANCELLED", 409);
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
    .select("amount_due, currency_code, status")
    .eq("entry_id", rowId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (paymentError || !payment) throw new CheckoutError("ENTRY_PAYMENT_NOT_FOUND", 404);
  if (payment.status === "paid") throw new CheckoutError("ALREADY_PAID", 409);
  return {
    amount: Number(payment.amount_due),
    currencyCode: payment.currency_code ?? "COP",
    redirectPath: `/competitions/${entry.tournament_id}`,
  };
}

async function resolveMarketplace(supabase: SupabaseServerClient, userId: string, rowId: string): Promise<ResolvedCheckoutRow> {
  const { data, error } = await supabase
    .from("marketplace_orders")
    .select("total_amount, currency_code, buyer_id, status")
    .eq("id", rowId)
    .maybeSingle();
  if (error || !data) throw new CheckoutError("ORDER_NOT_FOUND", 404);
  if (data.buyer_id !== userId) throw new CheckoutError("FORBIDDEN", 403);
  if (data.status === "paid") throw new CheckoutError("ALREADY_PAID", 409);
  return { amount: Number(data.total_amount), currencyCode: data.currency_code ?? "COP", redirectPath: `/marketplace/orders/${rowId}` };
}

async function resolveBilling(supabase: SupabaseServerClient, userId: string, rowId: string): Promise<ResolvedCheckoutRow> {
  const { data, error } = await supabase
    .from("billing_invoices")
    .select("amount_due, currency_code, profile_id, organization_id, seller_profile_id, status")
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
  return { amount: Number(data.amount_due), currencyCode: data.currency_code ?? "COP", redirectPath: "/business" };
}

export const CHECKOUT_RESOLVERS: Record<
  CheckoutDomain,
  (supabase: SupabaseServerClient, userId: string, rowId: string) => Promise<ResolvedCheckoutRow>
> = {
  shop: resolveShop,
  booking: resolveBooking,
  tournament: resolveTournament,
  marketplace: resolveMarketplace,
  billing: resolveBilling,
};
