import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { toSafeMessage } from "@/lib/safe-error";
import { buildEpaycoCheckout, type EpaycoDomain } from "@/lib/dynasty/epayco";
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

  // Hasta 20 intentos de iniciar un pago por hora por usuario.
  const allowed = await checkRateLimit(supabase, `checkout_epayco:${user.id}`, 20, 3600);
  if (!allowed) {
    return NextResponse.json({ error: "RATE_LIMITED" }, { status: 429 });
  }

  // NEXT_PUBLIC_EPAYCO_PUBLIC_KEY is what the client actually needs to open the widget, but
  // checking it here too means a missing/unconfigured key surfaces as the same
  // PAYMENT_PROVIDER_NOT_CONFIGURED shape every other checkout error goes through, instead
  // of a raw ePayco script failure with no context.
  if (!process.env.NEXT_PUBLIC_EPAYCO_PUBLIC_KEY) {
    return NextResponse.json({ error: "PAYMENT_PROVIDER_NOT_CONFIGURED" }, { status: 503 });
  }

  const body = await request.json().catch(() => ({}));
  const domain = typeof body?.domain === "string" ? (body.domain as EpaycoDomain) : undefined;
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
    const config = buildEpaycoCheckout({
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
    if (message === "UNSUPPORTED_CURRENCY" || message === "INVALID_AMOUNT") {
      return NextResponse.json({ error: message }, { status: 422 });
    }
    console.error("checkout/epayco: unexpected error", err);
    return NextResponse.json({ error: toSafeMessage(err, "checkout/epayco") }, { status: 500 });
  }
}
