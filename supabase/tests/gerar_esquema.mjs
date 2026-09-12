// Junta as migrations num arquivo so, para colar no SQL Editor do Supabase.
//
// O arquivo gerado nao e versionado de proposito: ele e copia do que ja esta
// em migrations/, e duas copias do mesmo SQL no git viram duas verdades no dia
// em que alguem editar uma so. Rode `npm run esquema` quando precisar dele.
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const DIR = fileURLToPath(new URL('../migrations/', import.meta.url));
const SAIDA = fileURLToPath(new URL('../esquema_completo.sql', import.meta.url));

const arquivos = readdirSync(DIR).filter((f) => f.endsWith('.sql')).sort();

const partes = arquivos.map((f) => {
  const barra = '-- ' + '='.repeat(58);
  return `${barra}\n-- ${f}\n${barra}\n\n${readFileSync(DIR + f, 'utf8').trimEnd()}\n`;
});

const cabeca = `-- Mispar — esquema completo, ${arquivos.length} migracoes em ordem.
--
-- Cole este arquivo inteiro no SQL Editor do Supabase e rode uma vez, num
-- projeto novo. Os papeis anon/authenticated/service_role ja existem la.
--
-- Gerado por \`npm run esquema\` em ${new Date().toISOString().slice(0, 10)}.
-- Nao edite aqui: edite a migration e gere de novo.

`;

writeFileSync(SAIDA, cabeca + partes.join('\n'));
console.log(`${arquivos.length} migrations -> supabase/esquema_completo.sql`);
