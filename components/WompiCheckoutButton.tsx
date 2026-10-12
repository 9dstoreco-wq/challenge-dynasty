"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { CreditCard, Loader2 } from "lucide-react";

export type WompiCheckoutDomain = "booking" | "tournament" | "marketplace" | "billing";

interface WompiCheckoutConfig {
  amountInCents: number;
  currency: string;
  reference: string;
  redirectUrl: string;
  publicKey: string;
  signature: string;
}

interface WompiCheckoutButtonProps {
  domain: WompiCheckoutDomain;
  rowId: string;
  className?: string;
}

const WOMPI_SCRIPT_SRC = "https://checkout.wompi.co/widget.js";

type WompiWidgetResult = { transaction?: { status?: string; id?: string } };
type WompiWidgetInstance = { open: (callback: (result: WompiWidgetResult) => void) => void };
type WompiWidgetCtor = new (opts: {
  currency: string;
  amountInCents: number;
  reference: string;
  publicKey: string;
  signature: { integrity: string };
  redirectUrl?: string;
}) => WompiWidgetInstance;

declare global {
  interface Window {
    WidgetCheckout?: WompiWidgetCtor;
  }
}

function loadWompiScript(): Promise<void> {
  if (typeof window === "undefined") return Promise.resolve();
  if (window.WidgetCheckout) return Promise.resolve();
  const existing = document.querySelector<HTMLScriptElement>(`script[src="${WOMPI_SCRIPT_SRC}"]`);
  if (existing) {
    return new Promise((resolve) => existing.addEventListener("load", () => resolve(), { once: true }));
  }
  return new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = WOMPI_SCRIPT_SRC;
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("WOMPI_SCRIPT_LOAD_FAILED"));
    document.body.appendChild(script);
  });
}

/**
 * Renders a "Pagar con Wompi" button. On mount it asks our own server
 * (/api/checkout/wompi) to look up the real amount owed for `domain`/`rowId` -- always
 * computed server-side from lib/dynasty/checkout-resolvers.ts -- and to compute the
 * integrity signature Wompi's widget requires (lib/dynasty/wompi.ts). Unlike the previous
 * ePayco button (components/EpaycoCheckoutButton.tsx), the amount can't be tampered with
 * client-side here: without a valid server-issued signature the widget itself won't open.
 * Clicking the button loads Wompi's widget.js (once per page) and opens its hosted Web
 * Checkout. The final source of truth is still the signed event Wompi sends to
 * supabase/functions/wompi-webhook, which re-verifies the transaction against Wompi's own
 * API before marking anything paid.
 */
export function WompiCheckoutButton({ domain, rowId, className }: WompiCheckoutButtonProps) {
  const t = useTranslations("Checkout");
  const ERROR_LABELS: Record<string, string> = {
    AUTH_REQUIRED: t("authRequired"),
    ALREADY_PAID: t("alreadyPaid"),
    FORBIDDEN: t("forbidden"),
    BOOKING_CANCELLED: t("bookingCancelled"),
    PAYMENT_NOT_REQUIRED: t("paymentNotRequired"),
    PAYMENT_PROVIDER_NOT_CONFIGURED: t("notConfigured"),
    INVALID_AMOUNT: t("invalidAmount"),
    WOMPI_SCRIPT_LOAD_FAILED: t("genericError"),
  };
  const [config, setConfig] = useState<WompiCheckoutConfig | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [opening, setOpening] = useState(false);

  useEffect(() => {
    let cancelled = false;

    fetch("/api/checkout/wompi", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ domain, rowId }),
    })
      .then(async (res) => {
        const data = await res.json();
        if (!res.ok) throw new Error(typeof data?.error === "string" ? data.error : "CHECKOUT_INIT_FAILED");
        if (!cancelled) setConfig(data as WompiCheckoutConfig);
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
        className={className ?? "rounded-lg bg-[#00A99D]/50 px-6 py-3 font-bold text-white opacity-70 inline-flex items-center justify-center gap-2"}
      >
        <Loader2 size={16} className="animate-spin" /> {t("preparing")}
      </button>
    );
  }

  return (
    <button
      onClick={async () => {
        setOpening(true);
        try {
          await loadWompiScript();
          if (!window.WidgetCheckout) throw new Error("WOMPI_SCRIPT_LOAD_FAILED");

          const checkout = new window.WidgetCheckout({
            currency: config.currency,
            amountInCents: config.amountInCents,
            reference: config.reference,
            publicKey: config.publicKey,
            signature: { integrity: config.signature },
            redirectUrl: config.redirectUrl,
          });

          checkout.open((result) => {
            if (result?.transaction?.status === "APPROVED") {
              window.location.href = config.redirectUrl;
            }
          });
        } catch (err) {
          setError(err instanceof Error ? err.message : "CHECKOUT_INIT_FAILED");
        } finally {
          setOpening(false);
        }
      }}
      disabled={opening}
      className={className ?? "rounded-lg bg-[#00A99D] px-6 py-3 font-bold text-white inline-flex items-center justify-center gap-2 disabled:opacity-70"}
    >
      {opening ? <Loader2 size={16} className="animate-spin" /> : <CreditCard size={16} />} {t("payWithWompi")}
    </button>
  );
}
