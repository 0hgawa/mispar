// Conversa com a Graph API da Meta.
//
// Este arquivo nao sabe nada de barbearia: so manda e recebe mensagem.

const GRAPH = "https://graph.facebook.com/v21.0";

const TOKEN = Deno.env.get("WHATSAPP_TOKEN")!;
const PHONE_ID = Deno.env.get("WHATSAPP_PHONE_ID")!;

/** O que chegou do cliente, ja limpo. */
export interface Incoming {
  /** E.164, com o `+` na frente. */
  phone: string;
  /** Nome do perfil do WhatsApp. Serve de palpite ate o Marcos corrigir. */
  profileName: string;
  /** Texto digitado, ou o rotulo do que ele tocou. */
  text: string;
  /** Id do item tocado numa lista ou botao. Vazio quando ele digitou. */
  choice: string;
}

export interface Choice {
  id: string;
  label: string;
  /** Linha menor embaixo do rotulo. So vale em lista. */
  detail?: string;
}

/**
 * Extrai a mensagem do webhook.
 *
 * A Meta manda status de entrega no mesmo endereco; devolve null para tudo
 * que nao for mensagem de gente.
 */
export function readIncoming(payload: unknown): Incoming | null {
  const value = (payload as WebhookPayload)?.entry?.[0]?.changes?.[0]?.value;
  const message = value?.messages?.[0];
  if (!message) return null;

  const contact = value?.contacts?.[0];
  const phone = `+${message.from}`;
  const profileName = contact?.profile?.name?.trim() || "Cliente";

  if (message.type === "text") {
    return { phone, profileName, text: message.text?.body ?? "", choice: "" };
  }

  // Botao de template chega por outro caminho: nao e `interactive`, e sim
  // `button`, com o texto do botao e o que ele carrega separados.
  if (message.type === "button") {
    return {
      phone,
      profileName,
      text: message.button?.text ?? "",
      choice: message.button?.payload ?? "",
    };
  }

  const reply = message.interactive?.list_reply ??
    message.interactive?.button_reply;
  if (reply) {
    return { phone, profileName, text: reply.title, choice: reply.id };
  }

  return { phone, profileName, text: "", choice: "" };
}

export async function sendText(to: string, body: string): Promise<void> {
  await send({ to, type: "text", text: { body, preview_url: false } });
}

/**
 * Manda uma pergunta com opcoes.
 *
 * Ate tres viram botoes, que aparecem direto na conversa; acima disso o
 * WhatsApp so aceita lista, que abre num menu.
 */
export async function sendChoices(
  to: string,
  body: string,
  choices: Choice[],
  listTitle = "Escolher",
): Promise<void> {
  if (choices.length === 0) {
    await sendText(to, body);
    return;
  }

  if (choices.length <= 3) {
    await send({
      to,
      type: "interactive",
      interactive: {
        type: "button",
        body: { text: body },
        action: {
          buttons: choices.map((choice) => ({
            type: "reply",
            reply: { id: choice.id, title: cut(choice.label, 20) },
          })),
        },
      },
    });
    return;
  }

  await send({
    to,
    type: "interactive",
    interactive: {
      type: "list",
      body: { text: body },
      action: {
        button: cut(listTitle, 20),
        sections: [{
          rows: choices.slice(0, 10).map((choice) => ({
            id: choice.id,
            title: cut(choice.label, 24),
            description: choice.detail ? cut(choice.detail, 72) : undefined,
          })),
        }],
      },
    },
  });
}

/**
 * Manda um template aprovado pela Meta.
 *
 * E o unico jeito de falar com quem nao escreveu antes — e o unico envio
 * cobrado. Os botoes de resposta rapida ja vem no template; aqui vai so o que
 * cada um devolve quando tocado, para o robo saber de qual horario se trata.
 *
 * Devolve se a Meta aceitou: so depois disso o horario pode ser marcado como
 * avisado.
 */
export function sendTemplate(
  to: string,
  name: string,
  variables: string[],
  buttonPayloads: string[] = [],
): Promise<boolean> {
  return send({
    to,
    type: "template",
    template: {
      name,
      language: { code: "pt_BR" },
      components: [
        ...(variables.length === 0 ? [] : [{
          type: "body",
          parameters: variables.map((text) => ({ type: "text", text })),
        }]),
        ...buttonPayloads.map((payload, index) => ({
          type: "button",
          sub_type: "quick_reply",
          index: String(index),
          parameters: [{ type: "payload", payload }],
        })),
      ],
    },
  });
}

/// Devolve se a Meta aceitou. Quem manda mensagem cobrada precisa saber.
async function send(message: Record<string, unknown>): Promise<boolean> {
  const response = await fetch(`${GRAPH}/${PHONE_ID}/messages`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ messaging_product: "whatsapp", ...message }),
  });

  if (!response.ok) {
    // Falha de envio nao pode derrubar o webhook: a Meta reenviaria tudo.
    console.error("envio falhou", response.status, await response.text());
    return false;
  }

  return true;
}

/** A Meta corta rotulo comprido sem avisar; melhor cortar com reticencia. */
function cut(text: string, max: number): string {
  return text.length <= max ? text : `${text.slice(0, max - 1)}…`;
}

interface WebhookPayload {
  entry?: Array<{
    changes?: Array<{
      value?: {
        contacts?: Array<{ profile?: { name?: string } }>;
        messages?: Array<{
          from: string;
          type: string;
          text?: { body?: string };
          button?: { payload?: string; text?: string };
          interactive?: {
            list_reply?: { id: string; title: string };
            button_reply?: { id: string; title: string };
          };
        }>;
      };
    }>;
  }>;
}
