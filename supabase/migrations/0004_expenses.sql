-- Despesas da barbearia.
--
-- Faturamento nao e lucro: sem o que sai, o Caixa mostra so metade da conta.
-- Espelha as tabelas `expense_categories` e `expenses` do SQLite do app
-- (schema v5).

-- No que o dinheiro sai. E cadastro, e nao lista fixa no codigo: os custos de
-- cada barbearia sao os dela — contador, sindicato, uniforme.
create table if not exists expense_categories (
  id      text primary key,
  name    text    not null,

  -- Tipo aposentado sai do formulario sem apagar o que ja foi lancado nele.
  active  boolean not null default true
);

-- O ponto de partida, igual ao do app. Os ids sao os mesmos, para o que ja
-- estiver lancado no celular achar o seu tipo aqui.
insert into expense_categories (id, name) values
  ('products',  'Produtos'),
  ('rent',      'Aluguel'),
  ('utilities', 'Água e luz'),
  ('card-fees', 'Maquininha'),
  ('marketing', 'Divulgação'),
  ('tools',     'Equipamento'),
  ('other',     'Outros')
on conflict (id) do nothing;

create table if not exists expenses (
  id          text primary key,
  spent_at    timestamptz not null,

  -- A coluna se chama "category" desde que o tipo era constante do codigo.
  -- Renomear custaria migracao dos dois lados e nao mudaria nada.
  category    text        not null references expense_categories (id),

  -- Em centavos, como todo dinheiro aqui. Zero nao e despesa.
  cents       integer     not null check (cents > 0),
  note        text,

  -- Aluguel, internet, contador: o app lanca sozinho todo mes.
  repeats_monthly boolean not null default false,

  -- Liga as copias mensais a um mesmo gasto.
  series_id   text,
  created_at  timestamptz not null default now()
);

-- O caixa sempre pergunta por periodo.
create index if not exists expenses_spent_at_idx on expenses (spent_at desc);

alter table expense_categories enable row level security;
alter table expenses enable row level security;

-- So o dono mexe no proprio dinheiro. O robo do WhatsApp nao tem nada que
-- ver aqui: ele marca horario, nao lanca gasto.
drop policy if exists expense_categories_owner_all on expense_categories;
create policy expense_categories_owner_all on expense_categories
  for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists expenses_owner_all on expenses;
create policy expenses_owner_all on expenses
  for all
  to authenticated
  using (true)
  with check (true);
