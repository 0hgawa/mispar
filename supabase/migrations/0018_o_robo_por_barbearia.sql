-- As funcoes do robo passam a perguntar de qual barbearia se trata.
--
-- Elas nasceram quando havia uma so, entao liam `services`, `shop_hours` e
-- `appointments` como se fossem do mundo. Depois da 0017 isso e pior que
-- errado: elas rodam como `security definer`, quer dizer, **por cima da RLS**.
-- Sem dizer o dono, o robo de uma barbearia marcaria horario na agenda de
-- outra.
--
-- O dono entra como primeiro parametro. Quem passa e a edge function, que
-- descobre de quem e pelo numero de WhatsApp que recebeu a mensagem.

-- ------------------------------------------------------------ os horarios

drop function if exists public.available_slots(date, text);

create function public.available_slots(
  p_owner      uuid,
  p_day        date,
  p_service_id text
)
returns table (starts_at timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  c_timezone constant text := 'America/Sao_Paulo';

  v_step     interval;
  v_duration interval;
  v_hours    shop_hours%rowtype;
  v_opens    timestamptz;
  v_closes   timestamptz;
  v_lunch    tstzrange;
begin
  -- O passo da grade e ajuste de cada barbearia, e nao constante do codigo:
  -- foi assim desde a 0007, e recriar a funcao a partir da 0002 tinha jogado
  -- isso fora. Quem pegou foi o teste.
  select make_interval(mins => coalesce(s.slot_step_minutes, 15))
    into v_step
    from shop_settings s
   where s.owner_id = p_owner;

  v_step := coalesce(v_step, interval '15 minutes');

  select make_interval(mins => s.duration_minutes)
    into v_duration
    from services s
   where s.owner_id = p_owner
     and s.id = p_service_id
     and s.active;

  if not found then
    return;
  end if;

  select *
    into v_hours
    from shop_hours h
   where h.owner_id = p_owner
     and h.weekday = extract(isodow from p_day)::integer;

  if not found or not v_hours.is_open then
    return;
  end if;

  v_opens  := (p_day + v_hours.opens_at)  at time zone c_timezone;
  v_closes := (p_day + v_hours.closes_at) at time zone c_timezone;

  v_lunch := case
    when v_hours.lunch_start is null then 'empty'::tstzrange
    else tstzrange(
      (p_day + v_hours.lunch_start) at time zone c_timezone,
      (p_day + v_hours.lunch_end)   at time zone c_timezone,
      '[)'
    )
  end;

  return query
  with candidate as (
    select generate_series(v_opens, v_closes - v_duration, v_step) as begins_at
  ),
  slot as (
    select
      c.begins_at,
      tstzrange(c.begins_at, c.begins_at + v_duration, '[)') as span
    from candidate c
  )
  select slot.begins_at
    from slot
   where slot.begins_at > now()
     and not (slot.span && v_lunch)
     and not exists (
       select 1
         from appointments a
        where a.owner_id = p_owner
          and a.status not in ('cancelled', 'no_show')
          and not a.walk_in
          and tstzrange(a.starts_at, a.ends_at, '[)') && slot.span
     )
     and not exists (
       select 1
         from time_blocks b
        where b.owner_id = p_owner
          and tstzrange(b.starts_at, b.ends_at, '[)') && slot.span
     )
   order by slot.begins_at;
end;
$$;

-- --------------------------------------------------------------- marcar

drop function if exists public.book_appointment(text, text, text, timestamptz);

create function public.book_appointment(
  p_owner      uuid,
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
   where s.owner_id = p_owner
     and s.id = p_service_id
     and s.active;

  if not found then
    raise exception 'SERVICO_INEXISTENTE' using errcode = 'P0002';
  end if;

  -- O telefone identifica o cliente dentro da barbearia, e nao no mundo: a
  -- mesma pessoa corta em duas e tem uma ficha em cada.
  insert into clients (owner_id, phone, name)
       values (p_owner, p_phone, p_name)
  on conflict (owner_id, phone) do update
          -- Nao sobrescreve o nome que o barbeiro ja corrigiu na mao.
          set name = clients.name
    returning id into v_client_id;

  begin
    insert into appointments (
      owner_id, client_id, service_id, starts_at,
      duration_minutes, price_cents, status
    )
    values (
      p_owner,
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

-- ------------------------------------------------------ desmarcar e confirmar

drop function if exists public.cancel_appointment(text, text);

create function public.cancel_appointment(
  p_owner          uuid,
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
   where a.owner_id = p_owner
     and a.id = p_appointment_id
     and c.owner_id = a.owner_id
     and a.client_id = c.id
     and c.phone = p_phone
     and a.status not in ('done', 'cancelled')
  returning true;
$$;

drop function if exists public.confirm_appointment(text, text);

create function public.confirm_appointment(
  p_owner          uuid,
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
   where a.owner_id = p_owner
     and a.id = p_appointment_id
     and c.owner_id = a.owner_id
     and a.client_id = c.id
     and c.phone = p_phone
     and a.status not in ('cancelled', 'no_show', 'done')
  returning true;
$$;

-- --------------------------------------------------------------- lembretes

drop function if exists public.due_reminders();

-- Devolve o dono junto: a varredura roda para todas as barbearias de uma vez,
-- e e o dono que diz por qual numero de WhatsApp aquela mensagem tem que sair.
create function public.due_reminders()
returns table (
  owner_id     uuid,
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
  select a.owner_id, a.id, c.phone, c.name, s.name, a.starts_at
    from appointments a
    join clients  c on c.owner_id = a.owner_id and c.id = a.client_id
    join services s on s.owner_id = a.owner_id and s.id = a.service_id
    join shop_settings cfg on cfg.owner_id = a.owner_id
   where cfg.reminder_enabled
     and a.status not in ('cancelled', 'no_show', 'done')
     and a.reminder_sent_at is null
     and a.starts_at > now()
     and a.starts_at <= now() + make_interval(hours => cfg.reminder_hours_before)
   order by a.owner_id, a.starts_at;
$$;

-- A lista traz nome e telefone de quem marcou, de todas as barbearias. So o
-- robo, que vive dentro da edge function, pode chamar.
revoke execute on function public.due_reminders() from public, anon, authenticated;
grant   execute on function public.due_reminders() to service_role;
