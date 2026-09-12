-- O gatilho da lápide escreve com a mão do dono, e não com a de quem apagou.
--
-- A 0012 deu a `authenticated` só leitura em `deleted_rows`, de propósito: o
-- livro dos apagados é escrito por gatilho, e ninguém deve poder riscar uma
-- lápide à mão — riscar é apagar a notícia de que algo sumiu.
--
-- Só que o gatilho roda com o papel de quem disparou. Então apagar um cliente
-- pelo app — que é a única coisa que o barbeiro faz ali — batia em
-- "permission denied for table deleted_rows", e a exclusão nunca chegava ao
-- servidor. O cliente apagado no celular voltava na descida seguinte.
--
-- `security definer` resolve sem abrir a porta: a função escreve como dona da
-- tabela, e o papel de quem apagou continua sem poder tocar no livro.
create or replace function record_deletion()
returns trigger
language plpgsql
security definer
set search_path = public
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

comment on function record_deletion() is
  'Anota quem foi apagado. `security definer` porque o livro e so-leitura para '
  'quem usa o app: quem escreve nele e o banco, nao a pessoa.';
