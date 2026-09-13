import { createHandler } from "./handler.ts";
Deno.serve(createHandler({
  supabaseURL: Deno.env.get("SUPABASE_URL") ?? "",
  serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  openaiKey: Deno.env.get("OPENAI_API_KEY") ?? "",
  model: Deno.env.get("OPENAI_PHOTO_MODEL") ?? "gpt-4.1-mini-2025-04-14",
}));
