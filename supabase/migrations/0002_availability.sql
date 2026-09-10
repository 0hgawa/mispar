-- Disponibilidade e marcacao.
--
-- Estas duas funcoes existem para o robo do WhatsApp ser burro: ele nao calcula
-- horario nem checa conflito, so pergunta e grava. Toda a regra mora aqui,
-- junto dos dados, onde nao da para dar corrida.

-- Horarios livres para um servico num dia.
--
-- Passo de 15 minutos: o Marcos encaixa pezinho em qualquer brecha, mas
-- oferecer de minuto em minuto viraria uma lista impossivel de ler no WhatsApp.
create or replace function public.available_slots(
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
  c_timezone constant text     := 'America/Sao_Paulo';
  c_step     constant interval := interval '15 minutes';

  v_duration interval;
  v_hours    shop_hours%rowtype;
  v_opens    timestamptz;
  v_closes   timestamptz;
  v_lunch    tstzrange;
begin
  select make_interval(mins => s.duration_minutes)
    into v_duration
    from services s
   where s.id = p_service_id
     and s.active;

  if not found then
    return;
  end if;

  select *
    into v_hours
    from shop_hours h
   where h.weekday = extract(isodow from p_day)::integer;

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
    select generate_series(v_opens, v_closes - v_duration, c_step) as begins_at
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
        where a.status not in ('cancelled', 'no_show')
          and tstzrange(a.starts_at, a.ends_at, '[)') && slot.span
     )
     and not exists (
       select 1
         from time_blocks b
        where tstzrange(b.starts_at, b.ends_at, '[)') && slot.span
     )
   order by slot.begins_at;
end;
$$;

-- Marca o horario e cadastra o cliente na mesma transacao.
--
-- Se dois clientes pedirem o mesmo horario no mesmo instante, um dos dois bate
-- na constraint de sobreposicao e recebe `HORARIO_OCUPADO` — nunca os dois
-- entram. E por isso que a checagem nao fica no robo.
create or replace function public.book_appointment(
  p_phone      text,
  p_name       text,
  p_service_id text,
  p_starts_at  timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client_id      uuid;
  v_duration       integer;
  v_price          integer;
  v_needs_deposit  boolean;
  v_appointment_id uuid;
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

-- Desmarca. Devolve falso se o horario nao era daquele telefone: ninguem
-- cancela o corte do vizinho.
create or replace function public.cancel_appointment(
  p_phone          text,
  p_appointment_id uuid
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
