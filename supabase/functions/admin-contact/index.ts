// Lets the signed-in ADMINISTRATOR add or change their own mobile number or email address.
//
// The new value is not saved until the administrator types the 6-digit code that was sent to it:
//   action "send":  { channel: "sms" | "email", value }        - sends a code to the NEW number / email
//   action "check": { channel, value, code }                    - checks the code, then saves the new value
//
// For "sms" the value is a Philippine mobile number and the code is sent by text message.
// For "email" the code is sent to the new address, and the sign-in email is changed once it is confirmed.
// Residents cannot use this: their number and email are managed by the administrator.
//
// Uses the same secrets as verify-contact (SMTP_* and SMS_PROVIDER + provider keys: twilio, semaphore or httpsms).
import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.16";

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

const CODE_MINUTES = 10;
const MAX_ATTEMPTS = 5;
const COOLDOWN_SECONDS = 60;
const MAX_SENDS_PER_HOUR = 5;
const PHONE_MSG = "Enter a valid Philippine mobile number, e.g. 0917 123 4567.";

function newCode(): string {
  const n = crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
  return n.toString().padStart(6, "0");
}

// The code is tied to the account, the way it was sent AND the exact new value, so a code for one number can never confirm another.
async function hash(userId: string, channel: string, value: string, code: string): Promise<string> {
  const data = new TextEncoder().encode(`change|${userId}|${channel}|${value}|${code}`);
  const buf = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(buf), (b) => b.toString(16).padStart(2, "0")).join("");
}

/** "0917 123 4567", "+63 917 123 4567", "9171234567" -> "09171234567" (null if not a PH mobile). */
function normalizePhone(raw: unknown): string | null {
  let d = String(raw ?? "").replace(/[^\d+]/g, "");
  if (d.startsWith("+")) d = d.slice(1);
  if (d.startsWith("63")) d = d.slice(2);
  else if (d.startsWith("0")) d = d.slice(1);
  return /^9\d{9}$/.test(d) ? `0${d}` : null;
}
const intl = (p: string) => `+63${p.slice(1)}`;

function maskEmail(e: string): string {
  const [u, d] = e.split("@");
  return `${u.slice(0, 2)}${"*".repeat(Math.max(1, u.length - 2))}@${d}`;
}
function maskPhone(p: string): string {
  const i = intl(p);
  return `${i.slice(0, 5)}${"*".repeat(Math.max(1, i.length - 8))}${i.slice(-3)}`;
}

function smsProvider(): string {
  const p = (Deno.env.get("SMS_PROVIDER") ?? "").toLowerCase();
  if (p) return p;
  return Deno.env.get("TWILIO_ACCOUNT_SID") ? "twilio" : "";
}

async function sendEmail(to: string, code: string) {
  const host = Deno.env.get("SMTP_HOST"), user = Deno.env.get("SMTP_USER"), pass = Deno.env.get("SMTP_PASS");
  if (!host || !user || !pass) throw new Error("Email sending is not set up yet.");
  const port = Number(Deno.env.get("SMTP_PORT") ?? "465");
  const transport = nodemailer.createTransport({ host, port, secure: port === 465, auth: { user, pass } });
  await transport.sendMail({
    from: Deno.env.get("SMTP_FROM") ?? user,
    to,
    subject: "Confirm your new ResidentHub email",
    text: `Your ResidentHub code to confirm this email address is ${code}.\n\nIt expires in ${CODE_MINUTES} minutes. Do not share it with anyone. ` +
      `If you did not ask for this, ignore this email.`,
    html: `<div style="font-family:Arial,sans-serif;max-width:420px"><h2 style="color:#11263E">ResidentHub</h2>` +
      `<p>Your code to confirm this email address is</p><p style="font-size:30px;letter-spacing:6px;font-weight:bold;color:#11263E">${code}</p>` +
      `<p style="color:#555">It expires in ${CODE_MINUTES} minutes. Do not share it with anyone. If you did not ask for this, ignore this email.</p></div>`,
  });
}

async function sendSms(to: string, code: string) {
  const text = `ResidentHub: your code to confirm this number is ${code}. It expires in ${CODE_MINUTES} minutes. Do not share it.`;
  const provider = smsProvider();
  const notSet = "Text messages are not set up yet.";
  const failed = "The text message could not be sent. Check the number and try again.";
  if (provider === "twilio") {
    const sid = Deno.env.get("TWILIO_ACCOUNT_SID"), token = Deno.env.get("TWILIO_AUTH_TOKEN");
    const from = Deno.env.get("TWILIO_FROM"), svc = Deno.env.get("TWILIO_MESSAGING_SERVICE_SID");
    if (!sid || !token || (!from && !svc)) throw new Error(notSet);
    const form = new URLSearchParams({ To: to, Body: text });
    if (svc) form.set("MessagingServiceSid", svc);
    else form.set("From", from!);
    const r = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
      method: "POST",
      headers: { Authorization: "Basic " + btoa(`${sid}:${token}`), "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    });
    if (!r.ok) throw new Error(failed);
    return;
  }
  if (provider === "httpsms") {
    const key = Deno.env.get("HTTPSMS_API_KEY"), from = Deno.env.get("HTTPSMS_FROM");
    if (!key || !from) throw new Error(notSet);
    const r = await fetch("https://api.httpsms.com/v1/messages/send", {
      method: "POST",
      headers: { "x-api-key": key, "Content-Type": "application/json" },
      body: JSON.stringify({ from, to, content: text }),
    });
    if (!r.ok) throw new Error(failed);
    return;
  }
  if (provider === "semaphore") {
    const key = Deno.env.get("SEMAPHORE_API_KEY");
    if (!key) throw new Error(notSet);
    const form = new URLSearchParams({ apikey: key, number: to.replace("+", ""), message: text });
    const sender = Deno.env.get("SEMAPHORE_SENDER");
    if (sender) form.set("sendername", sender);
    const r = await fetch("https://api.semaphore.co/api/v4/messages", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    });
    if (!r.ok) throw new Error(failed);
    return;
  }
  throw new Error(notSet);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Use POST." }, 405);

  try {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
      auth: { persistSession: false },
    });
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const { data: caller, error: callerErr } = await admin.auth.getUser(token);
    if (callerErr || !caller?.user) return reply({ error: "Please sign in again." }, 401);
    const uid = caller.user.id;

    const { data: me } = await admin.from("profiles").select("id,email,phone,role,suspended").eq("id", uid).maybeSingle();
    if (!me || me.suspended || me.role !== "admin") return reply({ error: "Only the administrator can change these details." }, 403);

    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? "");
    const channel = String(body.channel ?? "");
    if (channel !== "sms" && channel !== "email") return reply({ error: "Choose email or mobile number." }, 400);

    // The cleaned-up new value, and a check that nobody else already uses it.
    let value = "";
    if (channel === "sms") {
      const p = normalizePhone(body.value);
      if (!p) return reply({ error: PHONE_MSG }, 400);
      value = p;
      const { data: others } = await admin.from("profiles").select("id,phone").neq("id", uid).neq("phone", "").limit(5000);
      if ((others ?? []).some((o) => normalizePhone(o.phone) === value)) {
        return reply({ error: "That mobile number is already used by another account." }, 400);
      }
    } else {
      value = String(body.value ?? "").trim().toLowerCase();
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value)) return reply({ error: "Enter a valid email address." }, 400);
      if (value === String(me.email ?? "").toLowerCase()) return reply({ error: "That is already your email address." }, 400);
      const { data: used } = await admin.from("profiles").select("id").eq("email", value).neq("id", uid).maybeSingle();
      if (used) return reply({ error: "That email address is already used by another account." }, 400);
    }

    if (action === "send") {
      const now = Date.now();
      const { data: rows } = await admin.from("verification_codes").select("*").eq("user_id", uid);
      const prev = (rows ?? []).find((r) => r.channel === channel);
      if (prev) {
        const since = (now - new Date(prev.sent_at).getTime()) / 1000;
        if (since < COOLDOWN_SECONDS) {
          return reply({ error: `Please wait ${Math.ceil(COOLDOWN_SECONDS - since)} seconds before asking for a new code.` }, 429);
        }
      }
      const inWindow = prev && now - new Date(prev.window_start).getTime() < 3600_000;
      const windowStart = inWindow ? new Date(prev!.window_start) : new Date(now);
      const sends = inWindow ? prev!.sends : 0;
      if (sends >= MAX_SENDS_PER_HOUR) return reply({ error: "Too many codes were requested. Try again in an hour." }, 429);

      const code = newCode();
      try {
        if (channel === "sms") await sendSms(intl(value), code);
        else await sendEmail(value, code);
      } catch (e) {
        return reply({ error: (e as Error).message }, 502);
      }
      const { error } = await admin.from("verification_codes").upsert({
        user_id: uid,
        channel,
        code_hash: await hash(uid, channel, value, code),
        expires_at: new Date(now + CODE_MINUTES * 60_000).toISOString(),
        attempts: 0,
        sent_at: new Date(now).toISOString(),
        window_start: windowStart.toISOString(),
        sends: sends + 1,
      });
      if (error) return reply({ error: "Could not save the code. Try again." }, 500);
      return reply({ ok: true, cooldown: COOLDOWN_SECONDS, sentTo: channel === "sms" ? maskPhone(value) : maskEmail(value) });
    }

    if (action === "check") {
      const code = String(body.code ?? "").trim();
      if (!/^\d{6}$/.test(code)) return reply({ error: "Enter the 6-digit code." }, 400);
      const { data: rows } = await admin.from("verification_codes").select("*").eq("user_id", uid);
      const row = (rows ?? []).find((r) => r.channel === channel);
      if (!row) return reply({ error: "Ask for a new code first." }, 400);
      if (new Date(row.expires_at).getTime() < Date.now()) return reply({ error: "The code expired. Ask for a new code." }, 400);
      if (row.attempts >= MAX_ATTEMPTS) return reply({ error: "Too many wrong tries. Ask for a new code." }, 429);
      if ((await hash(uid, channel, value, code)) !== row.code_hash) {
        await admin.from("verification_codes").update({ attempts: row.attempts + 1 }).eq("user_id", uid).eq("channel", channel);
        return reply({ error: "That code is not correct." }, 400);
      }

      if (channel === "sms") {
        const { error } = await admin.from("profiles").update({ phone: value, contact_verified_at: new Date().toISOString() }).eq("id", uid);
        if (error) return reply({ error: "Could not save the number. Try again." }, 500);
      } else {
        const { error: aErr } = await admin.auth.admin.updateUserById(uid, { email: value, email_confirm: true });
        if (aErr) {
          const m = aErr.message ?? "";
          return reply({ error: /already|registered|exists/i.test(m) ? "That email address is already used by another account." : "Could not change the email. Try again." }, 400);
        }
        const { error } = await admin.from("profiles").update({ email: value }).eq("id", uid);
        if (error) return reply({ error: "Could not save the email. Try again." }, 500);
      }
      await admin.from("verification_codes").delete().eq("user_id", uid).eq("channel", channel);
      return reply({ ok: true, ...(channel === "sms" ? { phone: value } : { email: value }) });
    }

    return reply({ error: "Unknown action." }, 400);
  } catch (e) {
    return reply({ error: String((e as Error)?.message ?? e) }, 500);
  }
});
