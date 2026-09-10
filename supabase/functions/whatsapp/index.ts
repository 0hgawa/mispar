// Webhook do WhatsApp.
//
// GET  — a Meta verifica o endereco uma vez, no cadastro.
// POST — chega mensagem de cliente.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { handle } from "./conversation.ts";
import { readIncoming } from "./whatsapp.ts";

const VERIFY_TOKEN = Deno.env.get("WHATSAPP_VERIFY_TOKEN")!;

// serviceRole passa por cima da RLS. Nunca sai daqui.
const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

Deno.serve(async (request: Request) => {
  const url = new URL(request.url);

  if (request.method === "GET") {
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");

    if (mode === "subscribe" && token === VERIFY_TOKEN && challenge) {
      return new Response(challenge, { status: 200 });
    }
    return new Response("forbidden", { status: 403 });
  }

  if (request.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  // Responder 200 rapido e a regra da Meta: demorar faz ela reenviar tudo e a
  // conversa duplica. Se algo falhar depois, falha em silencio no log.
  try {
    const message = readIncoming(await request.json());
    if (message) await handle(db, message);
  } catch (error) {
    console.error("webhook falhou", error);
  }

  return new Response("ok", { status: 200 });
});
