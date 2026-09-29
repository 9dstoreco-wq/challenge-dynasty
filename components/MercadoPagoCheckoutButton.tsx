"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { CreditCard, Loader2 } from "lucide-react";

export type MercadoPagoCheckoutDomain = "shop" | "booking" | "tournament" | "marketplace" | "billing";

interface MercadoPagoCheckoutConfig {
  initPoint: string;
  preferenceId: string;
}

interface MercadoPagoCheckoutButtonProps {
  domain: MercadoPagoCheckoutDomain;
  rowId: string;
  className?: string;
}

/**
 * Renders a "Pagar con Mercado Pago" button. On mount it asks our own server
 * (/api/checkout/mercadopago) to look up the real amount owed and create a Mercado Pago
 * Checkout Pro preference for it -- the preference (and the amount it's for) is always
 * computed server-side from lib/dynasty/checkout-resolvers.ts, never from anything the
 * browser sends. Once the preference comes back, clicking the button navigates the browser
 * to Mercado Pago's hosted checkout (init_point); there is no widget to mount.
 */
export function MercadoPagoCheckoutButton({ domain, rowId, className }: MercadoPagoCheckoutButtonProps) {
  const t = useTranslations("Checkout");
  const ERROR_LABELS: Record<string, string> = {
    AUTH_REQUIRED: t("authRequired"),
    ALREADY_PAID: t("alreadyPaid"),
    FORBIDDEN: t("forbidden"),
    BOOKING_CANCELLED: t("bookingCancelled"),
    PAYMENT_NOT_REQUIRED: t("paymentNotRequired"),
    PAYMENT_PROVIDER_NOT_CONFIGURED: t("notConfigured"),
    INVALID_AMOUNT: t("invalidAmount"),
  };
  const [config, setConfig] = useState<MercadoPagoCheckoutConfig | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [redirecting, setRedirecting] = useState(false);

  useEffect(() => {
    let cancelled = false;

    fetch("/api/checkout/mercadopago", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ domain, rowId }),
    })
      .then(async (res) => {
        const data = await res.json();
        if (!res.ok) throw new Error(typeof data?.error === "string" ? data.error : "CHECKOUT_INIT_FAILED");
        if (!cancelled) setConfig(data as MercadoPagoCheckoutConfig);
      })
      .catch((err) => {
        if (!cancelled) setError(err instanceof Error ? err.message : "CHECKOUT_INIT_FAILED");
      });

    return () => {
      cancelled = true;
    };
  }, [domain, rowId]);

  if (error) {
    return (
      <p className="text-sm text-challenge-fire">
        {ERROR_LABELS[error] ?? t("genericError")}
      </p>
    );
  }

  if (!config) {
    return (
      <button
        disabled
        className={className ?? "rounded-lg bg-[#009EE3]/50 px-6 py-3 font-bold text-white opacity-70 inline-flex items-center justify-center gap-2"}
      >
        <Loader2 size={16} className="animate-spin" /> {t("preparing")}
      </button>
    );
  }

  return (
    <button
      onClick={() => {
        setRedirecting(true);
        window.location.href = config.initPoint;
      }}
      disabled={redirecting}
      className={className ?? "rounded-lg bg-[#009EE3] px-6 py-3 font-bold text-white inline-flex items-center justify-center gap-2 disabled:opacity-70"}
    >
      {redirecting ? <Loader2 size={16} className="animate-spin" /> : <CreditCard size={16} />} {t("payWithMercadoPago")}
    </button>
  );
}
