// "Forgot password" for people who are not signed in.
//
// action "request": { email }  - emails one 6-digit code and texts another to the numbers on the account.
//                                The answer is always the same, so nobody can find out which emails have accounts.
// action "confirm": { email, emailCode, smsCode, newPassword } - when both codes are right the password is replaced.
//
// Uses the same secrets as verify-contact (SMTP_* and SMS_PROVIDER + provider keys).
// This function is called without a sign-in, so "Verify JWT" is off for it; it checks everything itself.
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
const SAME_ANSWER =
  "If that email belongs to an account, we sent a code to it and a text message to the mobile number on file.";
const BAD_CODES = "The codes are not correct or have expired. Ask for new codes.";

function newCode(): string {
  const n = crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
  return n.toString().padStart(6, "0");
}

async function hash(userId: string, channel: string, code: string): Promise<string> {
  const data = new TextEncoder().encode(`reset|${userId}|${channel}|${code}`);
  const buf = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(buf), (b) => b.toString(16).padStart(2, "0")).join("");
}

function normalizePhone(raw: string): string | null {
  let d = String(raw ?? "").replace(/[^\d+]/g, "");
  if (d.startsWith("+")) d = d.slice(1);
  if (d.startsWith("63")) d = d.slice(2);
  else if (d.startsWith("0")) d = d.slice(1);
  return /^9\d{9}$/.test(d) ? `+63${d}` : null;
}

async function sendEmail(to: string, code: string) {
  const host = Deno.env.get("SMTP_HOST"), user = Deno.env.get("SMTP_USER"), pass = Deno.env.get("SMTP_PASS");
  if (!host || !user || !pass) throw new Error("not set up");
  const port = Number(Deno.env.get("SMTP_PORT") ?? "465");
  const transport = nodemailer.createTransport({ host, port, secure: port === 465, auth: { user, pass } });
  await transport.sendMail({
    from: Deno.env.get("SMTP_FROM") ?? user,
    to,
    subject: "Reset your ResidentHub password",
    text: `Your ResidentHub password reset code is ${code}.\n\nIt expires in ${CODE_MINUTES} minutes. Do not share it with anyone. ` +
      `If you did not ask to reset your password, ignore this email.`,
    html: `<div style="font-family:Arial,sans-serif;max-width:420px"><h2 style="color:#11263E">ResidentHub</h2>` +
      `<p>Your password reset code is</p><p style="font-size:30px;letter-spacing:6px;font-weight:bold;color:#11263E">${code}</p>` +
      `<p style="color:#555">It expires in ${CODE_MINUTES} minutes. Do not share it with anyone. If you did not ask to reset your password, ignore this email.</p></div>`,
  });
}

async function sendSms(to: string, code: string) {
  const text = `ResidentHub: your password reset code is ${code}. It expires in ${CODE_MINUTES} minutes. Do not share it.`;
  const provider = (Deno.env.get("SMS_PROVIDER") ?? "").toLowerCase();
  if (provider === "twilio") {
    const sid = Deno.env.get("TWILIO_ACCOUNT_SID"), token = Deno.env.get("TWILIO_AUTH_TOKEN");
    const from = Deno.env.get("TWILIO_FROM"), svc = Deno.env.get("TWILIO_MESSAGING_SERVICE_SID");
    if (!sid || !token || (!from && !svc)) throw new Error("not set up");
    const form = new URLSearchParams({ To: to, Body: text });
    if (svc) form.set("MessagingServiceSid", svc);
    else form.set("From", from!);
    const r = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
      method: "POST",
      headers: { Authorization: "Basic " + btoa(`${sid}:${token}`), "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    });
    if (!r.ok) throw new Error("sms failed");
    return;
  }
  if (provider === "semaphore") {
    const key = Deno.env.get("SEMAPHORE_API_KEY");
    if (!key) throw new Error("not set up");
    const form = new URLSearchParams({ apikey: key, number: to.replace("+", ""), message: text });
    const sender = Deno.env.get("SEMAPHORE_SENDER");
    if (sender) form.set("sendername", sender);
    const r = await fetch("https://api.semaphore.co/api/v4/messages", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    });
    if (!r.ok) throw new Error("sms failed");
    return;
  }
  throw new Error("not set up");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Use POST." }, 405);

  try {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
      auth: { persistSession: false },
    });
    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? "");
    const email = String(body.email ?? "").trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return reply({ error: "Enter a valid email address." }, 400);

    // Only an active account whose email and mobile number are confirmed can reset by itself.
    const { data: p } = await admin
      .from("profiles")
      .select("id,email,phone,role,suspended,contact_verified_at")
      .eq("email", email)
      .maybeSingle();
    const phone = p ? normalizePhone(p.phone ?? "") : null;
    const eligible = !!p && !p.suspended && !!phone && (p.role === "admin" || !!p.contact_verified_at);

    if (action === "request") {
      if (!eligible || !p) return reply({ ok: true, message: SAME_ANSWER, cooldown: COOLDOWN_SECONDS });
      const uid = p.id as string;
      const now = Date.now();
      const { data: rows } = await admin.from("reset_codes").select("*").eq("user_id", uid);
      const prev = (rows ?? []).find((r) => r.channel === "email");
      if (prev && (now - new Date(prev.sent_at).getTime()) / 1000 < COOLDOWN_SECONDS) {
        return reply({ ok: true, message: SAME_ANSWER, cooldown: COOLDOWN_SECONDS });
      }
      const inWindow = prev && now - new Date(prev.window_start).getTime() < 3600_000;
      const windowStart = inWindow ? new Date(prev!.window_start) : new Date(now);
      const sends = inWindow ? prev!.sends : 0;
      if (sends >= MAX_SENDS_PER_HOUR) return reply({ ok: true, message: SAME_ANSWER, cooldown: COOLDOWN_SECONDS });

      const emailCode = newCode(), smsCode = newCode();
      let failed = false;
      try { await sendEmail(email, emailCode); } catch (_) { failed = true; }
      try { await sendSms(phone!, smsCode); } catch (_) { failed = true; }
      if (failed) {
        // Same answer on the outside; the administrator can see the problem in the function logs.
        console.error("reset-password: a code could not be sent (check the SMTP and SMS secrets)");
        return reply({ ok: true, message: SAME_ANSWER, cooldown: COOLDOWN_SECONDS });
      }
      const common = {
        user_id: uid,
        expires_at: new Date(now + CODE_MINUTES * 60_000).toISOString(),
        attempts: 0,
        sent_at: new Date(now).toISOString(),
        window_start: windowStart.toISOString(),
        sends: sends + 1,
      };
      await admin.from("reset_codes").upsert([
        { ...common, channel: "email", code_hash: await hash(uid, "email", emailCode) },
        { ...common, channel: "sms", code_hash: await hash(uid, "sms", smsCode) },
      ]);
      return reply({ ok: true, message: SAME_ANSWER, cooldown: COOLDOWN_SECONDS });
    }

    if (action === "confirm") {
      const emailCode = String(body.emailCode ?? "").trim();
      const smsCode = String(body.smsCode ?? "").trim();
      const pw = String(body.newPassword ?? "");
      if (!/^\d{6}$/.test(emailCode) || !/^\d{6}$/.test(smsCode)) return reply({ error: "Enter both 6-digit codes." }, 400);
      if (pw.length < 8) return reply({ error: "New password must be at least 8 characters." }, 400);
      if (!eligible || !p) return reply({ error: BAD_CODES }, 400);
      const uid = p.id as string;

      const { data: rows } = await admin.from("reset_codes").select("*").eq("user_id", uid);
      const e = (rows ?? []).find((r) => r.channel === "email");
      const s = (rows ?? []).find((r) => r.channel === "sms");
      if (!e || !s) return reply({ error: BAD_CODES }, 400);
      if (new Date(e.expires_at).getTime() < Date.now() || e.attempts >= MAX_ATTEMPTS || s.attempts >= MAX_ATTEMPTS) {
        return reply({ error: BAD_CODES }, 400);
      }
      const okEmail = (await hash(uid, "email", emailCode)) === e.code_hash;
      const okSms = (await hash(uid, "sms", smsCode)) === s.code_hash;
      if (!okEmail || !okSms) {
        await admin.from("reset_codes").update({ attempts: e.attempts + 1 }).eq("user_id", uid).eq("channel", "email");
        await admin.from("reset_codes").update({ attempts: s.attempts + 1 }).eq("user_id", uid).eq("channel", "sms");
        return reply({ error: BAD_CODES }, 400);
      }
      const { error } = await admin.auth.admin.updateUserById(uid, { password: pw });
      if (error) return reply({ error: /password/i.test(error.message) ? error.message : "Could not change the password. Try again." }, 400);
      await admin.from("profiles").update({ must_change_password: false }).eq("id", uid);
      await admin.from("reset_codes").delete().eq("user_id", uid);
      return reply({ ok: true });
    }

    return reply({ error: "Unknown action." }, 400);
  } catch (e) {
    return reply({ error: String((e as Error)?.message ?? e) }, 500);
  }
});
