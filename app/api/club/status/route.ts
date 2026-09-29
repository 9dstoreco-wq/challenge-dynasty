import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export async function GET() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ ownsClub: false, organizationId: null, organizationName: null });
  }

  const { data, error } = await supabase
    .from("organizations")
    .select("id,name")
    .eq("owner_id", user.id)
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();

  if (error) {
    console.error("club/status: organizations lookup failed", error.message);
    return NextResponse.json({ ownsClub: false, organizationId: null, organizationName: null });
  }

  return NextResponse.json({
    ownsClub: Boolean(data),
    organizationId: data?.id ?? null,
    organizationName: data?.name ?? null,
  });
}
