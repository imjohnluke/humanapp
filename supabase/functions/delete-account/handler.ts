export type Config = { supabaseURL: string; serviceKey: string };

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } });
}
function fail(code: string, status: number): Response { return json({ error: code }, status); }

export function createHandler(config: Config, fetcher: typeof fetch = fetch) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") return fail("method_not_allowed", 405);
    const authorization = request.headers.get("Authorization") ?? "";
    if (!/^Bearer \S+$/.test(authorization)) return fail("sign_in_required", 401);
    if (!config.supabaseURL || !config.serviceKey) return fail("unavailable", 503);
    try {
      const auth = await fetcher(`${config.supabaseURL}/auth/v1/user`, {
        headers: { apikey: config.serviceKey, Authorization: authorization },
        signal: AbortSignal.timeout(10000),
      });
      if (!auth.ok) return fail(auth.status >= 500 ? "unavailable" : "sign_in_required", auth.status >= 500 ? 503 : 401);
      const user = await auth.json();
      if (typeof user.id !== "string" || !/^[0-9a-f-]{36}$/i.test(user.id)) return fail("sign_in_required", 401);
      const deleted = await fetcher(`${config.supabaseURL}/auth/v1/admin/users/${encodeURIComponent(user.id)}`, {
        method: "DELETE",
        headers: { apikey: config.serviceKey, Authorization: `Bearer ${config.serviceKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({ should_soft_delete: false }),
        signal: AbortSignal.timeout(15000),
      });
      if (!deleted.ok) return fail("unavailable", 503);
      return json({ deleted: true });
    } catch {
      return fail("unavailable", 503);
    }
  };
}
