import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { toSafeMessage } from "@/lib/safe-error";
import { buildMercadoPagoPreference, type MercadoPagoDomain } from "@/lib/dynasty/mercadopago";
import { ALLOWED_CHECKOUT_DOMAINS, CHECKOUT_RESOLVERS, CheckoutError } from "@/lib/dynasty/checkout-resolvers";

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

  const body = await request.json().catch(() => ({}));
  const domain = typeof body?.domain === "string" ? (body.domain as MercadoPagoDomain) : undefined;
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
    const config = await buildMercadoPagoPreference({
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
    if (message === "MERCADOPAGO_ACCESS_TOKEN_MISSING" || message === "SUPABASE_URL_MISSING") {
      return NextResponse.json({ error: "PAYMENT_PROVIDER_NOT_CONFIGURED" }, { status: 503 });
    }
    if (message === "UNSUPPORTED_CURRENCY" || message === "INVALID_AMOUNT") {
      return NextResponse.json({ error: message }, { status: 422 });
    }
    console.error("checkout/mercadopago: unexpected error", err);
    return NextResponse.json({ error: toSafeMessage(err, "checkout/mercadopago") }, { status: 500 });
  }
}
