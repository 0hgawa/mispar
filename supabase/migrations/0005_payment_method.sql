-- Como o cliente pagou.
--
-- Sem isto nao da para conferir a maquininha contra o que o dia rendeu: o
-- extrato do cartao chega dois dias depois e ninguem lembra qual corte foi no
-- Pix. Espelha a coluna `payment_method` do SQLite do app (schema v7).

-- Texto, e nao enum, pelo mesmo motivo do status: acrescentar uma forma de
-- pagamento nao deve pedir migracao dos dois lados no mesmo dia.
alter table appointments
  add column if not exists payment_method text;

-- Só faz sentido em atendimento concluido. Marcado nao foi pago ainda, e
-- falta nao foi paga nunca.
alter table appointments
  drop constraint if exists appointments_payment_only_when_done;
alter table appointments
  add constraint appointments_payment_only_when_done
  check (payment_method is null or status = 'done');
