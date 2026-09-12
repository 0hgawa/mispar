-- O servidor passa a aceitar o que o aparelho realmente grava.
--
-- A subida so serve se tudo couber. Duas regras do Postgres recusavam linhas
-- que o app cria todo dia, e cada recusa seria uma linha que nunca chega — um
-- backup com buraco, que e pior que nenhum porque ninguem sabe onde esta o
-- buraco.

-- --------------------------------------------------------- cliente sem telefone
--
-- A tela de marcar pede "Telefone (opcional)", e o barbeiro pula. No servidor
-- a coluna era obrigatoria, unica e no formato internacional — entao o cliente
-- anotado so pelo nome nunca subiria, e dois deles colidiriam no `unique` por
-- serem o mesmo texto vazio.
--
-- Nulo, e nao vazio: no Postgres dois nulos nao se chocam no indice unico, e e
-- assim que se diz "nao sei" sem inventar um valor. O formato continua exigido
-- de quem tem numero — telefone errado quebra o robo, e ai o erro tem que
-- aparecer na hora de gravar.
alter table clients alter column phone drop not null;

alter table clients drop constraint if exists clients_phone_check;
alter table clients
  add constraint clients_phone_check
  check (phone is null or phone ~ '^\+[1-9][0-9]{7,14}$');

comment on column clients.phone is
  'Nulo quando ninguem anotou. O robo simplesmente nao acha esse cliente, que '
  'e a verdade: sem numero nao ha conversa.';

-- ------------------------------------------------------ balcao nao disputa cadeira
--
-- A trava de sobreposicao existe para a agenda: duas pessoas nao sentam na
-- mesma cadeira as 14h. Lancamento de balcao nao e reserva — e a anotacao de
-- algo que ja aconteceu, e ele nasce concluido. O Marcos pode muito bem
-- registrar uma venda de pomada as 14h enquanto alguem estava cortando.
--
-- Sem esta excecao, esse lancamento seria recusado pelo servidor para sempre,
-- e o aparelho ficaria tentando subir a mesma linha a cada passada.
alter table appointments drop constraint if exists appointments_no_overlap;

alter table appointments
  add constraint appointments_no_overlap
  exclude using gist (tstzrange(starts_at, ends_at, '[)') with &&)
  where (status not in ('cancelled', 'no_show') and not walk_in);
