-- Fiado: o atendimento aconteceu e o dinheiro nao entrou.
--
-- Antes isso nao tinha onde morar no banco. O barbeiro tinha duas saidas, e as
-- duas mentiam: anotar uma forma de pagamento que nao houve — e o Caixa passa
-- a dizer que ele tem um dinheiro que nao tem — ou deixar o horario aberto,
-- como se o cliente nao tivesse vindo e a cadeira estivesse livre.
--
-- A cadeira foi usada, entao o atendimento fecha. O dinheiro fica devendo.
alter table appointments
  add column if not exists owed boolean not null default false;

comment on column appointments.owed is
  'Concluido sem receber. Enquanto for verdade, payment_method e nulo e o '
  'Caixa nao conta o valor como entrada.';

-- Devendo e pago sao estados que se excluem: se ha forma de pagamento, o
-- dinheiro entrou. Sem esta trava, um "recebi depois" mal gravado deixaria o
-- valor contado duas vezes — como entrada e como divida.
alter table appointments drop constraint if exists appointments_owed_check;
alter table appointments
  add constraint appointments_owed_check
  check (not owed or payment_method is null);
