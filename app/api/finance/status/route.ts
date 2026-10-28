import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { toSafeMessage } from "@/lib/safe-error";

export const dynamic = "force-dynamic";

// AUDITORIA DE NAV (2026-10-28): "Finanzas" aparecia en el menu para TODOS los usuarios, incluso
// cuando las 4 tablas que esa pagina muestra (finance_accounts, finance_transactions,
// payment_records, finance_invoices) estaban vacias para el 100% de las cuentas en produccion.
// Luis decidio ocultarla hasta que el usuario tenga algo real que ver ahi. Este endpoint hace
// ese chequeo (igual que /api/club/status) para que Sidebar/BottomNav decidan si mostrarla.
export async function GET() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ hasActivity: false });
  }

  const [accounts, transactions, payments, invoices] = await Promise.all([
    supabase.from("finance_accounts").select("id").eq("profile_id", user.id).limit(1),
    supabase.from("finance_transactions").select("id").eq("profile_id", user.id).limit(1),
    supabase.from("payment_records").select("id").eq("payer_profile_id", user.id).limit(1),
    supabase.from("finance_invoices").select("id").eq("profile_id", user.id).limit(1),
  ]);

  for (const [label, result] of [
    ["accounts", accounts],
    ["transactions", transactions],
    ["payments", payments],
    ["invoices", invoices],
  ] as const) {
    if (result.error) toSafeMessage(result.error, `finance.status.${label}`); // registra el detalle solo en logs del servidor
  }

  const hasActivity = Boolean(
    accounts.data?.length || transactions.data?.length || payments.data?.length || invoices.data?.length
  );

  return NextResponse.json({ hasActivity });
}
