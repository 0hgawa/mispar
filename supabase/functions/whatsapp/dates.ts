// Datas em portugues, no fuso da loja.
//
// Tudo que o cliente digita ou ve passa por aqui. O banco guarda timestamptz;
// a conversa fala "sabado as 14h".

export const TIMEZONE = "America/Sao_Paulo";

const WEEKDAYS = [
  "domingo",
  "segunda",
  "terca",
  "quarta",
  "quinta",
  "sexta",
  "sabado",
];

const MONTHS = [
  "janeiro", "fevereiro", "marco", "abril", "maio", "junho",
  "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
];

/** Tira acento e caixa: "Sábado" e "sabado" tem que dar na mesma coisa. */
export function normalize(text: string): string {
  return text
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim();
}

/** Data de hoje na loja, como `YYYY-MM-DD`. */
export function today(): string {
  return new Date().toLocaleDateString("en-CA", { timeZone: TIMEZONE });
}

export function addDays(isoDay: string, days: number): string {
  const date = new Date(`${isoDay}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

/** 0 = domingo. */
export function weekdayOf(isoDay: string): number {
  return new Date(`${isoDay}T12:00:00Z`).getUTCDay();
}

/** "Sabado, 14 de marco" */
export function longDay(isoDay: string): string {
  const date = new Date(`${isoDay}T12:00:00Z`);
  const weekday = WEEKDAYS[date.getUTCDay()];
  const label = weekday[0].toUpperCase() + weekday.slice(1);
  return `${label}, ${date.getUTCDate()} de ${MONTHS[date.getUTCMonth()]}`;
}

/** "hoje", "amanha" ou "sabado, 14/03" — o rotulo curto dos botoes. */
export function shortDay(isoDay: string): string {
  const now = today();
  if (isoDay === now) return "Hoje";
  if (isoDay === addDays(now, 1)) return "Amanha";

  const date = new Date(`${isoDay}T12:00:00Z`);
  const weekday = WEEKDAYS[date.getUTCDay()];
  const day = String(date.getUTCDate()).padStart(2, "0");
  const month = String(date.getUTCMonth() + 1).padStart(2, "0");
  return `${weekday[0].toUpperCase()}${weekday.slice(1)} ${day}/${month}`;
}

/** "14:00" a partir de um instante. */
export function hourOf(instant: string): string {
  return new Date(instant).toLocaleTimeString("pt-BR", {
    timeZone: TIMEZONE,
    hour: "2-digit",
    minute: "2-digit",
  });
}

/**
 * Entende o dia que o cliente escreveu.
 *
 * Aceita "hoje", "amanha", nome de dia da semana e "14/03". Devolve null
 * quando nao reconhece — nesse caso o robo pergunta em vez de chutar.
 */
export function parseDay(text: string): string | null {
  const input = normalize(text);
  const now = today();

  if (/\bhoje\b/.test(input)) return now;
  // "depois de amanha" antes de "amanha": o segundo casa dentro do primeiro.
  if (/\bdepois de amanha\b/.test(input)) return addDays(now, 2);
  if (/\bamanha\b/.test(input)) return addDays(now, 1);

  const slashed = input.match(/\b(\d{1,2})[/](\d{1,2})\b/);
  if (slashed) {
    const [, day, month] = slashed;
    const year = new Date(`${now}T12:00:00Z`).getUTCFullYear();
    const iso = `${year}-${month.padStart(2, "0")}-${day.padStart(2, "0")}`;
    // Dia que ja passou neste ano quer dizer o ano que vem.
    return iso < now ? `${year + 1}${iso.slice(4)}` : iso;
  }

  const wanted = WEEKDAYS.findIndex((name) => input.includes(name));
  if (wanted === -1) return null;

  // Proxima ocorrencia daquele dia da semana, hoje incluso.
  for (let ahead = 0; ahead < 7; ahead++) {
    const candidate = addDays(now, ahead);
    if (weekdayOf(candidate) === wanted) return candidate;
  }
  return null;
}
