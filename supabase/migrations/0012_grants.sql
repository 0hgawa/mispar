-- Quem pode tocar em cada tabela, dito aqui e nao num interruptor do painel.
--
-- Ate agora o esquema so ligava RLS e escrevia politica. Faltava a outra
-- metade: no Postgres o acesso passa por **duas** portas, e as duas tem que
-- abrir. O `grant` diz se o papel pode ao menos tentar; a politica decide
-- quais linhas ele ve. Politica sem grant nao da acesso nenhum — a consulta
-- morre antes, em "permission denied".
--
-- Sem este arquivo, o projeto so funcionava com "Automatically expose new
-- tables" ligado na criacao — quer dizer, o esquema dependia de uma caixinha
-- marcada uma vez, fora do git, que ninguem lembraria de marcar de novo. Com
-- os grants escritos, o projeto se recria igual com a caixinha desligada, que
-- e o que o proprio Supabase recomenda.

grant usage on schema public to anon, authenticated;

-- ------------------------------------------------------------- o barbeiro
-- Tudo, em tudo. Quem manda no que ele ve e a RLS, que ja esta escrita para
-- `authenticated` desde a 0001. E um app de uma pessoa: nao ha o que esconder
-- dela dentro da propria barbearia.
grant select, insert, update, delete on
  services, clients, shop_hours, time_blocks, appointments,
  expense_categories, expenses, shop_settings, conversations
  to authenticated;

-- O livro dos apagados so se le: quem escreve nele e o gatilho, e reescrever
-- lapide seria apagar a noticia de que algo sumiu.
grant select on deleted_rows to authenticated;

-- ---------------------------------------------------------------- anonimo
-- Nada. E deliberado, e vale a pena dizer por que:
--
-- A chave publicavel do app entra como `anon` **ate o login**. Se `anon`
-- enxergasse qualquer coisa, a base de clientes e a agenda inteira estariam
-- abertas para quem lesse a chave dentro do APK — e ela e publica por design.
-- Fechado aqui, a chave sozinha nao vale nada: ela so abre porta depois que
-- alguem entra com e-mail e senha.
--
-- O robo nao precisa de `anon`: ele fala como `service_role`, de dentro da
-- edge function, e `service_role` passa por cima da RLS.
revoke all on all tables in schema public from anon;

-- A politica 0007 deixava `anon` ler os ajustes, mirando no robo. Nunca valeu
-- nada: sem grant, a leitura morria antes da politica. Sai para o arquivo
-- parar de prometer um acesso que nao existe.
drop policy if exists shop_settings_read on shop_settings;

create policy shop_settings_read on shop_settings
  for select
  to authenticated
  using (true);
