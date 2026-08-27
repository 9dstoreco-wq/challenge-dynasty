import { createClient } from "@/lib/supabase/server";

export async function getDynastyAIContext() {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("get_dynasty_ai_context");
  if (error) {
    throw new Error(`Dynasty AI context error: ${error.message}`);
  }
  return data;
}
