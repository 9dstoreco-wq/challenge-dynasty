"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { CreditCard, Loader2 } from "lucide-react";

export type EpaycoCheckoutDomain = "shop" | "booking" | "tournament" | "marketplace" | "billing";

interface EpaycoCheckoutConfig {
  amount: number;
  currencyCode: string;
  description: string;
  invoice: string;
  redirectUrl: string;
}

interface EpaycoCheckoutButtonProps {
  domain: EpaycoCheckoutDomain;
  rowId: string;
  className?: string;
}

const EPAYCO_SCRIPT_SRC = "https://checkout.epayco.co/checkout.js";

type EpaycoHandler = { open: (data: Record<string, string>) => void };

declare global {
  interface Window {
    ePayco?: {
      checkout: {
        configure: (opts: { key: string; test: boolean }) => EpaycoHandler;
      };
    };
  }
}

function loadEpaycoScript(): Promise<void> {
  if (typeof window === "undefined") return Promise.resolve();
  if (window.ePayco) return Promise.resolve();
  const existing = document.querySelector<HTMLScriptElement>(`script[src="${EPAYCO_SCRIPT_SRC}"]`);
  if (existing) {
    return new Promise((resolve) => existing.addEventListener("load", () => resolve(), { once: true }));
  }
  return new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = EPAYCO_SCRIPT_SRC;
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("EPAYCO_SCRIPT_LOAD_FAILED"));
    document.body.appendChild(script);
  });
}

/**
 * Renders a "Pagar con ePayco" button. On mount it asks our own server
 * (/api/checkout/epayco) to look up the real amount owed for `domain`/`rowId` -- always
 * computed server-side from lib/dynasty/checkout-resolvers.ts, never from anything the
 * browser sends. Clicking the button loads ePayco's own checkout.js (once per page) and
 * opens its hosted "Standard Checkout" widget with that amount. The final source of truth
 * is the signed confirmation webhook ePayco sends to supabase/functions/epayco-webhook,
 * which re-validates the amount against the row itself before marking anything paid (see
 * the comment at the top of lib/dynasty/epayco.ts).
 */
export function EpaycoCheckoutButton({ domain, rowId, className }: EpaycoCheckoutButtonProps) {
  const t = useTranslations("Checkout");
  const ERROR_LABELS: Record<string, string> = {
    AUTH_REQUIRED: t("authRequired"),
    ALREADY_PAID: t("alreadyPaid"),
    FORBIDDEN: t("forbidden"),
    BOOKING_CANCELLED: t("bookingCancelled"),
    PAYMENT_NOT_REQUIRED: t("paymentNotRequired"),
    PAYMENT_PROVIDER_NOT_CONFIGURED: t("notConfigured"),
    INVALID_AMOUNT: t("invalidAmount"),
    EPAYCO_SCRIPT_LOAD_FAILED: t("genericError"),
  };
  const [config, setConfig] = useState<EpaycoCheckoutConfig | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [opening, setOpening] = useState(false);
  const handlerRef = useRef<EpaycoHandler | null>(null);

  useEffect(() => {
    let cancelled = false;

    fetch("/api/checkout/epayco", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ domain, rowId }),
    })
      .then(async (res) => {
        const data = await res.json();
        if (!res.ok) throw new Error(typeof data?.error === "string" ? data.error : "CHECKOUT_INIT_FAILED");
        if (!cancelled) setConfig(data as EpaycoCheckoutConfig);
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
          const publicKey = process.env.NEXT_PUBLIC_EPAYCO_PUBLIC_KEY ?? "";
          const testMode = process.env.NEXT_PUBLIC_EPAYCO_TEST_MODE !== "false";
          const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";

          await loadEpaycoScript();
          if (!window.ePayco) throw new Error("EPAYCO_SCRIPT_LOAD_FAILED");

          if (!handlerRef.current) {
            handlerRef.current = window.ePayco.checkout.configure({ key: publicKey, test: testMode });
          }

          handlerRef.current.open({
            amount: String(config.amount),
            tax_base: "0",
            tax: "0",
            name: config.description,
            description: config.description,
            currency: config.currencyCode.toLowerCase(),
            country: "co",
            invoice: config.invoice,
            extra1: config.invoice,
            external: "false",
            response: config.redirectUrl,
            confirmation: `${supabaseUrl}/functions/v1/epayco-webhook`,
            methodconfirmation: "POST",
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
      {opening ? <Loader2 size={16} className="animate-spin" /> : <CreditCard size={16} />} {t("payWithEpayco")}
    </button>
  );
}
