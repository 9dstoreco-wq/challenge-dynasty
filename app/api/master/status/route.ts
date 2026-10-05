import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { toSafeMessage } from "@/lib/safe-error";

export const dynamic = "force-dynamic";

export async function GET() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ isAdmin: false });
  }

  const { data, error } = await supabase.rpc("is_platform_admin");
  if (error) {
    toSafeMessage(error, "master.status.isPlatformAdmin"); // registra el detalle solo en logs del servidor
    return NextResponse.json({ isAdmin: false });
  }

  return NextResponse.json({ isAdmin: data === true });
}
