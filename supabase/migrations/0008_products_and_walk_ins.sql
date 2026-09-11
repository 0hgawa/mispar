-- Produto no catalogo, e atendimento sem cliente.
--
-- O app passou a vender pomada e a lancar quem chega sem marcar. Estas duas
-- mudancas ja existem no banco do aparelho; aqui elas alcancam o Postgres, que
-- e o banco que o robo le. Sem a primeira, o robo ofereceria "Pomada" como
-- horario para marcar.

-- O que a barbearia vende e nao ocupa cadeira.
--
-- Texto com check, e nao enum: produto e servico sao os dois casos que
-- existem, e um enum novo obrigaria migracao so para acrescentar um terceiro.
alter table services
  add column if not exists kind text not null default 'service'
    check (kind in ('service', 'product'));

comment on column services.kind is
  'service ocupa horario e se marca; product so e vendido.';

-- Quem chega sem marcar nao tem cadastro, e exigir um nome faria a venda nao
-- ser lancada — que e o problema que o campo vazio resolve.
alter table appointments
  alter column client_id drop not null;

comment on column appointments.client_id is
  'Nulo no que foi lancado direto no Caixa, sem hora marcada.';
