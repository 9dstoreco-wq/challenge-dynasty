import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
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

  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: auth } },
  });
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) return json({ error: "AUTH_INVALID" }, 401);

  const body = await req.json().catch(() => ({}));
  const message = typeof body?.message === "string" ? body.message.trim() : "";
  const mode = typeof body?.mode === "string" ? body.mode : "coach";
  const allowedModes = ["coach", "fitness", "club", "coach_business", "tournament", "commerce"];
  if (!message) return json({ error: "MESSAGE_REQUIRED" }, 400);
  if (!allowedModes.includes(mode)) return json({ error: "INVALID_MODE" }, 400);

  const { data: context, error: contextError } = await supabase.rpc("get_dynasty_ai_context");
  if (contextError) return json({ error: "CONTEXT_ERROR", detail: contextError.message }, 500);

  const { data: memory, error: memoryError } = await supabase.rpc("get_dynasty_ai_memory", {
    p_profile_id: context?.profile_id ?? userData.user.id,
    p_scope: mode === "coach" ? "athlete" : mode,
  });
  if (memoryError) return json({ error: "MEMORY_ERROR", detail: memoryError.message }, 500);

  const profileId = context?.profile_id ?? userData.user.id;
  let { data: conversation } = await supabase
    .from("ai_conversations")
    .select("id")
    .eq("profile_id", profileId)
    .eq("mode", mode)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!conversation) {
    const { data: created, error: createError } = await supabase
      .from("ai_conversations")
      .insert({ profile_id: profileId, mode, title: `Dynasty ${mode}` })
      .select("id")
      .single();

    if (createError) {
      return json({ error: "CONVERSATION_CREATE_ERROR", detail: createError.message }, 500);
    }
    conversation = created;
  }

  const { error: userMessageError } = await supabase.from("ai_messages").insert({
    conversation_id: conversation.id,
    profile_id: profileId,
    role: "user",
    content: message,
    metadata: { mode },
  });
  if (userMessageError) {
    return json({ error: "MESSAGE_SAVE_ERROR", detail: userMessageError.message }, 500);
  }

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
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${openaiKey}`,
    },
    body: JSON.stringify({
      model: Deno.env.get("DYNASTY_AI_MODEL") || "gpt-5.6",
      input: [
        { role: "system", content: [{ type: "input_text", text: system }] },
        { role: "user", content: [{ type: "input_text", text: message }] },
      ],
    }),
  });

  if (!openaiResp.ok) {
    return json({ error: "MODEL_PROVIDER_ERROR", detail: await openaiResp.text() }, 502);
  }

  const completion = await openaiResp.json();
  const responseText = typeof completion?.output_text === "string" ? completion.output_text : "";
  if (!responseText) return json({ error: "MODEL_EMPTY_RESPONSE" }, 502);

  const usage = completion?.usage ?? {};
  const inputTokens = Number(usage?.input_tokens ?? usage?.prompt_tokens ?? 0) || 0;
  const outputTokens = Number(usage?.output_tokens ?? usage?.completion_tokens ?? 0) || 0;

  const { error: assistantMessageError } = await supabase.from("ai_messages").insert({
    conversation_id: conversation.id,
    profile_id: profileId,
    role: "assistant",
    content: responseText,
    metadata: { mode, model: completion?.model ?? null, response_id: completion?.id ?? null },
  });

  if (assistantMessageError) {
    return json({ error: "ASSISTANT_SAVE_ERROR", detail: assistantMessageError.message }, 500);
  }

  await supabase.from("ai_usage_events").insert({
    profile_id: profileId,
    mode,
    provider: "openai",
    model: completion?.model ?? Deno.env.get("DYNASTY_AI_MODEL") ?? "gpt-5.6",
    input_tokens: inputTokens,
    output_tokens: outputTokens,
    metadata: { response_id: completion?.id ?? null },
  });

  if (mode === "coach") await supabase.rpc("mark_ai_daily_coach_completed");

  return json({
    ok: true,
    response: responseText,
    conversation_id: conversation.id,
    response_id: completion?.id ?? null,
  });
});
