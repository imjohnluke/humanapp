import { createHandler } from "./handler.ts";
Deno.serve(createHandler({
  supabaseURL: Deno.env.get("SUPABASE_URL") ?? "",
  serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
}));
