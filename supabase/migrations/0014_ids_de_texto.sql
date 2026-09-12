-- Os ids passam a ser texto, como ja sao no aparelho.
--
-- O app trata id como etiqueta opaca: o servico e `corte`, o tipo de despesa e
-- `rent`, o cliente de exemplo e `rafael`. Sao legiveis de proposito — quem le
-- o banco entende sem consultar outra tabela. `services.id`,
-- `expense_categories.id` e `expenses.id` ja eram `text` aqui por isso mesmo.
--
-- Clientes, horarios e bloqueios ficaram `uuid` desde a primeira migration, e
-- so agora isso doeu: a subida do aparelho morre em
-- "invalid input syntax for type uuid: rafael", e morre **antes** de mandar os
-- clientes, os horarios e as despesas. Um backup que para na segunda tabela.
--
-- Texto nao perde nada. O robo continua criando uuid — `gen_random_uuid()`
-- vira texto no mesmo formato —, e quem gera id no celular continua gerando
-- uuid v4. O que muda e que o banco deixa de recusar uma etiqueta so porque
-- ela e legivel.

-- A chave estrangeira precisa sair antes: os dois lados mudam de tipo juntos.
alter table appointments drop constraint appointments_client_id_fkey;

alter table clients      alter column id        type text using id::text;
alter table clients      alter column id        set default gen_random_uuid()::text;

alter table appointments alter column id        type text using id::text;
alter table appointments alter column id        set default gen_random_uuid()::text;
alter table appointments alter column client_id type text using client_id::text;

alter table time_blocks  alter column id        type text using id::text;
alter table time_blocks  alter column id        set default gen_random_uuid()::text;

alter table appointments
  add constraint appointments_client_id_fkey
  foreign key (client_id) references clients (id) on delete restrict;

-- ------------------------------------------------- as funcoes que falavam uuid

drop function if exists public.book_appointment(text, text, text, timestamptz);

create function public.book_appointment(
  p_phone      text,
  p_name       text,
  p_service_id text,
  p_starts_at  timestamptz
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client_id      text;
  v_duration       integer;
  v_price          integer;
  v_needs_deposit  boolean;
  v_appointment_id text;
begin
  select s.duration_minutes, s.price_cents, s.requires_deposit
    into v_duration, v_price, v_needs_deposit
    from services s
   where s.id = p_service_id
     and s.active;

  if not found then
    raise exception 'SERVICO_INEXISTENTE' using errcode = 'P0002';
  end if;

  insert into clients (phone, name)
       values (p_phone, p_name)
  on conflict (phone) do update
          -- Nao sobrescreve o nome que o Marcos ja corrigiu na mao.
          set name = clients.name
    returning id into v_client_id;

  begin
    insert into appointments (
      client_id, service_id, starts_at, duration_minutes, price_cents, status
    )
    values (
      v_client_id,
      p_service_id,
      p_starts_at,
      v_duration,
      v_price,
      -- Servico com sinal so fica confirmado quando o dinheiro entra.
      (case when v_needs_deposit then 'awaiting' else 'confirmed' end)::appointment_status
    )
    returning id into v_appointment_id;
  exception
    when exclusion_violation then
      raise exception 'HORARIO_OCUPADO' using errcode = 'P0001';
  end;

  return v_appointment_id;
end;
$$;

drop function if exists public.cancel_appointment(text, uuid);

create function public.cancel_appointment(
  p_phone          text,
  p_appointment_id text
)
returns boolean
language sql
security definer
set search_path = public
as $$
  update appointments a
     set status = 'cancelled'
    from clients c
   where a.id = p_appointment_id
     and a.client_id = c.id
     and c.phone = p_phone
     and a.status not in ('done', 'cancelled')
  returning true;
$$;

drop function if exists public.confirm_appointment(text, uuid);

create function public.confirm_appointment(
  p_phone          text,
  p_appointment_id text
)
returns boolean
language sql
security definer
set search_path = public
as $$
  update appointments a
     set confirmed_at = now()
    from clients c
   where a.id = p_appointment_id
     and a.client_id = c.id
     and c.phone = p_phone
     and a.status not in ('cancelled', 'no_show', 'done')
  returning true;
$$;

drop function if exists public.due_reminders();

create function public.due_reminders()
returns table (
  id           text,
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
    join clients c  on c.id = a.client_id
    join services s on s.id = a.service_id
   cross join shop_settings cfg
   where cfg.reminder_enabled
     and a.status not in ('cancelled', 'no_show', 'done')
     and a.reminder_sent_at is null
     and a.starts_at > now()
     and a.starts_at <= now() + make_interval(hours => cfg.reminder_hours_before)
   order by a.starts_at;
$$;

-- A lista traz nome e telefone de quem marcou: nao e a chave do app que puxa
-- isso, e a do robo, que vive dentro da edge function.
revoke execute on function public.due_reminders() from public, anon, authenticated;
grant   execute on function public.due_reminders() to service_role;
