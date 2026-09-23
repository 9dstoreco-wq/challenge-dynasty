"use client";

import { useEffect, useRef, useState } from "react";

export type WompiCheckoutDomain = "shop" | "booking" | "tournament" | "marketplace" | "billing";

interface WompiCheckoutConfig {
  publicKey: string;
  currency: string;
  amountInCents: number;
  reference: string;
  signatureIntegrity: string;
  redirectUrl: string;
}

interface WompiCheckoutButtonProps {
  domain: WompiCheckoutDomain;
  rowId: string;
  className?: string;
}

const ERROR_LABELS: Record<string, string> = {
  AUTH_REQUIRED: "Inicia sesión para pagar.",
  ALREADY_PAID: "Esto ya está pagado.",
  FORBIDDEN: "No tienes acceso a este pago.",
  PAYMENT_PROVIDER_NOT_CONFIGURED: "Pagos aún no disponibles.",
  INVALID_AMOUNT: "Monto inválido para cobrar.",
};

/**
 * Renders a "Pagar con Wompi" button. On mount it asks our own server
 * (/api/checkout/wompi) to look up the real amount owed and sign a Wompi Web Checkout
 * config for it — the integrity signature is never computed in the browser. Once that
 * config comes back, it injects Wompi's own widget script (checkout.wompi.co/widget.js),
 * which renders the actual payment button and opens Wompi's modal on click.
 */
export function WompiCheckoutButton({ domain, rowId, className }: WompiCheckoutButtonProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [config, setConfig] = useState<WompiCheckoutConfig | null>(null);
  const [error, setError] = useState<string | null>(null);

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

  useEffect(() => {
    if (!config || !containerRef.current) return;
    containerRef.current.innerHTML = "";

    const form = document.createElement("form");
    const script = document.createElement("script");
    script.src = "https://checkout.wompi.co/widget.js";
    script.setAttribute("data-render", "button");
    script.setAttribute("data-public-key", config.publicKey);
    script.setAttribute("data-currency", config.currency);
    script.setAttribute("data-amount-in-cents", String(config.amountInCents));
    script.setAttribute("data-reference", config.reference);
    script.setAttribute("data-signature:integrity", config.signatureIntegrity);
    script.setAttribute("data-redirect-url", config.redirectUrl);

    form.appendChild(script);
    containerRef.current.appendChild(form);
  }, [config]);

  if (error) {
    return (
      <p className="text-sm text-challenge-fire">
        {ERROR_LABELS[error] ?? "No se pudo iniciar el pago. Intenta de nuevo."}
      </p>
    );
  }

  if (!config) {
    return (
      <button
        disabled
        className={className ?? "rounded-lg bg-gold-500/50 px-6 py-3 font-bold text-black opacity-70"}
      >
        Preparando pago…
      </button>
    );
  }

  return <div ref={containerRef} />;
}
