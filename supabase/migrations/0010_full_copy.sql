-- O Postgres passa a guardar tudo o que o aparelho guarda.
--
-- Ate aqui o servidor existia para o robo: so as colunas que ele precisava
-- para conversar subiam. O resto — o que o Marcos ajusta na mao — vivia num
-- arquivo SQLite so, dentro de um celular so. Celular quebrado era tudo
-- perdido, e nao havia de onde recuperar.
--
-- Com a copia completa, celular novo entra com e-mail e senha e volta inteiro.
-- Por isso sobem tambem colunas que o robo nunca vai ler: elas nao estao aqui
-- para serem usadas, estao aqui para nao se perderem.
--
-- Espelha o schema v17 do Drift.

-- ---------------------------------------------------------------- balcao
-- Digitado direto no Caixa, sem ter passado pela agenda.
--
-- Coluna, e nao "sem cliente": o balcao tambem se cadastra, e lancamento com
-- nome escolhido continua sendo lancamento. Sem isto, o app confundia venda de
-- balcao com horario marcado e trancava a edicao do proprio lancamento.
alter table appointments
  add column if not exists walk_in boolean not null default false;

comment on column appointments.walk_in is
  'Lancado direto no Caixa. O robo nunca cria um destes: ele so marca horario.';

-- O que ja estava gravado sem cliente era lancamento de balcao — era assim que
-- o app reconhecia um ate agora.
update appointments set walk_in = true where client_id is null;

-- ------------------------------------------------------------- ajustes
alter table shop_settings
  -- Quando um cliente conta como sumido. So a lista de clientes le; o robo
  -- nao tem nada a ver com isso.
  add column if not exists drifted_enabled boolean not null default true,
  add column if not exists drifted_days    integer not null default 60,

  -- As formas de pagamento aceitas, separadas por virgula. Texto e nao tres
  -- colunas: uma quarta forma um dia nao vira migracao.
  add column if not exists accepted_payments text not null default 'cash,pix,card',

  -- O cadastro da barbearia. Estes tres o robo vai querer, para responder
  -- "onde fica?" sem o Marcos digitar.
  add column if not exists shop_name      text not null default '',
  add column if not exists shop_address   text not null default '',
  add column if not exists shop_instagram text not null default '';

alter table shop_settings
  drop constraint if exists shop_settings_drifted_days_check;
alter table shop_settings
  add constraint shop_settings_drifted_days_check
  check (drifted_days between 7 and 365);

comment on column shop_settings.drifted_days is
  'Dias sem aparecer para contar como sumido. Entre 7 e 365: menos de uma '
  'semana acusa quem cortou sabado passado, e mais de um ano nao avisa nada.';

comment on column shop_settings.shop_instagram is
  'O @ sem arroba e em minuscula, que e como ele entra no endereco do perfil.';
