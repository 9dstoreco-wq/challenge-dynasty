import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export async function POST() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ ready: false, error: "AUTH_REQUIRED" }, { status: 401 });
  }

  const { error } = await supabase.rpc("get_or_create_daily_coach_session", {
    p_mode: "coach",
    p_plan: {},
  });

  if (error) {
    return NextResponse.json({ ready: false, error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ready: true });
}
