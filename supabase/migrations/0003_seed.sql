-- Dados que a loja precisa para funcionar no primeiro dia.
--
-- Servicos e horario de funcionamento nao sao exemplo: sao a configuracao real
-- da Marcos Barber. Confira os precos antes de aplicar.

insert into services (id, name, duration_minutes, price_cents, requires_deposit) values
  ('pezinho',     'Pezinho',       15,   1500, false),
  ('barba',       'Barba',         30,   3000, false),
  ('corte',       'Corte',         30,   4000, false),
  ('degrade',     'Degradê',       45,   4500, false),
  ('corte-barba', 'Corte + Barba', 50,   6000, false),
  ('platinado',   'Platinado',     90,  12000, true)
on conflict (id) do nothing;

-- Segunda a sexta com almoco; sabado direto; domingo fechado.
insert into shop_hours (weekday, is_open, opens_at, closes_at, lunch_start, lunch_end) values
  (1, true,  '09:00', '19:00', '12:10', '13:30'),
  (2, true,  '09:00', '19:00', '12:10', '13:30'),
  (3, true,  '09:00', '19:00', '12:10', '13:30'),
  (4, true,  '09:00', '19:00', '12:10', '13:30'),
  (5, true,  '09:00', '20:00', '12:10', '13:30'),
  (6, true,  '08:00', '18:00', null,    null),
  (7, false, '09:00', '19:00', null,    null)
on conflict (weekday) do nothing;
