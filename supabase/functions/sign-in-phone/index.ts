// Sign in with a mobile number + password.
//
// The app sends { phone, password }. This function finds the account whose mobile number matches (profiles.phone),
// signs it in with its email and the password on the server, and returns the session. The email address is never
// sent back, and the answer for "no such number" and "wrong password" is the same, so nobody can use this to find
// out which numbers have accounts. Suspended accounts get a clear message.
//
// This function is called without a sign-in, so "Verify JWT" is off for it; it checks everything itself.
// It only uses the secrets that Supabase gives every function (SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY).
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

const WRONG = "Incorrect mobile number or password.";

/** 09XXXXXXXXX form of a typed Philippine mobile number, or null. */
function normalizePhone(raw: unknown): string | null {
  let d = String(raw ?? "").replace(/\D/g, "");
  if (d.startsWith("63") && d.length === 12) d = "0" + d.slice(2);
  else if (d.length === 10 && d.startsWith("9")) d = "0" + d;
  return /^09\d{9}$/.test(d) ? d : null;
}

// Best-effort limit: 5 wrong tries per number per minute (per running copy of the function).
const tries = new Map<string, { n: number; until: number }>();

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Use POST." }, 405);

  let body: { phone?: unknown; password?: unknown };
  try {
    body = await req.json();
  } catch {
    return reply({ error: "Bad request." }, 400);
  }
  const phone = normalizePhone(body.phone);
  const password = String(body.password ?? "");
  if (!phone) return reply({ error: "Enter a valid mobile number, e.g. 0917 555 0112." }, 400);
  if (!password) return reply({ error: "Enter your password." }, 400);

  const now = Date.now();
  const t = tries.get(phone);
  if (t && t.n >= 5 && now < t.until) {
    return reply({ error: "Too many failed attempts. Please wait a minute and try again." }, 429);
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  const { data: rows, error } = await admin.from("profiles").select("email, phone").neq("phone", "").limit(5000);
  if (error) return reply({ error: "Could not reach the database. Try again." }, 500);
  const hits = (rows ?? []).filter((r) => normalizePhone(r.phone) === phone);

  let session: unknown = null;
  let banned = false;
  if (hits.length === 1) {
    const r = await fetch(`${url}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { apikey: anon, "Content-Type": "application/json" },
      body: JSON.stringify({ email: hits[0].email, password }),
    });
    const j = await r.json().catch(() => ({}));
    if (r.ok && j.access_token) session = j;
    else if (String(j.msg ?? j.error_description ?? j.message ?? "").toLowerCase().includes("banned")) banned = true;
  }

  if (session) {
    tries.delete(phone);
    return reply({ session });
  }
  if (banned) return reply({ error: "This account has been suspended. Contact the administrator." }, 403);

  const n = (t && now < t.until ? t.n : 0) + 1;
  tries.set(phone, { n, until: now + 60_000 });
  return reply({ error: WRONG }, 401);
});
