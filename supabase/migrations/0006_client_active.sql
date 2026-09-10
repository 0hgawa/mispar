-- Cliente fora da lista.
--
-- Espelha a coluna `active` do SQLite do app (schema v9). Serve para o Marcos
-- tirar da busca quem nao volta mais, sem apagar o historico — apagar levaria
-- junto os atendimentos, que sao o Caixa dele.

alter table clients
  add column if not exists active boolean not null default true;

-- De proposito, o robo do WhatsApp **nao** olha esta coluna. Ela e a lista do
-- app; se um cliente fora da lista mandar mensagem querendo marcar, ele marca
-- igual — recusar por causa de uma arrumacao de lista seria perder dinheiro na
-- porta.
