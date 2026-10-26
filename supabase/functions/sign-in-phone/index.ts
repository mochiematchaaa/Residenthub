// Sign-in by mobile number was removed from ResidentHub: people sign in with their email address.
// This function is kept only so old copies of the app get a clear message instead of an error.
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve((req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  return new Response(JSON.stringify({ error: "Sign in with your email address." }), {
    status: 410,
    headers: { ...cors, "Content-Type": "application/json" },
  });
});
