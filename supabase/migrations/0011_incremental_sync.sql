-- Sincronia incremental: o celular passa a puxar so o que mudou.
--
-- Ate aqui, **qualquer** mudanca no servidor fazia o app rebaixar tudo de
-- novo — o catalogo inteiro, a base de clientes inteira e noventa dias de
-- agenda. Um horario marcado pelo robo custava tudo isso. Numa barbearia de
-- uma cadeira ninguem sente, mas e trabalho O(tudo) por evento: cresce com o
-- tamanho do historico, nao com o tamanho da mudanca.
--
-- Duas pecas resolvem, e as duas tem que existir:
--
-- 1. `updated_at` em toda tabela, mexido por gatilho. O app guarda a hora da
--    ultima passada e pergunta "o que mudou desde entao?".
--
-- 2. `deleted_rows`, o livro dos apagados. Consulta incremental **nao enxerga
--    o que sumiu**: a linha nao esta mais la para dizer que se foi, e o
--    cliente apagado no servidor ficaria para sempre no celular. O gatilho
--    anota o id ao apagar, e a proxima passada leva a noticia.
--
-- Nenhuma das duas muda o comportamento de quem escreve hoje.

-- ------------------------------------------------------------ quando mudou

create or replace function touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function touch_updated_at() is
  'Carimba a hora da escrita. Gatilho, e nao responsabilidade de quem grava: '
  'quem esquecesse de preencher sumiria da sincronia sem erro nenhum.';

-- ------------------------------------------------------------ o que sumiu

create table if not exists deleted_rows (
  -- Nome da tabela e id em texto: uma lapide serve para todas, e uuid e text
  -- cabem no mesmo lugar.
  table_name text        not null,
  row_id     text        not null,
  deleted_at timestamptz not null default now(),
  primary key (table_name, row_id)
);

comment on table deleted_rows is
  'O livro dos apagados. Sem ele a sincronia incremental so sabe somar: '
  'servico aposentado e cliente removido ficariam para sempre no aparelho.';

create index if not exists deleted_rows_when_idx on deleted_rows (deleted_at);

alter table deleted_rows enable row level security;

drop policy if exists deleted_rows_staff on deleted_rows;
create policy deleted_rows_staff on deleted_rows
  for select
  to authenticated
  using (true);

create or replace function record_deletion()
returns trigger
language plpgsql
as $$
begin
  -- Reapagar o mesmo id acontece quando uma linha e recriada e removida de
  -- novo; vale a data mais nova, que e a noticia que o celular ainda nao tem.
  insert into deleted_rows (table_name, row_id)
  values (tg_table_name, old.id::text)
  on conflict (table_name, row_id)
    do update set deleted_at = now();
  return old;
end;
$$;

-- --------------------------------------------------- ligando nas tabelas

do $$
declare
  t text;
begin
  foreach t in array array[
    'services', 'clients', 'shop_hours', 'time_blocks',
    'appointments', 'expense_categories', 'expenses', 'shop_settings'
  ] loop
    execute format(
      'alter table %I add column if not exists updated_at timestamptz not null default now()', t);

    execute format('drop trigger if exists %I on %I', t || '_touch', t);
    execute format(
      'create trigger %I before update on %I for each row execute function touch_updated_at()',
      t || '_touch', t);

    -- O indice e o que faz "mudou depois de tal hora" ser uma faixa lida de
    -- ponta, e nao a tabela inteira varrida a cada passada.
    execute format(
      'create index if not exists %I on %I (updated_at)', t || '_updated_idx', t);
  end loop;

  -- A lapide so para as tabelas de onde o app realmente apaga. `shop_hours` e
  -- `shop_settings` tem linha fixa: nao se apagam, se editam.
  foreach t in array array[
    'services', 'clients', 'time_blocks',
    'appointments', 'expense_categories', 'expenses'
  ] loop
    execute format('drop trigger if exists %I on %I', t || '_tombstone', t);
    execute format(
      'create trigger %I after delete on %I for each row execute function record_deletion()',
      t || '_tombstone', t);
  end loop;
end;
$$;

-- ------------------------------------------------------ o que o robo pede

-- A fila de lembretes varre por status e hora de inicio. Sem isto ela le a
-- agenda inteira a cada passada do cron, de dez em dez minutos, para sempre.
create index if not exists appointments_due_idx
  on appointments (starts_at)
  where reminder_sent_at is null;

-- O robo chega pelo telefone e o Caixa fecha o mes por data. As duas ja tem
-- indice: `clients.phone` e unique, `expenses.spent_at` veio na 0004.
