import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { toSafeMessage } from "@/lib/safe-error";

export const dynamic = "force-dynamic";

const FUNCTION_NAME = "dynasty-ai-chat";
const MAX_MESSAGE_LENGTH = 4000;
const ALLOWED_MODES = new Set(["coach", "fitness", "club", "coach_business", "tournament", "commerce"]);

const rateWindow = new Map<string, { startedAt: number; count: number }>();
const RATE_LIMIT = 20;
const RATE_WINDOW_MS = 60_000;

function rateLimitKey(request: Request, userId: string) {
  const forwarded = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  return `${userId}:${forwarded || "unknown"}`;
}

function allowedRequest(key: string) {
  const now = Date.now();
  const current = rateWindow.get(key);
  if (!current || now - current.startedAt >= RATE_WINDOW_MS) {
    rateWindow.set(key, { startedAt: now, count: 1 });
    return true;
  }
  if (current.count >= RATE_LIMIT) return false;
  current.count += 1;
  return true;
}

export async function POST(request: Request) {
  const supabase = await createClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser();

  if (authError || !user) {
    return NextResponse.json({ error: "AUTH_REQUIRED" }, { status: 401 });
  }

  const key = rateLimitKey(request, user.id);
  if (!allowedRequest(key)) {
    return NextResponse.json({ error: "RATE_LIMITED" }, { status: 429, headers: { "Retry-After": "60" } });
  }

  const contentLength = Number(request.headers.get("content-length") || 0);
  if (contentLength > 12000) {
    return NextResponse.json({ error: "PAYLOAD_TOO_LARGE" }, { status: 413 });
  }

  const body = await request.json().catch(() => ({}));
  const message = typeof body?.message === "string" ? body.message.trim() : "";
  const mode = typeof body?.mode === "string" ? body.mode : "coach";

  if (!message) {
    return NextResponse.json({ error: "MESSAGE_REQUIRED" }, { status: 400 });
  }
  if (message.length > MAX_MESSAGE_LENGTH) {
    return NextResponse.json({ error: "MESSAGE_TOO_LONG" }, { status: 413 });
  }
  if (!ALLOWED_MODES.has(mode)) {
    return NextResponse.json({ error: "INVALID_MODE" }, { status: 400 });
  }

  const { data, error } = await supabase.functions.invoke(FUNCTION_NAME, {
    body: { message, mode },
  });

  if (error) {
    return NextResponse.json(
      { error: "AI_FUNCTION_ERROR", detail: toSafeMessage(error, "api.dynasty-ai.chat") },
      { status: 502 }
    );
  }

  return NextResponse.json(data);
}
