-- O lembrete da vespera.
--
-- E a unica mensagem que custa dinheiro: vai fora da janela de 24h, entao
-- precisa de template aprovado e e cobrada por envio. Por isso ela tem
-- interruptor, tem hora escolhida pelo dono, e tem uma trava contra enviar
-- duas vezes o mesmo lembrete — que seria pagar dois.

alter table shop_settings
  add column if not exists reminder_enabled boolean not null default false,
  add column if not exists reminder_hours_before integer not null default 24
    check (reminder_hours_before between 2 and 72);

comment on column shop_settings.reminder_enabled is
  'Desligado de fabrica: mensagem cobrada nao se liga sozinha.';

-- Quando o lembrete daquele horario saiu, e quando o cliente respondeu que vem.
--
-- Sao duas datas soltas, e nao estados novos no enum, porque nao competem com
-- ele: `status` conta a vida do atendimento (sinal, atendido, faltou) e estas
-- duas contam a conversa. Um horario pode estar esperando sinal e mesmo assim
-- ter sido confirmado pelo cliente.
alter table appointments
  add column if not exists reminder_sent_at timestamptz,
  add column if not exists confirmed_at     timestamptz;

comment on column appointments.reminder_sent_at is
  'A trava contra o envio dobrado: se a varredura rodar duas vezes, a segunda '
  'nao acha mais este horario.';

comment on column appointments.confirmed_at is
  'O cliente respondeu que vem. Nulo nao quer dizer que faltou: quer dizer '
  'que ele nao respondeu.';

-- ------------------------------------------------------------------------

-- Quem merece lembrete agora.
--
-- A regra mora aqui, e nao espalhada no codigo do robo: quem recebe uma
-- mensagem cobrada e a parte que precisa estar certa.
create or replace function public.due_reminders()
returns table (
  id           uuid,
  phone        text,
  client_name  text,
  service_name text,
  starts_at    timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select a.id, c.phone, c.name, s.name, a.starts_at
    from appointments a
    join clients  c on c.id = a.client_id
    join services s on s.id = a.service_id
   cross join shop_settings cfg
   where cfg.reminder_enabled
     -- So o que ainda vai acontecer. Desmarcado, faltou e ja atendido nao
     -- recebem aviso — e avisar de novo seria pagar para repetir.
     and a.status not in ('cancelled', 'no_show', 'done')
     and a.reminder_sent_at is null
     -- Ja entrou na janela, e ainda nao chegou a hora.
     and a.starts_at > now()
     and a.starts_at <= now() + make_interval(hours => cfg.reminder_hours_before)
   order by a.starts_at;
$$;

comment on function public.due_reminders is
  'Horarios que entraram na janela do lembrete e ainda nao foram avisados. '
  'Venda de balcao nao aparece: sem cliente, nao ha para quem mandar.';

-- O cliente respondeu ao lembrete.
--
-- Confere o telefone antes de gravar: o id do horario viaja no botao da
-- mensagem, e ninguem confirma o horario de outro.
create or replace function public.confirm_appointment(
  p_phone          text,
  p_appointment_id uuid
) returns boolean
language sql
volatile
security definer
set search_path = public
as $$
  update appointments a
     set confirmed_at = now()
    from clients c
   where a.id = p_appointment_id
     and c.id = a.client_id
     and c.phone = p_phone
     and a.status not in ('cancelled', 'no_show')
  returning true;
$$;

-- Quem pode chamar a lista.
--
-- `security definer` passa por cima da RLS, e o PostgREST publica toda funcao
-- do schema `public` para a chave do app — que viaja dentro do aparelho e nao
-- e segredo. Sem este revoke, qualquer um com a chave puxaria nome e telefone
-- de todos os clientes da semana com uma chamada sem argumento.
--
-- So a varredura precisa dela, e a varredura fala como serviceRole.
revoke execute on function public.due_reminders() from public, anon, authenticated;
grant   execute on function public.due_reminders() to service_role;
