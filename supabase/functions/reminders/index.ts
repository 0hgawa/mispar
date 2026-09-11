// A varredura do lembrete da vespera.
//
// Roda de hora em hora, agendada no pg_cron. O Postgres decide quem recebe
// (a funcao `due_reminders`); aqui so se manda e se anota que mandou.
//
// E a unica mensagem cobrada do robo — vai fora da janela de 24h, entao e
// template aprovado e tem preco por envio. Por isso nada sai antes de o dono
// ligar o interruptor, e nada sai duas vezes para o mesmo horario.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { dayOf, hourOf, shortDay } from "../_shared/dates.ts";
import { sendTemplate } from "../_shared/whatsapp.ts";

/**
 * O template aprovado na Meta.
 *
 * Corpo: "Oi, {{1}}! Seu {{2}} esta marcado para {{3}}. Confirma?"
 * Botoes de resposta rapida, nesta ordem: *Confirmar* e *Desmarcar*.
 */
const TEMPLATE = "lembrete_horario";

// serviceRole passa por cima da RLS. Nunca sai daqui.
const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

interface Due {
  id: string;
  phone: string;
  client_name: string;
  service_name: string;
  starts_at: string;
}

Deno.serve(async () => {
  const { data, error } = await db.rpc("due_reminders");
  if (error) {
    console.error("due_reminders falhou", error);
    return new Response("erro", { status: 500 });
  }

  const due = (data ?? []) as Due[];
  let sent = 0;

  for (const item of due) {
    const day = shortDay(dayOf(item.starts_at));
    const when = `${day} as ${hourOf(item.starts_at)}`;

    const ok = await sendTemplate(
      item.phone,
      TEMPLATE,
      [item.client_name.split(" ")[0], item.service_name, when],
      [`confirm:${item.id}`, `cancel:${item.id}`],
    );

    // Nao deu, nao anota: na varredura seguinte ele tenta de novo. Anotar
    // sem ter mandado custaria o cliente, nao o envio.
    if (!ok) continue;

    const stamped = await db
      .from("appointments")
      .update({ reminder_sent_at: new Date().toISOString() })
      .eq("id", item.id);

    if (stamped.error) {
      console.error("nao anotou o envio", item.id, stamped.error);
    }
    sent++;
  }

  return Response.json({ due: due.length, sent });
});
