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
  '0008_products_and_walk_ins.sql',
  '0009_reminder.sql',
  '0010_full_copy.sql',
  '0011_incremental_sync.sql',
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

// ---- produto e atendimento sem cliente ----

// O catalogo que veio do seed e todo de servico: produto nao existia.
const kinds = await one(
  `select count(*) filter (where kind = 'service')::int servicos,
          count(*) filter (where kind = 'product')::int produtos
     from services`,
);
check(
  'o catalogo antigo continua todo servico',
  kinds.servicos === 6 && kinds.produtos === 0,
  `${kinds.servicos} servicos, ${kinds.produtos} produtos`,
);

await db.exec(
  `insert into services (id, name, duration_minutes, price_cents, kind)
     values ('pomada', 'Pomada', 5, 3500, 'product')`,
);
const prod = await one(`select kind from services where id = 'pomada'`);
check('produto entra no catalogo', prod.kind === 'product');

// O robo so oferece o que ocupa cadeira.
const bookable = await one(
  `select count(*)::int n from services where active and kind = 'service'`,
);
check('o robo nao ve o produto', bookable.n === 6, `veio ${bookable.n}`);

// Terceiro tipo nao passa: o check protege contra erro de digitacao.
let refused = false;
try {
  await db.exec(
    `insert into services (id, name, duration_minutes, price_cents, kind)
       values ('x', 'X', 10, 100, 'pacote')`,
  );
} catch {
  refused = true;
}
check('tipo desconhecido e recusado', refused);

// Venda lancada no balcao: sem cliente, e ainda assim gravada.
const sale = await one(
  `insert into appointments (service_id, starts_at, duration_minutes, price_cents, status)
     values ('pomada', now(), 5, 3500, 'done')
     returning client_id`,
);
check('atendimento sem cliente e aceito', sale.client_id === null);


// ---- lembrete da vespera ----

const cfg0 = await one(`select reminder_enabled e, reminder_hours_before h from shop_settings`);
check('lembrete vem desligado de fabrica', cfg0.e === false && cfg0.h === 24, `${cfg0.e} / ${cfg0.h}h`);

const avisado = await one(
  `insert into clients (phone, name) values ('+5511922222222', 'Vespera') returning id`,
);
const perto = await one(
  `insert into appointments (client_id, service_id, starts_at, duration_minutes, price_cents, status)
     values ('${avisado.id}', 'corte', now() + interval '3 hours', 30, 4000, 'confirmed')
     returning id`,
);
await db.exec(
  `insert into appointments (client_id, service_id, starts_at, duration_minutes, price_cents, status)
     values ('${avisado.id}', 'corte', now() + interval '5 days', 30, 4000, 'confirmed')`,
);

const fila = async () => (await all(`select id, phone, client_name from due_reminders()`));

check('desligado nao manda nada', (await fila()).length === 0);

await db.exec(`update shop_settings set reminder_enabled = true`);
const dentro = await fila();
check('ligado, so o horario dentro da janela', dentro.length === 1 && dentro[0].id === perto.id, `${dentro.length} na fila`);
check('o lembrete leva telefone e nome', dentro[0]?.phone === '+5511922222222' && dentro[0]?.client_name === 'Vespera');

// Janela mais curta: o mesmo horario ainda nao chegou a vez.
await db.exec(`update shop_settings set reminder_hours_before = 2`);
check('janela curta deixa o horario para depois', (await fila()).length === 0);
await db.exec(`update shop_settings set reminder_hours_before = 24`);

// A trava contra pagar dois.
await db.exec(`update appointments set reminder_sent_at = now() where id = '${perto.id}'`);
check('nao manda duas vezes', (await fila()).length === 0);
await db.exec(`update appointments set reminder_sent_at = null where id = '${perto.id}'`);

await db.exec(`update appointments set status = 'cancelled' where id = '${perto.id}'`);
check('desmarcado nao recebe lembrete', (await fila()).length === 0);
await db.exec(`update appointments set status = 'confirmed' where id = '${perto.id}'`);

// Venda de balcao entra na janela, mas nao tem para quem mandar.
await db.exec(
  `insert into appointments (service_id, starts_at, duration_minutes, price_cents, status)
     values ('pomada', now() + interval '4 hours', 5, 3500, 'confirmed')`,
);
check('venda sem cliente nao entra na fila', (await fila()).length === 1);

let horaAbsurda = false;
try { await db.exec(`update shop_settings set reminder_hours_before = 100`); } catch { horaAbsurda = true; }
check('janela absurda e recusada', horaAbsurda);

// O id do horario viaja no botao da mensagem, entao o telefone tem que bater.
const alheio = await one(`select confirm_appointment('+5511900000000', '${perto.id}'::uuid) ok`);
check('ninguem confirma o horario de outro', alheio.ok === null, String(alheio.ok));
const dono = await one(`select confirm_appointment('+5511922222222', '${perto.id}'::uuid) ok`);
check('o dono do numero confirma', dono.ok === true, String(dono.ok));
const marca = await one(`select confirmed_at from appointments where id = '${perto.id}'`);
check('a confirmacao fica gravada', marca.confirmed_at !== null);

// A lista traz nome e telefone: a chave publica do app nao pode chama-la.
let anonBarrado = false;
try {
  await db.exec('set role anon');
  await db.query('select * from due_reminders()');
} catch {
  anonBarrado = true;
} finally {
  await db.exec('reset role');
}
check('a chave do app nao puxa a lista de lembretes', anonBarrado);

// E a varredura, que fala como serviceRole, continua chamando.
await db.exec('set role service_role');
const comoRobo = await all('select * from due_reminders()');
await db.exec('reset role');
check('o robo continua chamando', comoRobo.length === 1, `veio ${comoRobo.length}`);
// ---- 12. a copia completa: o servidor guarda o que o aparelho guarda ----

// Venda de balcao se declara, e nao se adivinha pela falta de cliente.
const balcao = await one('select walk_in from appointments limit 1');
check('horario marcado nasce sem ser balcao', balcao.walk_in === false, String(balcao.walk_in));

// O que o app ajusta sobe junto, mesmo o que o robo nunca le: esta aqui para
// nao se perder, e nao para ser usado.
const ajustes = await one(`
  select drifted_enabled, drifted_days, accepted_payments,
         shop_name, shop_address, shop_instagram
    from shop_settings`);
check('o aviso de sumido vem ligado, com 60 dias',
  ajustes.drifted_enabled === true && ajustes.drifted_days === 60,
  ajustes.drifted_enabled + ' / ' + ajustes.drifted_days);
check('de fabrica a barbearia aceita as tres formas',
  ajustes.accepted_payments === 'cash,pix,card', ajustes.accepted_payments);
check('cadastro da barbearia comeca vazio, e nao nulo',
  ajustes.shop_name === '' && ajustes.shop_address === '' && ajustes.shop_instagram === '');

// Prazo fora da conta e engano de digitacao, e passaria adiante escondendo
// clientes da lista ou acusando quem cortou sabado passado.
let prazoAbsurdo = false;
try { await db.exec('update shop_settings set drifted_days = 2'); } catch { prazoAbsurdo = true; }
check('prazo de sumido menor que uma semana e recusado', prazoAbsurdo);
let prazoLongo = false;
try { await db.exec('update shop_settings set drifted_days = 400'); } catch { prazoLongo = true; }
check('prazo maior que um ano e recusado', prazoLongo);
await db.exec('update shop_settings set drifted_days = 90');
const mudou = await one('select drifted_days from shop_settings');
check('prazo dentro da conta grava', mudou.drifted_days === 90, String(mudou.drifted_days));

// ---- 13. sincronia incremental: so o que mudou, e o que sumiu ----

// Editar carimba a hora. Sem o gatilho, quem gravasse sem preencher sumiria
// da sincronia sem erro nenhum.
const antes = await one("select updated_at from services where id = 'corte'");
await db.exec("update services set price_cents = 4500 where id = 'corte'");
const depois = await one("select updated_at from services where id = 'corte'");
check('editar carimba updated_at', depois.updated_at > antes.updated_at,
  antes.updated_at + ' -> ' + depois.updated_at);

// A pergunta que o celular faz a cada passada.
// O marco e o carimbo mais novo do catalogo, e nao o do corte: os testes
// acima ja inseriram servicos depois da migracao, e eles sao mais novos com
// razao. Depois do update, so o corte fica acima da marca.
const marcoSync = (await one('select max(updated_at) t from services')).t;
await db.exec("update services set price_cents = 4600 where id = 'corte'");
const desdeEntao = await all(
  'select id from services where updated_at > $1 order by id', [marcoSync]);
check('so o que mudou volta na passada',
  desdeEntao.length === 1 && desdeEntao[0].id === 'corte',
  JSON.stringify(desdeEntao));

// Consulta incremental nao enxerga o que sumiu: a linha nao esta mais la para
// contar. Por isso a lapide.
await db.exec("insert into services (id, name, duration_minutes, price_cents) values ('teste', 'Teste', 30, 1000)");
const marco = (await one('select now() t')).t;
await db.exec("delete from services where id = 'teste'");
const lapides = await all(
  'select table_name, row_id from deleted_rows where deleted_at >= $1', [marco]);
check('apagar deixa lapide para o celular achar',
  lapides.length === 1 && lapides[0].table_name === 'services' && lapides[0].row_id === 'teste',
  JSON.stringify(lapides));

// Linha recriada e apagada de novo vale pela data mais nova — e a noticia que
// o aparelho ainda nao tem.
await db.exec("insert into services (id, name, duration_minutes, price_cents) values ('teste', 'Teste', 30, 1000)");
await db.exec("delete from services where id = 'teste'");
const umaSo = await one("select count(*)::int n from deleted_rows where row_id = 'teste'");
check('apagar duas vezes deixa uma lapide so', umaSo.n === 1, String(umaSo.n));

// Ajuste nao se apaga, se edita: linha fixa nao ganha lapide.
const semLapide = await one(
  "select count(*)::int n from pg_trigger where tgname = 'shop_settings_tombstone'");
check('ajuste de linha fixa nao ganha lapide', semLapide.n === 0, String(semLapide.n));

// A chave publica do app nao pode ler o livro dos apagados sem entrar.
let anonNoLivro = false;
try {
  await db.exec('set role anon');
  await db.query('select * from deleted_rows');
  anonNoLivro = true;
} catch {
} finally {
  await db.exec('reset role');
}
check('anonimo nao le o livro dos apagados', anonNoLivro === false);

// O indice da fila de lembretes existe: sem ele o cron varre a agenda inteira
// de dez em dez minutos, para sempre.
const idx = await one(
  "select count(*)::int n from pg_indexes where indexname = 'appointments_due_idx'");
check('a fila de lembretes tem indice proprio', idx.n === 1, String(idx.n));

console.log(failed === 0 ? '\nTUDO PASSOU' : `\n${failed} FALHA(S)`);
process.exit(failed === 0 ? 0 : 1);
