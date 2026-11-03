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

/** A Philippine mobile number: 0917 123 4567, +63 917 123 4567 or 9171234567. */
function validPhone(raw: string): boolean {
  let d = String(raw ?? "").replace(/[^\d+]/g, "");
  if (d.startsWith("+")) d = d.slice(1);
  if (d.startsWith("63")) d = d.slice(2);
  else if (d.startsWith("0")) d = d.slice(1);
  return /^9\d{9}$/.test(d);
}
const PHONE_MSG = "Enter a valid Philippine mobile number, e.g. 0917 123 4567.";

// Easy to read out loud (no 0/O or 1/l/I) and always follows the password rules:
// 12 characters with an uppercase letter, a lowercase letter, a number and a symbol.
function tempPassword(): string {
  const pick = (chars: string) => chars[crypto.getRandomValues(new Uint32Array(1))[0] % chars.length];
  const lower = "abcdefghjkmnpqrstuvwxyz", upper = "ABCDEFGHJKMNPQRSTUVWXYZ", digits = "23456789", symbols = "#@!?%$";
  const all = lower + upper + digits;
  const out = [pick(lower), pick(upper), pick(digits), pick(symbols)];
  while (out.length < 12) out.push(pick(all));
  // shuffle (Fisher-Yates)
  for (let i = out.length - 1; i > 0; i--) {
    const j = crypto.getRandomValues(new Uint32Array(1))[0] % (i + 1);
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out.join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Use POST." }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(url, serviceKey, { auth: { persistSession: false } });

    // Who is calling? Must be a signed-in, active administrator.
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const { data: caller, error: callerErr } = await admin.auth.getUser(token);
    if (callerErr || !caller?.user) return reply({ error: "Please sign in again." }, 401);
    const { data: me } = await admin
      .from("profiles")
      .select("role,suspended,name,email")
      .eq("id", caller.user.id)
      .maybeSingle();
    if (!me || me.role !== "admin" || me.suspended) {
      return reply({ error: "Only the administrator can do that." }, 403);
    }

    // Account changes made here run with the server key, so the database cannot see who is
    // signed in. We write the audit trail entry ourselves, with the administrator as the actor.
    async function audit(
      action: "INSERT" | "UPDATE" | "DELETE",
      recordId: string,
      unit: string,
      oldValue: unknown,
      newValue: unknown,
    ) {
      try {
        const { error } = await admin.from("audit_log").insert({
          actor_id: caller.user.id,
          actor_name: (me!.name || me!.email || "Administrator") as string,
          actor_role: "admin",
          action,
          source_table: "profiles",
          kind: "account",
          record_id: recordId,
          unit,
          old_value: oldValue ?? null,
          new_value: newValue ?? null,
        });
        if (error) console.error("audit insert failed", error.message);
      } catch (e) {
        console.error("audit insert failed", String((e as Error)?.message ?? e));
      }
    }

    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? "");
    const userId = String(body.userId ?? "");

    // Never let this function touch an administrator account (including your own).
    async function targetResident(): Promise<{ error?: string; row?: any }> {
      if (!userId) return { error: "Missing account." };
      const { data: t } = await admin
        .from("profiles")
        .select("id,role,name,email,phone,unit,suspended")
        .eq("id", userId)
        .maybeSingle();
      if (!t) return { error: "Account not found." };
      if (t.role !== "resident") return { error: "That is not a resident account." };
      return { row: t };
    }

    if (action === "create") {
      const email = String(body.email ?? "").trim().toLowerCase();
      const name = String(body.name ?? "").trim();
      const phone = String(body.phone ?? "").trim();
      const unit = String(body.unit ?? "").trim();
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return reply({ error: "Enter a valid email address." }, 400);
      if (!name) return reply({ error: "Enter the resident's name." }, 400);
      if (!unit) return reply({ error: "Choose the resident's unit." }, 400);
      if (phone && !validPhone(phone)) return reply({ error: PHONE_MSG }, 400); // the mobile number is optional contact information
      const { data: unitRow } = await admin
        .from("records")
        .select("id")
        .eq("kind", "unit")
        .eq("id", unit)
        .maybeSingle();
      if (!unitRow) return reply({ error: "That unit does not exist yet. Add the unit first." }, 400);

      const password = tempPassword();
      const { data: created, error: cErr } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
      });
      if (cErr || !created?.user) {
        const m = cErr?.message ?? "Could not create the account.";
        return reply({ error: /already|registered|exists/i.test(m) ? "That email already has an account." : m }, 400);
      }
      const { error: pErr } = await admin.from("profiles").upsert({
        id: created.user.id,
        email,
        name,
        phone,
        unit,
        role: "resident",
        suspended: false,
        must_change_password: true,
        contact_verified_at: null,
      });
      if (pErr) {
        await admin.auth.admin.deleteUser(created.user.id);
        return reply({ error: pErr.message }, 500);
      }
      await audit("INSERT", created.user.id, unit, null, { email, name, phone, unit, role: "resident" });
      return reply({ ok: true, userId: created.user.id, email, password });
    }

    if (action === "reset-password") {
      const t = await targetResident();
      if (t.error) return reply({ error: t.error }, 400);
      const password = tempPassword();
      const { error } = await admin.auth.admin.updateUserById(userId, { password });
      if (error) return reply({ error: error.message }, 500);
      await admin.from("profiles").update({ must_change_password: true }).eq("id", userId);
      await audit("UPDATE", userId, t.row.unit ?? "", { email: t.row.email, name: t.row.name }, {
        email: t.row.email,
        name: t.row.name,
        event: "Temporary password issued",
        must_change_password: true,
      });
      return reply({ ok: true, password });
    }

    if (action === "set-suspended") {
      const t = await targetResident();
      if (t.error) return reply({ error: t.error }, 400);
      const suspended = body.suspended === true;
      const { error } = await admin.auth.admin.updateUserById(userId, {
        ban_duration: suspended ? "876000h" : "none",
      });
      if (error) return reply({ error: error.message }, 500);
      await admin.from("profiles").update({ suspended }).eq("id", userId);
      await audit("UPDATE", userId, t.row.unit ?? "", { name: t.row.name, suspended: !!t.row.suspended }, { name: t.row.name, suspended });
      return reply({ ok: true });
    }

    if (action === "update-profile") {
      const t = await targetResident();
      if (t.error) return reply({ error: t.error }, 400);
      const patch: Record<string, string | null> = {};
      if (body.name !== undefined) patch.name = String(body.name).trim();
      if (body.phone !== undefined) {
        const phone = String(body.phone).trim();
        if (phone && !validPhone(phone)) return reply({ error: PHONE_MSG }, 400);
        patch.phone = phone;
      }
      if (body.unit !== undefined) {
        const unit = String(body.unit).trim();
        const { data: unitRow } = await admin.from("records").select("id").eq("kind", "unit").eq("id", unit).maybeSingle();
        if (!unitRow) return reply({ error: "That unit does not exist." }, 400);
        patch.unit = unit;
      }
      const { error } = await admin.from("profiles").update(patch).eq("id", userId);
      if (error) return reply({ error: error.message }, 500);
      const before: Record<string, unknown> = {};
      const after: Record<string, unknown> = {};
      for (const k of Object.keys(patch)) {
        if ((t.row[k] ?? "") !== (patch[k] ?? "")) {
          before[k] = t.row[k] ?? "";
          after[k] = patch[k];
        }
      }
      if (Object.keys(after).length) {
        await audit("UPDATE", userId, (patch.unit ?? t.row.unit ?? "") as string, { email: t.row.email, ...before }, { email: t.row.email, ...after });
      }
      return reply({ ok: true });
    }

    if (action === "delete") {
      const t = await targetResident();
      if (t.error) return reply({ error: t.error }, 400);
      const { error } = await admin.auth.admin.deleteUser(userId);
      if (error) return reply({ error: error.message }, 500);
      await admin.from("profiles").delete().eq("id", userId);
      await audit("DELETE", userId, t.row.unit ?? "", { email: t.row.email, name: t.row.name, phone: t.row.phone, unit: t.row.unit, role: "resident" }, null);
      return reply({ ok: true });
    }

    return reply({ error: "Unknown action." }, 400);
  } catch (e) {
    return reply({ error: String((e as Error)?.message ?? e) }, 500);
  }
});
