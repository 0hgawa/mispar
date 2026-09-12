-- Mispar — esquema base.
--
-- Duas regras guiam este arquivo:
--   1. A agenda nao pode ter dois clientes no mesmo horario. Isso e garantido
--      pelo banco, nao pelo app: o bot e o celular do Marcos escrevem ao mesmo
--      tempo e nenhum "check antes do insert" resolve corrida.
--   2. Preco e duracao ficam gravados no agendamento. Se o Marcos subir o preco
--      do corte amanha, o que ja passou continua valendo o que foi cobrado.

-- ---------------------------------------------------------------- servicos --

create table services (
  id               text primary key,
  name             text    not null,
  duration_minutes integer not null check (duration_minutes between 5 and 480),
  price_cents      integer not null check (price_cents >= 0),
  requires_deposit boolean not null default false,
  active           boolean not null default true
);

comment on column services.price_cents is
  'Centavos. Dinheiro nunca em ponto flutuante.';

-- ---------------------------------------------------------------- clientes --

create table clients (
  id         uuid primary key default gen_random_uuid(),
  -- O telefone e a identidade: e por ele que a pessoa chega no WhatsApp.
  phone      text        not null unique check (phone ~ '^\+[1-9][0-9]{7,14}$'),
  name       text        not null check (length(btrim(name)) > 0),
  -- "Maquina 2 nas laterais, tesoura em cima."
  note       text,
  created_at timestamptz not null default now()
);

-- --------------------------------------------------------- funcionamento --

create table shop_hours (
  -- 1 = segunda ... 7 = domingo (isodow)
  weekday     integer primary key check (weekday between 1 and 7),
  is_open     boolean not null default true,
  opens_at    time    not null,
  closes_at   time    not null,
  lunch_start time,
  lunch_end   time,
  check (closes_at > opens_at),
  check ((lunch_start is null) = (lunch_end is null)),
  check (lunch_end is null or lunch_end > lunch_start)
);

-- Fechamento pontual: medico, feriado, viagem.
create table time_blocks (
  id        uuid primary key default gen_random_uuid(),
  starts_at timestamptz not null,
  ends_at   timestamptz not null,
  reason    text,
  check (ends_at > starts_at)
);

create index time_blocks_range_idx on time_blocks using gist (
  tstzrange(starts_at, ends_at, '[)')
);

-- ------------------------------------------------------------ agendamentos --

create type appointment_status as enum (
  'awaiting',      -- marcado, sem resposta ainda
  'confirmed',     -- respondeu confirmando
  'deposit_paid',  -- pagou sinal
  'done',          -- atendido
  'no_show',       -- nao apareceu
  'cancelled'      -- desmarcado a tempo
);

create table appointments (
  id               uuid primary key default gen_random_uuid(),
  client_id        uuid    not null references clients(id)  on delete restrict,
  service_id       text    not null references services(id) on delete restrict,
  starts_at        timestamptz not null,
  -- Copia do servico no momento da marcacao, de proposito.
  duration_minutes integer not null check (duration_minutes between 5 and 480),
  price_cents      integer not null check (price_cents >= 0),
  status           appointment_status not null default 'awaiting',
  created_at       timestamptz not null default now(),

  -- Preenchido pelo gatilho abaixo. Nao e coluna gerada porque
  -- `timestamptz + interval` nao e imutavel no Postgres — depende do fuso.
  ends_at          timestamptz not null,
  check (ends_at > starts_at)
);

-- Quem grava informa inicio e duracao; o fim e conta do banco.
create or replace function set_appointment_end()
returns trigger
language plpgsql
as $$
begin
  new.ends_at := new.starts_at + make_interval(mins => new.duration_minutes);
  return new;
end;
$$;

create trigger appointments_set_end
  before insert or update of starts_at, duration_minutes on appointments
  for each row execute function set_appointment_end();

-- O coracao da agenda: duas pessoas nao ocupam a mesma cadeira.
-- Desmarcado e falta liberam o horario; o resto trava.
alter table appointments
  add constraint appointments_no_overlap
  exclude using gist (tstzrange(starts_at, ends_at, '[)') with &&)
  where (status not in ('cancelled', 'no_show'));

create index appointments_starts_at_idx on appointments (starts_at);
create index appointments_client_idx    on appointments (client_id, starts_at desc);

-- ------------------------------------------------------ conversa do robo --

-- Onde cada telefone parou na conversa. Some sozinho depois de um tempo.
create table conversations (
  phone      text primary key,
  state      jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------------- RLS --

-- Ninguem anonimo le nada. O app do Marcos entra autenticado; o robo usa a
-- serviceRole, que passa por cima da RLS e nunca sai do servidor.
alter table services      enable row level security;
alter table clients       enable row level security;
alter table shop_hours    enable row level security;
alter table time_blocks   enable row level security;
alter table appointments  enable row level security;
alter table conversations enable row level security;

create policy staff_reads_services  on services      for select to authenticated using (true);
create policy staff_writes_services on services      for all    to authenticated using (true) with check (true);
create policy staff_clients         on clients       for all    to authenticated using (true) with check (true);
create policy staff_hours           on shop_hours    for all    to authenticated using (true) with check (true);
create policy staff_blocks          on time_blocks   for all    to authenticated using (true) with check (true);
create policy staff_appointments    on appointments  for all    to authenticated using (true) with check (true);

-- `conversations` fica sem policy de propósito: so a serviceRole toca nela.
