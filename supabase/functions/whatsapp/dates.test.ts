import { assertEquals } from "jsr:@std/assert@1";
import {
  addDays,
  hourOf,
  longDay,
  normalize,
  parseDay,
  shortDay,
  today,
  weekdayOf,
} from "./dates.ts";

Deno.test("normalize tira acento e caixa", () => {
  assertEquals(normalize("Sábado"), "sabado");
  assertEquals(normalize("  TERÇA  "), "terca");
  assertEquals(normalize("Não"), "nao");
});

Deno.test("addDays atravessa virada de mes", () => {
  assertEquals(addDays("2026-01-31", 1), "2026-02-01");
  assertEquals(addDays("2026-12-31", 1), "2027-01-01");
  assertEquals(addDays("2026-03-01", -1), "2026-02-28");
});

Deno.test("addDays atravessa ano bissexto", () => {
  assertEquals(addDays("2028-02-28", 1), "2028-02-29");
});

Deno.test("weekdayOf sabe o dia da semana", () => {
  // 10/09/2026 foi uma quinta-feira.
  assertEquals(weekdayOf("2026-09-10"), 4);
  assertEquals(weekdayOf("2026-09-13"), 0);
});

Deno.test("longDay escreve por extenso, com maiuscula", () => {
  assertEquals(longDay("2026-09-10"), "Quinta, 10 de setembro");
  assertEquals(longDay("2026-09-12"), "Sabado, 12 de setembro");
});

Deno.test("shortDay diz hoje e amanha", () => {
  assertEquals(shortDay(today()), "Hoje");
  assertEquals(shortDay(addDays(today(), 1)), "Amanha");
});

Deno.test("shortDay usa dia e mes para o resto", () => {
  const distant = addDays(today(), 9);
  const [, month, day] = distant.split("-");
  assertEquals(shortDay(distant).endsWith(`${day}/${month}`), true);
});

Deno.test("parseDay entende hoje, amanha e depois de amanha", () => {
  assertEquals(parseDay("hoje"), today());
  assertEquals(parseDay("pode ser amanha?"), addDays(today(), 1));
  assertEquals(parseDay("depois de amanha"), addDays(today(), 2));
});

Deno.test("parseDay entende dia da semana, com e sem acento", () => {
  const withAccent = parseDay("sábado");
  const without = parseDay("sabado");
  assertEquals(withAccent, without);
  assertEquals(weekdayOf(withAccent!), 6);
});

Deno.test("parseDay pega a proxima ocorrencia, nunca uma ja passada", () => {
  const parsed = parseDay("segunda")!;
  assertEquals(parsed >= today(), true);
  assertEquals(weekdayOf(parsed), 1);
});

Deno.test("parseDay entende data escrita", () => {
  const parsed = parseDay("marca dia 25/12 por favor")!;
  assertEquals(parsed.endsWith("-12-25"), true);
});

Deno.test("parseDay devolve null quando nao reconhece", () => {
  assertEquals(parseDay("qualquer coisa"), null);
  assertEquals(parseDay(""), null);
  assertEquals(parseDay("tanto faz"), null);
});

Deno.test("hourOf mostra a hora no fuso da loja", () => {
  assertEquals(hourOf("2026-09-10T17:00:00Z"), "14:00");
  assertEquals(hourOf("2026-09-10T12:30:00Z"), "09:30");
});
