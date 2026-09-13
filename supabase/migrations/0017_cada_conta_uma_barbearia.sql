-- Cada conta passa a ser uma barbearia.
--
-- Ate aqui o banco era de uma barbearia so — a do dono do projeto. Toda
-- politica dizia `to authenticated using (true)`: qualquer pessoa que
-- entrasse via **tudo**. Dois barbeiros com o mesmo app enxergariam os
-- clientes, a agenda e o caixa um do outro. Nao era falta de configuracao; era
-- o desenho.
--
-- Agora cada linha tem dono, e o dono e quem entrou. O app nao muda: ele
-- continua mandando as mesmas linhas, e `owner_id` se preenche sozinho com
-- quem esta logado. Quem decide o que cada um enxerga passa a ser o banco.
--
-- **Chave composta, e nao id global.** Os ids legiveis do app — `corte`,
-- `rent`, `pezinho` — sao chave primaria. Com duas barbearias, as duas tem um
-- servico `corte`, e a segunda seria recusada. Dono + id resolve sem abrir mao
-- do nome legivel, que e o que faz o banco ser lido sem consultar outra
-- tabela.

-- `=` sobre uuid dentro de um indice gist: e o que deixa a trava de
-- sobreposicao valer **por barbearia**, e nao para a cadeira do mundo inteiro.
create extension if not exists btree_gist;

-- ------------------------------------------------------------------- dono

do $$
declare
  t text;
  dono uuid;
begin
  -- A barbearia que ja existe fica com a conta que ja existe. Enquanto so ha
  -- uma, isso e exato; se houvesse duas, nao haveria como adivinhar e a
  -- migration falharia de proposito, em vez de dar as linhas para alguem.
  select id into strict dono from auth.users;

  foreach t in array array[
    'services', 'clients', 'shop_hours', 'shop_settings', 'time_blocks',
    'appointments', 'expense_categories', 'expenses', 'deleted_rows',
    'conversations'
  ] loop
    execute format('alter table %I add column if not exists owner_id uuid', t);
    execute format('update %I set owner_id = %L where owner_id is null', t, dono);
    execute format(
      'alter table %I alter column owner_id set not null, '
      'alter column owner_id set default auth.uid()', t);
    execute format(
      'alter table %I add constraint %I foreign key (owner_id) '
      'references auth.users (id) on delete cascade',
      t, t || '_owner_fkey');
  end loop;
end;
$$;

-- ------------------------------------------------- as chaves, agora por dono

alter table appointments drop constraint appointments_client_id_fkey;
alter table appointments drop constraint appointments_service_id_fkey;
alter table expenses     drop constraint expenses_category_fkey;

alter table services           drop constraint services_pkey;
alter table clients            drop constraint clients_pkey;
alter table shop_hours         drop constraint shop_hours_pkey;
alter table shop_settings      drop constraint shop_settings_pkey;
alter table time_blocks        drop constraint time_blocks_pkey;
alter table appointments       drop constraint appointments_pkey;
alter table expense_categories drop constraint expense_categories_pkey;
alter table expenses           drop constraint expenses_pkey;
alter table deleted_rows       drop constraint deleted_rows_pkey;
alter table conversations      drop constraint conversations_pkey;

alter table services           add primary key (owner_id, id);
alter table clients            add primary key (owner_id, id);
alter table shop_hours         add primary key (owner_id, weekday);
alter table time_blocks        add primary key (owner_id, id);
alter table appointments       add primary key (owner_id, id);
alter table expense_categories add primary key (owner_id, id);
alter table expenses           add primary key (owner_id, id);
alter table deleted_rows       add primary key (owner_id, table_name, row_id);
alter table conversations      add primary key (owner_id, phone);

-- Uma linha de ajustes por barbearia. O `id` travado em 1 era o jeito de dizer
-- "linha unica" quando so havia uma barbearia; agora quem diz isso e o dono.
alter table shop_settings drop constraint if exists shop_settings_id_check;
alter table shop_settings add primary key (owner_id);

-- O telefone identifica o cliente **dentro** de uma barbearia. A mesma pessoa
-- pode cortar em duas, e cada uma tem a ficha dela.
alter table clients drop constraint if exists clients_phone_key;
alter table clients add constraint clients_phone_key unique (owner_id, phone);

alter table appointments
  add constraint appointments_service_fkey
  foreign key (owner_id, service_id) references services (owner_id, id)
  on delete restrict;

alter table appointments
  add constraint appointments_client_fkey
  foreign key (owner_id, client_id) references clients (owner_id, id)
  on delete restrict;

alter table expenses
  add constraint expenses_category_fkey
  foreign key (owner_id, category) references expense_categories (owner_id, id);

-- A cadeira e de cada um: duas barbearias marcam as 14h sem se atrapalhar.
alter table appointments drop constraint if exists appointments_no_overlap;
alter table appointments
  add constraint appointments_no_overlap
  exclude using gist (
    owner_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  )
  where (status not in ('cancelled', 'no_show') and not walk_in);

-- --------------------------------------------------- quem enxerga o que

do $$
declare
  t text;
begin
  foreach t in array array[
    'services', 'clients', 'shop_hours', 'shop_settings', 'time_blocks',
    'appointments', 'expense_categories', 'expenses', 'conversations'
  ] loop
    -- Fora as politicas antigas, todas com `using (true)`.
    execute format(
      'do $inner$ declare p text; begin '
      '  for p in select policyname from pg_policies where schemaname = ''public'' and tablename = %L loop '
      '    execute format(''drop policy %%I on %I'', p); '
      '  end loop; end $inner$;', t, t);

    -- `(select auth.uid())` e nao `auth.uid()`: solto, o Postgres chama a
    -- funcao **uma vez por linha**; dentro do select ele resolve uma vez e usa
    -- o resultado. E a diferenca entre a agenda abrir na hora e engasgar.
    execute format(
      'create policy %I on %I for all to authenticated '
      'using (owner_id = (select auth.uid())) '
      'with check (owner_id = (select auth.uid()))',
      t || '_owner', t);
  end loop;
end;
$$;

-- O livro dos apagados continua so de leitura: quem escreve nele e o gatilho.
drop policy if exists deleted_rows_staff on deleted_rows;
create policy deleted_rows_owner on deleted_rows
  for select to authenticated
  using (owner_id = (select auth.uid()));

-- O gatilho grava com a mao da dona da tabela, entao precisa dizer o dono da
-- linha que sumiu — `auth.uid()` ali dentro seria nulo.
create or replace function record_deletion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into deleted_rows (owner_id, table_name, row_id)
  values (old.owner_id, tg_table_name, old.id::text)
  on conflict (owner_id, table_name, row_id)
    do update set deleted_at = now();
  return old;
end;
$$;
