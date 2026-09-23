import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { toSafeMessage } from "@/lib/safe-error";
import { buildWompiCheckoutConfig, type WompiDomain } from "@/lib/dynasty/wompi";

export const dynamic = "force-dynamic";

const ALLOWED_DOMAINS = new Set<WompiDomain>(["shop", "booking", "tournament", "marketplace", "billing"]);

type Resolved = { amount: number; currencyCode: string; redirectPath: string };

class CheckoutError extends Error {
  status: number;
  constructor(code: string, status: number) {
    super(code);
    this.status = status;
  }
}

type SupabaseServerClient = Awaited<ReturnType<typeof createClient>>;

async function resolveShop(supabase: SupabaseServerClient, userId: string, rowId: string): Promise<Resolved> {
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

async function resolveBooking(supabase: SupabaseServerClient, userId: string, rowId: string): Promise<Resolved> {
  const { data: booking, error: bookingError } = await supabase
    .from("bookings")
    .select("id, booked_by")
    .eq("id", rowId)
    .maybeSingle();
  if (bookingError || !booking) throw new CheckoutError("BOOKING_NOT_FOUND", 404);
  if (booking.booked_by !== userId) throw new CheckoutError("FORBIDDEN", 403);

  const { data: payment, error: paymentError } = await supabase
    .from("booking_payment_records")
    .select("amount_due, currency_code, payment_status")
    .eq("booking_id", rowId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (paymentError || !payment) throw new CheckoutError("BOOKING_PAYMENT_NOT_FOUND", 404);
  if (payment.payment_status === "paid") throw new CheckoutError("ALREADY_PAID", 409);
  return { amount: Number(payment.amount_due), currencyCode: payment.currency_code ?? "COP", redirectPath: `/bookings/${rowId}` };
}

async function resolveTournament(supabase: SupabaseServerClient, userId: string, rowId: string): Promise<Resolved> {
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

async function resolveMarketplace(supabase: SupabaseServerClient, userId: string, rowId: string): Promise<Resolved> {
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

async function resolveBilling(supabase: SupabaseServerClient, userId: string, rowId: string): Promise<Resolved> {
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

const RESOLVERS: Record<WompiDomain, typeof resolveShop> = {
  shop: resolveShop,
  booking: resolveBooking,
  tournament: resolveTournament,
  marketplace: resolveMarketplace,
  billing: resolveBilling,
};

export async function POST(request: Request) {
  const supabase = await createClient();
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();
  if (authError || !user) {
    return NextResponse.json({ error: "AUTH_REQUIRED" }, { status: 401 });
  }

  const body = await request.json().catch(() => ({}));
  const domain = typeof body?.domain === "string" ? (body.domain as WompiDomain) : undefined;
  const rowId = typeof body?.rowId === "string" ? body.rowId : "";

  if (!domain || !ALLOWED_DOMAINS.has(domain)) {
    return NextResponse.json({ error: "INVALID_DOMAIN" }, { status: 400 });
  }
  if (!rowId) {
    return NextResponse.json({ error: "ROW_ID_REQUIRED" }, { status: 400 });
  }

  try {
    const resolver = RESOLVERS[domain];
    const resolved = await resolver(supabase, user.id, rowId);

    const origin = request.headers.get("origin") ?? new URL(request.url).origin;
    const config = await buildWompiCheckoutConfig({
      domain,
      rowId,
      amount: resolved.amount,
      currencyCode: resolved.currencyCode,
      redirectPath: resolved.redirectPath,
      origin,
    });

    return NextResponse.json(config);
  } catch (err) {
    if (err instanceof CheckoutError) {
      return NextResponse.json({ error: err.message }, { status: err.status });
    }
    const message = err instanceof Error ? err.message : "CHECKOUT_INIT_FAILED";
    if (message === "WOMPI_PUBLIC_KEY_MISSING" || message === "WOMPI_INTEGRITY_SECRET_MISSING") {
      return NextResponse.json({ error: "PAYMENT_PROVIDER_NOT_CONFIGURED" }, { status: 503 });
    }
    if (message === "UNSUPPORTED_CURRENCY" || message === "INVALID_AMOUNT") {
      return NextResponse.json({ error: message }, { status: 422 });
    }
    console.error("checkout/wompi: unexpected error", err);
    return NextResponse.json({ error: toSafeMessage(err, "checkout/wompi") }, { status: 500 });
  }
}
