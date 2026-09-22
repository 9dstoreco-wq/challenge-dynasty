import { createClient } from "@/lib/supabase/server";
import { toSafeMessage } from "@/lib/safe-error";

export async function getDynastyAIContext() {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("get_dynasty_ai_context");
  if (error) {
    throw new Error(toSafeMessage(error, "dynasty.aiContext"));
  }
  return data;
}
