import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const DIR = fileURLToPath(new URL('../migrations/', import.meta.url));
const db = await new PGlite();
process.on('uncaughtException', (e) => { console.log('ERRO NAO TRATADO: ' + String(e.message).slice(0, 200)); process.exit(1); });

let failed = 0;
const check = (name, ok, detail = '') => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ' — ' + detail : ''}`);
  if (!ok) failed++;
};

// O Supabase ja traz estes papeis; o Postgres puro nao.
await db.exec(`create role anon; create role authenticated; create role service_role;`);

// ---- 1. as migrations aplicam ----
for (const file of [
  '0001_schema.sql',
  '0002_availability.sql',
  '0003_seed.sql',
  '0004_expenses.sql',
  '0005_payment_method.sql',
  '0006_client_active.sql',
  '0007_slot_step.sql',
]) {
  try {
    await db.exec(readFileSync(DIR + file, 'utf8'));
    check(`migration ${file}`, true);
  } catch (e) {
    check(`migration ${file}`, false, e.message);
    process.exit(1);
  }
}

const one = async (sql, params) => (await db.query(sql, params)).rows[0];
const all = async (sql, params) => (await db.query(sql, params)).rows;

// ---- 2. o seed entrou ----
const svc = await one(`select count(*)::int n from services`);
check('6 servicos no catalogo', svc.n === 6, `veio ${svc.n}`);
const hrs = await one(`select count(*)::int n from shop_hours where is_open`);
check('6 dias abertos, domingo fechado', hrs.n === 6, `veio ${hrs.n}`);

// ---- 3. telefone precisa ser E.164 ----
try {
  await db.exec(`insert into clients (phone, name) values ('11988124471', 'Rafael')`);
  check('telefone sem + e recusado', false, 'aceitou');
} catch { check('telefone sem + e recusado', true); }

// ---- 4. marcar horario ----
// Uma quinta-feira futura, 14:00 em Sao Paulo.
const day = '2027-03-11';
const at = (h, m = 0) => `${day} ${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}-03`;

const booked = await one(
  `select book_appointment('+5511988124471', 'Rafael Lima', 'corte-barba', $1::timestamptz) id`,
  [at(14)],
);
check('book_appointment devolve id', !!booked.id);

const appt = await one(`select duration_minutes d, price_cents p, status::text s from appointments`);
check('duracao e preco ficam gravados no agendamento', appt.d === 50 && appt.p === 6000, `${appt.d}min R$${appt.p / 100}`);
check('sem sinal ja entra confirmado', appt.s === 'confirmed', appt.s);

// ---- 5. servico com sinal entra aguardando ----
await db.exec(`select book_appointment('+5511999999999', 'Jonas Beiral', 'platinado', '${at(16)}'::timestamptz)`);
const dep = await one(`select status::text s from appointments where service_id = 'platinado'`);
check('servico com sinal entra aguardando', dep.s === 'awaiting', dep.s);

// ---- 6. o banco recusa sobreposicao ----
try {
  await db.exec(`select book_appointment('+5511977777777', 'Outro', 'corte', '${at(14, 30)}'::timestamptz)`);
  check('sobreposicao e recusada pelo banco', false, 'deixou marcar em cima');
} catch (e) {
  check('sobreposicao e recusada pelo banco', /HORARIO_OCUPADO/.test(e.message), e.message.slice(0, 60));
}

// ---- 7. encostar sem invadir e permitido ----
try {
  await db.exec(`select book_appointment('+5511966666666', 'Colado', 'corte', '${at(14, 50)}'::timestamptz)`);
  check('horario colado no anterior e aceito', true);
} catch (e) { check('horario colado no anterior e aceito', false, e.message.slice(0, 60)); }

// ---- 8. cancelar libera o horario ----
await db.exec(`select cancel_appointment('+5511988124471', '${booked.id}'::uuid)`);
try {
  await db.exec(`select book_appointment('+5511955555555', 'Substituto', 'corte', '${at(14)}'::timestamptz)`);
  check('cancelar libera o horario para outro', true);
} catch (e) { check('cancelar libera o horario para outro', false, e.message.slice(0, 60)); }

// ---- 9. ninguem cancela o corte do vizinho ----
const stranger = await all(`select cancel_appointment('+5511900000000', '${booked.id}'::uuid) ok`);
check('telefone errado nao cancela', stranger.length === 0 || !stranger[0].ok);

// ---- 10. disponibilidade ----
const free = await all(`select starts_at from available_slots($1::date, 'corte')`, [day]);
check('available_slots devolve horarios', free.length > 0, `${free.length} vagas`);

const hhmm = (d) => new Date(d).toLocaleTimeString('pt-BR', { timeZone: 'America/Sao_Paulo', hour: '2-digit', minute: '2-digit' });
const times = free.map((r) => hhmm(r.starts_at));
check('nao oferece durante o almoco', !times.some((t) => t > '12:10' && t < '13:30'), times.filter((t) => t > '12:10' && t < '13:30').join(' '));
check('nao oferece em cima de horario marcado', !times.includes('16:30'), '16:30 tem platinado');
check('primeiro horario e 09:00', times[0] === '09:00', times[0]);
check('ultimo corte cabe antes de fechar', times.at(-1) <= '18:30', times.at(-1));

// ---- 11. bloqueio some da lista ----
await db.exec(`insert into time_blocks (starts_at, ends_at, reason) values ('${at(10)}', '${at(11)}', 'Medico')`);
const afterBlock = (await all(`select starts_at from available_slots($1::date, 'corte')`, [day])).map((r) => hhmm(r.starts_at));
check('bloqueio remove os horarios', !afterBlock.includes('10:00') && !afterBlock.includes('10:30'));

// ---- 12. domingo nao tem horario ----
const sunday = await all(`select starts_at from available_slots('2027-03-14'::date, 'corte')`);
check('domingo nao devolve nada', sunday.length === 0, `veio ${sunday.length}`);

// ---- 13. dia no passado nao devolve nada ----
const past = await all(`select starts_at from available_slots('2020-01-06'::date, 'corte')`);
check('dia no passado nao devolve nada', past.length === 0, `veio ${past.length}`);

// ---- 14. servico inexistente ----
try {
  await db.exec(`select book_appointment('+5511911111111', 'X', 'sobrancelha', '${at(9)}'::timestamptz)`);
  check('servico inexistente e recusado', false, 'aceitou');
} catch (e) { check('servico inexistente e recusado', /SERVICO_INEXISTENTE/.test(e.message), e.message.slice(0, 60)); }

// ---- despesas ----
const cats = await one(`select count(*)::int n from expense_categories`);
check('7 tipos de despesa no seed', cats.n === 7, `veio ${cats.n}`);

// O tipo tem que existir: gasto solto nao aparece no Caixa, porque a consulta
// junta pelo tipo para pegar o nome.
try {
  await db.exec(
    `insert into expenses (id, spent_at, category, cents)
     values ('x', now(), 'inexistente', 100)`,
  );
  check('tipo inexistente e recusado', false, 'o banco aceitou');
} catch {
  check('tipo inexistente e recusado', true);
}

// Zero nao e despesa.
try {
  await db.exec(
    `insert into expenses (id, spent_at, category, cents)
     values ('y', now(), 'rent', 0)`,
  );
  check('despesa de zero e recusada', false, 'o banco aceitou');
} catch {
  check('despesa de zero e recusada', true);
}

await db.exec(
  `insert into expenses (id, spent_at, category, cents, repeats_monthly, series_id)
   values ('z', now(), 'rent', 80000, true, 'z')`,
);
const rent = await one(`select cents, repeats_monthly from expenses where id = 'z'`);
check('aluguel mensal gravado', rent.cents === 80000 && rent.repeats_monthly === true);

// ---- forma de pagamento ----
// Marcado nao foi pago ainda: anotar Pix num horario aberto seria dinheiro
// que nao entrou.
const scheduled = await one(
  `select id from appointments where status <> 'done' limit 1`,
);
if (scheduled) {
  try {
    await db.exec(
      `update appointments set payment_method = 'pix' where id = '${scheduled.id}'`,
    );
    check('pagamento so em atendimento concluido', false, 'o banco aceitou');
  } catch {
    check('pagamento so em atendimento concluido', true);
  }
}

const done = await one(
  `select id from appointments where status = 'done' limit 1`,
);
if (done) {
  await db.exec(
    `update appointments set payment_method = 'pix' where id = '${done.id}'`,
  );
  const row = await one(
    `select payment_method from appointments where id = '${done.id}'`,
  );
  check('pagamento gravado no concluido', row.payment_method === 'pix');
}

// ---- cliente fora da lista ----
// Apagar cliente com atendimento levaria o atendimento junto, e com ele o
// Caixa. O banco tem que recusar mesmo que a tela deixe passar.
const withHistory = await one(
  `select c.id from clients c join appointments a on a.client_id = c.id limit 1`,
);
if (withHistory) {
  try {
    await db.exec(`delete from clients where id = '${withHistory.id}'`);
    check('cliente com atendimento nao se apaga', false, 'o banco aceitou');
  } catch {
    check('cliente com atendimento nao se apaga', true);
  }

  await db.exec(
    `update clients set active = false where id = '${withHistory.id}'`,
  );
  const off = await one(
    `select active from clients where id = '${withHistory.id}'`,
  );
  check('cliente sai da lista sem perder historico', off.active === false);

  const kept = await one(
    `select count(*)::int n from appointments where client_id = '${withHistory.id}'`,
  );
  check('os atendimentos dele continuam la', kept.n > 0, `veio ${kept.n}`);
}

// Quem nunca veio se apaga de vez.
const typo = await one(
  `insert into clients (phone, name)
   values ('+5511900000000', 'Rafel Lima') returning id`,
);
await db.exec(`delete from clients where id = '${typo.id}'`);
const gone = await one(
  `select count(*)::int n from clients where id = '${typo.id}'`,
);
check('cliente sem atendimento se apaga', gone.n === 0);

// ---- o passo sai da tabela, nao do codigo ----
// Sem isto, o app e o robo podem oferecer grades diferentes no mesmo dia.
const dia = '2026-09-14'; // segunda

const passo = async (minutos) => {
  await db.exec(`update shop_settings set slot_step_minutes = ${minutos}`);
  const rows = await all(
    `select starts_at from available_slots('${dia}'::date, 'corte')
      order by starts_at limit 2`,
  );
  if (rows.length < 2) return null;
  return (new Date(rows[1].starts_at) - new Date(rows[0].starts_at)) / 60000;
};

const de15 = await passo(15);
check('passo de 15 devolve horarios de 15 em 15', de15 === 15, `veio ${de15}`);

const de30 = await passo(30);
check('mudar para 30 muda a grade', de30 === 30, `veio ${de30}`);

// Volta ao padrao para nao contaminar o resto.
await db.exec(`update shop_settings set slot_step_minutes = 15`);

console.log(failed === 0 ? '\nTUDO PASSOU' : `\n${failed} FALHA(S)`);
process.exit(failed === 0 ? 0 : 1);
