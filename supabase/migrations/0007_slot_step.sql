-- O passo dos horarios virou ajuste.
--
-- Estava escrito duas vezes: `interval '15 minutes'` na 0002 e uma constante
-- no Dart. Duas copias da mesma regra e a receita para o app oferecer 10:05 e
-- o robo oferecer 10:00 no mesmo dia. Agora mora no banco, e os dois leem
-- daqui.
--
-- Espelha a tabela `shop_settings` do SQLite do app (schema v10).

create table if not exists shop_settings (
  -- Uma linha so: o id travado em 1 impede uma segunda.
  id                integer primary key default 1 check (id = 1),
  slot_step_minutes integer not null default 15
    check (slot_step_minutes between 5 and 60)
);

insert into shop_settings (id) values (1) on conflict (id) do nothing;

alter table shop_settings enable row level security;

-- O robo le para oferecer horario; so o dono muda.
drop policy if exists shop_settings_read on shop_settings;
create policy shop_settings_read on shop_settings
  for select
  to anon, authenticated
  using (true);

drop policy if exists shop_settings_owner_write on shop_settings;
create policy shop_settings_owner_write on shop_settings
  for all
  to authenticated
  using (true)
  with check (true);

-- ------------------------------------------------------------------------

-- A mesma funcao da 0002, palavra por palavra. So o passo mudou de lugar.
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
  c_timezone constant text := 'America/Sao_Paulo';

  -- O passo agora sai da tabela. Sem linha de ajuste, cai no mesmo 15 de
  -- sempre: a agenda nao pode parar de oferecer horario por falta de
  -- configuracao.
  v_step     interval;
  v_duration interval;
  v_hours    shop_hours%rowtype;
  v_opens    timestamptz;
  v_closes   timestamptz;
  v_lunch    tstzrange;
begin
  select make_interval(mins => coalesce(min(s.slot_step_minutes), 15))
    into v_step
    from shop_settings s;

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
