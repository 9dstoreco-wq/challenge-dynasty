import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

// Modes that are part of the free/base product (personal daily coaching) — never gated.
const FREE_MODES = new Set(["coach", "fitness"]);

// Modes that are the premium, revenue-facing product: clubs, coaches (business side), and
// tournament organizers. Each maps to the feature_key that must exist as an active
// billing_entitlements row (for the user's profile, or for an organization they own) before
// the mode is usable. A user holding "ai.enterprise.full" bypasses all of these.
const MODE_FEATURE_KEY: Record<string, string | null> = {
  coach: null,
  fitness: null,
  club: "ai.club.access",
  coach_business: "ai.coach_business.access",
  tournament: "ai.tournament.access",
  commerce: "ai.commerce.access",
};

const ENTERPRISE_FEATURE_KEY = "ai.enterprise.full";

async function hasModeAccess(
  supabase: ReturnType<typeof createClient>,
  profileId: string,
  mode: string
): Promise<boolean> {
  if (FREE_MODES.has(mode)) return true;
  const featureKey = MODE_FEATURE_KEY[mode];
  if (!featureKey) return true;

  const { data: enterprise } = await supabase.rpc("has_billing_entitlement", {
    p_feature_key: ENTERPRISE_FEATURE_KEY,
    p_profile_id: profileId,
  });
  if (enterprise) return true;

  const { data: profileEntitled } = await supabase.rpc("has_billing_entitlement", {
    p_feature_key: featureKey,
    p_profile_id: profileId,
  });
  if (profileEntitled) return true;

  const { data: ownedOrgs } = await supabase
    .from("organizations")
    .select("id")
    .eq("owner_id", profileId);

  for (const org of (ownedOrgs as Array<{ id: string }> | null) ?? []) {
    const { data: orgEntitled } = await supabase.rpc("has_billing_entitlement", {
      p_feature_key: featureKey,
      p_organization_id: org.id,
    });
    if (orgEntitled) return true;
  }

  return false;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) return json({ error: "AUTH_REQUIRED" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  if (!supabaseUrl || !anonKey) return json({ error: "SUPABASE_CONFIG_MISSING" }, 500);
  if (!openaiKey) return json({ error: "AI_PROVIDER_NOT_CONFIGURED" }, 503);

  const supabase = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: auth } } });
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) return json({ error: "AUTH_INVALID" }, 401);

  const body = await req.json().catch(() => ({}));
  const message = typeof body?.message === "string" ? body.message.trim() : "";
  const mode = typeof body?.mode === "string" ? body.mode : "coach";
  const allowedModes = ["coach", "fitness", "club", "coach_business", "tournament", "commerce"];
  if (!message) return json({ error: "MESSAGE_REQUIRED" }, 400);
  if (message.length > 4000) return json({ error: "MESSAGE_TOO_LONG" }, 400);
  if (!allowedModes.includes(mode)) return json({ error: "INVALID_MODE" }, 400);

  const profileId = userData.user.id;

  const modeAllowed = await hasModeAccess(supabase, profileId, mode);
  if (!modeAllowed) {
    return json({ error: "PLAN_REQUIRED", feature: MODE_FEATURE_KEY[mode] }, 402);
  }

  const { data: reservationId, error: gateError } = await supabase.rpc("reserve_ai_request", { p_feature_key: "ai.chat", p_hour_limit: 30 });
  if (gateError) {
    if (gateError.message?.includes("AI_RATE_LIMITED")) return json({ error: "AI_RATE_LIMITED" }, 429);
    return json({ error: "AI_USAGE_GATE_ERROR", detail: gateError.message }, 503);
  }

  const releaseReservation = async () => { await supabase.rpc("release_ai_request_reservation", { p_reservation_id: reservationId }); };

  try {
    const { data: context, error: contextError } = await supabase.rpc("get_dynasty_ai_context");
    if (contextError) throw new Error(`CONTEXT_ERROR: ${contextError.message}`);

    const { data: memory, error: memoryError } = await supabase.rpc("get_dynasty_ai_memory", { p_profile_id: userData.user.id, p_scope: mode === "coach" ? "athlete" : mode });
    if (memoryError) throw new Error(`MEMORY_ERROR: ${memoryError.message}`);

    let { data: conversation } = await supabase.from("ai_conversations").select("id").eq("profile_id", profileId).eq("mode", mode).order("updated_at", { ascending: false }).limit(1).maybeSingle();
    if (!conversation) {
      const { data: created, error: createError } = await supabase.from("ai_conversations").insert({ profile_id: profileId, mode, title: `Dynasty ${mode}` }).select("id").single();
      if (createError) throw new Error(`CONVERSATION_CREATE_ERROR: ${createError.message}`);
      conversation = created;
    }

    const { error: userMessageError } = await supabase.from("ai_messages").insert({ conversation_id: conversation.id, profile_id: profileId, role: "user", content: message, metadata: { mode } });
    if (userMessageError) throw new Error(`MESSAGE_SAVE_ERROR: ${userMessageError.message}`);

    const system = [
      "You are Dynasty Coach AI, a premium daily sports and fitness coach inside the Dynasty ecosystem.",
      "Answer in clear Spanish unless the user asks for another language.",
      "Use only the authorized Dynasty context and memory. Never invent account, club, purchase, financial, or performance facts.",
      "For medical or clinical issues, encourage appropriate professional evaluation rather than diagnosing.",
      `Mode: ${mode}`,
      `Authorized context: ${JSON.stringify(context ?? {})}`,
      `Long-term memory: ${JSON.stringify(memory ?? [])}`,
    ].join("\n\n");

    const openaiResp = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${openaiKey}` },
      body: JSON.stringify({ model: Deno.env.get("DYNASTY_AI_MODEL") || "gpt-5.6", input: [
        { role: "system", content: [{ type: "input_text", text: system }] },
        { role: "user", content: [{ type: "input_text", text: message }] },
      ] }),
    });

    if (!openaiResp.ok) {
      const errBody = await openaiResp.text().catch(() => "");
      throw new Error(`MODEL_PROVIDER_ERROR: [${openaiResp.status}] ${errBody.slice(0, 500)}`);
    }
    const completion = await openaiResp.json();
    const responseText = typeof completion?.output_text === "string" ? completion.output_text : "";
    if (!responseText) throw new Error(`MODEL_EMPTY_RESPONSE: ${JSON.stringify(completion).slice(0, 500)}`);

    const usage = completion?.usage ?? {};
    const inputTokens = Number(usage?.input_tokens ?? usage?.prompt_tokens ?? 0) || 0;
    const outputTokens = Number(usage?.output_tokens ?? usage?.completion_tokens ?? 0) || 0;
    const model = completion?.model ?? Deno.env.get("DYNASTY_AI_MODEL") ?? "gpt-5.6";
    const responseId = completion?.id ?? null;

    const { error: assistantMessageError } = await supabase.from("ai_messages").insert({ conversation_id: conversation.id, profile_id: profileId, role: "assistant", content: responseText, metadata: { mode, model, response_id: responseId } });
    if (assistantMessageError) throw new Error(`ASSISTANT_SAVE_ERROR: ${assistantMessageError.message}`);

    const { error: usageError } = await supabase.from("ai_usage_events").insert({ profile_id: profileId, feature_key: "ai.chat", model, input_tokens: inputTokens, output_tokens: outputTokens, request_id: responseId ?? `reservation:${reservationId}` });
    if (usageError) throw new Error(`USAGE_SAVE_ERROR: ${usageError.message}`);

    await releaseReservation();
    if (mode === "coach") await supabase.rpc("mark_ai_daily_coach_completed");
    return json({ ok: true, response: responseText, conversation_id: conversation.id, response_id: responseId });
  } catch (error) {
    await releaseReservation();
    const fullMessage = error instanceof Error ? error.message : "AI_REQUEST_FAILED";
    const code = fullMessage.split(":")[0].trim();
    const status = code === "AI_RATE_LIMITED" ? 429 : code === "MODEL_PROVIDER_ERROR" ? 502 : 500;
    return json({ error: code, detail: fullMessage }, status);
  }
});
