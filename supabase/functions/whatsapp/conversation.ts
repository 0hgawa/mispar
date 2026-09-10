// A conversa.
//
// Meta: horario marcado em quatro mensagens, sem sair do WhatsApp e sem link.
// O robo nao decide nada sozinho — quem sabe o que esta livre e o Postgres.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import {
  addDays,
  hourOf,
  longDay,
  normalize,
  parseDay,
  shortDay,
  today,
} from "./dates.ts";
import { type Choice, type Incoming, sendChoices, sendText } from "./whatsapp.ts";

/** Quantos horarios oferecer por vez. Lista longa trava a decisao. */
const TIMES_PER_PAGE = 4;

/** Quantos dias a frente o cliente pode marcar. */
const BOOKING_HORIZON_DAYS = 21;

type State =
  | { step: "start" }
  | { step: "service" }
  | { step: "day"; serviceId: string }
  | { step: "time"; serviceId: string; day: string; page: number }
  | { step: "cancel" };

interface Service {
  id: string;
  name: string;
  duration_minutes: number;
  price_cents: number;
}

export async function handle(
  db: SupabaseClient,
  message: Incoming,
): Promise<void> {
  const state = await loadState(db, message.phone);
  const next = await step(db, message, state);
  await saveState(db, message.phone, next);
}

async function step(
  db: SupabaseClient,
  message: Incoming,
  state: State,
): Promise<State> {
  const said = normalize(message.text);
  const choice = message.choice;

  // Escape hatch em qualquer ponto: o cliente sempre alcanca uma pessoa.
  if (choice === "humano" || /\b(atendente|falar com|humano)\b/.test(said)) {
    await sendText(
      message.phone,
      "Beleza — o Marcos ve esta conversa e responde assim que sair da cadeira.",
    );
    return { step: "start" };
  }

  if (choice === "cancelar" || /\b(cancelar|desmarcar)\b/.test(said)) {
    return await offerCancellations(db, message);
  }

  if (choice.startsWith("cancel:")) {
    return await doCancel(db, message, choice.slice("cancel:".length));
  }

  if (choice.startsWith("svc:")) {
    return await offerDays(db, message, choice.slice("svc:".length));
  }

  if (choice.startsWith("day:") && state.step === "day") {
    return await offerTimes(db, message, state.serviceId, choice.slice(4), 0);
  }

  if (choice === "mais" && state.step === "time") {
    return await offerTimes(
      db,
      message,
      state.serviceId,
      state.day,
      state.page + 1,
    );
  }

  if (choice.startsWith("at:") && state.step === "time") {
    return await book(db, message, state.serviceId, choice.slice(3));
  }

  // Texto livre: se ele ja escolheu servico e escreveu um dia, pula a etapa.
  if (state.step === "day") {
    const day = parseDay(message.text);
    if (day) return await offerTimes(db, message, state.serviceId, day, 0);
  }

  return await greet(db, message);
}

// --------------------------------------------------------------- etapas --

async function greet(db: SupabaseClient, message: Incoming): Promise<State> {
  const { data: services } = await db
    .from("services")
    .select("id, name, duration_minutes, price_cents")
    .eq("active", true)
    .order("price_cents");

  if (!services?.length) {
    await sendText(message.phone, "A agenda esta fechada agora. Volte mais tarde.");
    return { step: "start" };
  }

  const usual = await lastService(db, message.phone);
  const firstName = message.profileName.split(" ")[0];

  // Cliente conhecido nao repete o que sempre pede: o de sempre vem primeiro.
  const choices: Choice[] = usual
    ? [
      { id: `svc:${usual.id}`, label: usual.name, detail: priceLine(usual) },
      ...services
        .filter((s: Service) => s.id !== usual.id)
        .map(toChoice),
    ]
    : services.map(toChoice);

  await sendChoices(
    message.phone,
    usual
      ? `Oi, ${firstName}! ${usual.name}, como da ultima vez?`
      : `Oi, ${firstName}! O que voce quer fazer?`,
    choices,
    "Ver servicos",
  );

  return { step: "service" };
}

async function offerDays(
  db: SupabaseClient,
  message: Incoming,
  serviceId: string,
): Promise<State> {
  const days: Choice[] = [];

  for (let ahead = 0; ahead < BOOKING_HORIZON_DAYS && days.length < 8; ahead++) {
    const day = addDays(today(), ahead);
    const { data } = await db.rpc("available_slots", {
      p_day: day,
      p_service_id: serviceId,
    });
    if (data?.length) {
      days.push({
        id: `day:${day}`,
        label: shortDay(day),
        detail: `${data.length} ${data.length === 1 ? "horario" : "horarios"} livres`,
      });
    }
  }

  if (days.length === 0) {
    await sendText(
      message.phone,
      "A agenda esta cheia nas proximas semanas. Escreva *atendente* que o Marcos te encaixa.",
    );
    return { step: "start" };
  }

  await sendChoices(message.phone, "Que dia fica bom?", days, "Ver dias");
  return { step: "day", serviceId };
}

async function offerTimes(
  db: SupabaseClient,
  message: Incoming,
  serviceId: string,
  day: string,
  page: number,
): Promise<State> {
  const { data: slots } = await db.rpc("available_slots", {
    p_day: day,
    p_service_id: serviceId,
  });

  if (!slots?.length) {
    await sendText(
      message.phone,
      `${longDay(day)} lotou. Me diz outro dia que eu vejo.`,
    );
    return { step: "day", serviceId };
  }

  const from = page * TIMES_PER_PAGE;
  const window = slots.slice(from, from + TIMES_PER_PAGE);

  if (window.length === 0) {
    return await offerTimes(db, message, serviceId, day, 0);
  }

  const choices: Choice[] = window.map((slot: { starts_at: string }) => ({
    id: `at:${slot.starts_at}`,
    label: hourOf(slot.starts_at),
  }));

  if (from + TIMES_PER_PAGE < slots.length) {
    choices.push({ id: "mais", label: "Outro horario" });
  }

  await sendChoices(
    message.phone,
    `${longDay(day)}. Tenho estes horarios:`,
    choices,
    "Ver horarios",
  );

  return { step: "time", serviceId, day, page };
}

async function book(
  db: SupabaseClient,
  message: Incoming,
  serviceId: string,
  startsAt: string,
): Promise<State> {
  const { error } = await db.rpc("book_appointment", {
    p_phone: message.phone,
    p_name: message.profileName,
    p_service_id: serviceId,
    p_starts_at: startsAt,
  });

  if (error) {
    // Alguem pegou o horario no meio da conversa. Acontece e tem que ser suave.
    if (error.message.includes("HORARIO_OCUPADO")) {
      await sendText(
        message.phone,
        "Esse horario acabou de ser preenchido. Olha os que sobraram:",
      );
      const day = startsAt.slice(0, 10);
      return await offerTimes(db, message, serviceId, day, 0);
    }
    console.error("book_appointment falhou", error);
    await sendText(
      message.phone,
      "Deu problema aqui do meu lado. Escreva *atendente* que o Marcos resolve.",
    );
    return { step: "start" };
  }

  const { data: service } = await db
    .from("services")
    .select("name, price_cents")
    .eq("id", serviceId)
    .single();

  await sendText(
    message.phone,
    [
      `Fechado — ${longDay(startsAt.slice(0, 10))}, as ${hourOf(startsAt)}.`,
      `${service?.name} · ${money(service?.price_cents ?? 0)}`,
      "",
      "Te mando um lembrete um dia antes. Se precisar mudar, e so escrever *cancelar*.",
    ].join("\n"),
  );

  return { step: "start" };
}

async function offerCancellations(
  db: SupabaseClient,
  message: Incoming,
): Promise<State> {
  const { data: appointments } = await db
    .from("appointments")
    .select("id, starts_at, services(name), clients!inner(phone)")
    .eq("clients.phone", message.phone)
    .in("status", ["awaiting", "confirmed", "deposit_paid"])
    .gte("starts_at", new Date().toISOString())
    .order("starts_at")
    .limit(5);

  if (!appointments?.length) {
    await sendText(message.phone, "Voce nao tem horario marcado.");
    return { step: "start" };
  }

  await sendChoices(
    message.phone,
    "Qual voce quer desmarcar?",
    appointments.map((row) => ({
      id: `cancel:${row.id}`,
      label: `${shortDay(row.starts_at.slice(0, 10))} ${hourOf(row.starts_at)}`,
      detail: embedded<{ name: string }>(row.services)?.name,
    })),
    "Ver horarios",
  );

  return { step: "cancel" };
}

async function doCancel(
  db: SupabaseClient,
  message: Incoming,
  appointmentId: string,
): Promise<State> {
  const { data } = await db.rpc("cancel_appointment", {
    p_phone: message.phone,
    p_appointment_id: appointmentId,
  });

  await sendText(
    message.phone,
    data
      ? "Desmarcado. Quando quiser voltar, e so chamar."
      : "Nao achei esse horario. Escreva *atendente* que o Marcos confere.",
  );

  return { step: "start" };
}

// --------------------------------------------------------------- estado --

async function loadState(db: SupabaseClient, phone: string): Promise<State> {
  const { data } = await db
    .from("conversations")
    .select("state")
    .eq("phone", phone)
    .maybeSingle();

  return (data?.state as State | undefined) ?? { step: "start" };
}

async function saveState(
  db: SupabaseClient,
  phone: string,
  state: State,
): Promise<void> {
  await db
    .from("conversations")
    .upsert({ phone, state, updated_at: new Date().toISOString() });
}

// ---------------------------------------------------------------- ajuda --

async function lastService(
  db: SupabaseClient,
  phone: string,
): Promise<Service | null> {
  const { data } = await db
    .from("appointments")
    .select("services(id, name, duration_minutes, price_cents), clients!inner(phone)")
    .eq("clients.phone", phone)
    .eq("status", "done")
    .order("starts_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  return embedded<Service>(data?.services) ?? null;
}

/**
 * Achata um relacionamento embutido do PostgREST.
 *
 * Sem tipos gerados, o cliente assume lista mesmo quando a relacao e
 * muitos-para-um e o servidor devolve um objeto so.
 */
function embedded<T>(value: unknown): T | undefined {
  if (Array.isArray(value)) return value[0] as T | undefined;
  return (value ?? undefined) as T | undefined;
}

function toChoice(service: Service): Choice {
  return {
    id: `svc:${service.id}`,
    label: service.name,
    detail: priceLine(service),
  };
}

function priceLine(service: Service): string {
  return `${money(service.price_cents)} · ${service.duration_minutes} min`;
}

function money(cents: number): string {
  return cents % 100 === 0
    ? `R$ ${cents / 100}`
    : `R$ ${(cents / 100).toFixed(2).replace(".", ",")}`;
}
