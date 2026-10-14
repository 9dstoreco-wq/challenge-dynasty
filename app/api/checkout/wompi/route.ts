import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { toSafeMessage } from "@/lib/safe-error";
import { buildWompiCheckout, type WompiDomain } from "@/lib/dynasty/wompi";
import { ALLOWED_CHECKOUT_DOMAINS, CHECKOUT_RESOLVERS, CheckoutError } from "@/lib/dynasty/checkout-resolvers";
import { checkRateLimit } from "@/lib/rate-limit";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const supabase = await createClient();
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();
  if (authError || !user) {
    return NextResponse.json({ error: "AUTH_REQUIRED" }, { status: 401 });
  }

  // Hasta 20 intentos de iniciar un pago por hora por usuario (mismo limite que ePayco).
  const allowed = await checkRateLimit(supabase, 'checkout_wompi', 20, 3600);
  if (!allowed) {
    return NextResponse.json({ error: "RATE_LIMITED" }, { status: 429 });
  }

  // NEXT_PUBLIC_WOMPI_PUBLIC_KEY is what the client needs to open the widget, and
  // WOMPI_INTEGRITY_SECRET is what this route needs to sign it -- checking both here means
  // a missing/unconfigured key surfaces as the same PAYMENT_PROVIDER_NOT_CONFIGURED shape
  // every other checkout error goes through, instead of a raw widget script failure.
  if (!process.env.NEXT_PUBLIC_WOMPI_PUBLIC_KEY || !process.env.WOMPI_INTEGRITY_SECRET) {
    return NextResponse.json({ error: "PAYMENT_PROVIDER_NOT_CONFIGURED" }, { status: 503 });
  }

  const body = await request.json().catch(() => ({}));
  const domain = typeof body?.domain === "string" ? (body.domain as WompiDomain) : undefined;
  const rowId = typeof body?.rowId === "string" ? body.rowId : "";

  if (!domain || !ALLOWED_CHECKOUT_DOMAINS.has(domain)) {
    return NextResponse.json({ error: "INVALID_DOMAIN" }, { status: 400 });
  }
  if (!rowId) {
    return NextResponse.json({ error: "ROW_ID_REQUIRED" }, { status: 400 });
  }

  try {
    const resolver = CHECKOUT_RESOLVERS[domain];
    const resolved = await resolver(supabase, user.id, rowId);

    const origin = request.headers.get("origin") ?? new URL(request.url).origin;
    const config = buildWompiCheckout({
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
    if (message === "PAYMENT_PROVIDER_NOT_CONFIGURED") {
      return NextResponse.json({ error: message }, { status: 503 });
    }
    if (message === "UNSUPPORTED_CURRENCY" || message === "INVALID_AMOUNT") {
      return NextResponse.json({ error: message }, { status: 422 });
    }
    console.error("checkout/wompi: unexpected error", err);
    return NextResponse.json({ error: toSafeMessage(err, "checkout/wompi") }, { status: 500 });
  }
}
