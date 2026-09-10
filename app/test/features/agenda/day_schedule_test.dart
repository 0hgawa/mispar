import 'package:flutter_test/flutter_test.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment_status.dart';
import 'package:marcos_barber/src/features/agenda/domain/day_schedule.dart';
import 'package:marcos_barber/src/features/agenda/domain/day_slot.dart';
import 'package:marcos_barber/src/features/agenda/domain/shop_hours.dart';
import 'package:marcos_barber/src/features/clients/domain/client.dart';
import 'package:marcos_barber/src/features/services/domain/service.dart';

void main() {
  // Horario de uma quinta-feira: 9h as 19h com almoco de 12:10 as 13:30.
  const hours = DayHours(
    weekday: DateTime.thursday,
    isOpen: true,
    opensAt: Duration(hours: 9),
    closesAt: Duration(hours: 19),
    lunchStart: Duration(hours: 12, minutes: 10),
    lunchEnd: Duration(hours: 13, minutes: 30),
  );

  // Domingo: a barbearia nao abre.
  const fechado = DayHours.closed(DateTime.sunday);
  final day = DateTime(2026, 9, 10);
  DateTime at(int hour, int minute) => DateTime(2026, 9, 10, hour, minute);

  Appointment booking(String id, DateTime start, int minutes) => Appointment(
    id: id,
    startsAt: start,
    status: AppointmentStatus.confirmed,
    duration: Duration(minutes: minutes),
    priceCents: 4000,
    client: const Client(id: 'c', name: 'Rafael Lima', phone: '11 98812-4471'),
    service: Service(
      id: 's',
      name: 'Corte',
      duration: Duration(minutes: minutes),
      priceCents: 4000,
      requiresDeposit: false,
    ),
  );

  List<FreeSlot> freeSlotsOf(List<DaySlot> slots) =>
      slots.whereType<FreeSlot>().toList();

  test('dia sem nada marcado vira uma vaga antes e outra depois do almoco', () {
    final slots = buildDaySchedule(day, const [], hours: hours);
    final free = freeSlotsOf(slots);

    expect(free, hasLength(2));
    expect(free.first.start, at(9, 0));
    expect(free.first.end, at(12, 10));
    expect(free.last.start, at(13, 30));
    expect(free.last.end, at(19, 0));
  });

  test('o buraco entre dois horarios vira vaga', () {
    final slots = buildDaySchedule(day, [
      booking('a', at(9, 0), 50),
      booking('b', at(11, 40), 30),
    ], hours: hours);

    final gap = freeSlotsOf(slots).firstWhere((s) => s.start == at(9, 50));
    expect(gap.end, at(11, 40));
    expect(slots.whereType<BookedSlot>(), hasLength(2));
  });

  test('horarios colados nao geram vaga entre eles', () {
    final slots = buildDaySchedule(day, [
      booking('a', at(9, 0), 30),
      booking('b', at(9, 30), 30),
    ], hours: hours);

    expect(freeSlotsOf(slots).any((s) => s.start == at(9, 30)), isFalse);
  });

  test('vaga menor que 15 minutos nao aparece: nao cabe nem um pezinho', () {
    final slots = buildDaySchedule(day, [
      booking('a', at(9, 0), 30),
      booking('b', at(9, 40), 30),
    ], hours: hours);

    expect(freeSlotsOf(slots).any((s) => s.start == at(9, 30)), isFalse);
  });

  test('o almoco e recortado de dentro da vaga', () {
    final slots = buildDaySchedule(day, [
      booking('a', at(9, 0), 30),
    ], hours: hours);
    final free = freeSlotsOf(slots);

    expect(
      free.any((s) => s.start == at(9, 30) && s.end == at(12, 10)),
      isTrue,
    );
    expect(
      free.any((s) => s.start == at(13, 30) && s.end == at(19, 0)),
      isTrue,
    );
    expect(
      free.any(
        (s) => s.start.isAfter(at(12, 10)) && s.start.isBefore(at(13, 30)),
      ),
      isFalse,
    );
  });

  test('domingo nao tem vaga nenhuma', () {
    // A barbearia nao abre. Sem esta regra o app ofereceria horario e deixaria
    // marcar num dia fechado.
    final domingo = DateTime(2026, 9, 13);
    final slots = buildDaySchedule(domingo, const [], hours: fechado);

    expect(slots, isEmpty);
  });

  test('horario que sobrou num domingo continua aparecendo', () {
    // Se o Marcos abriu excepcionalmente, o que esta marcado nao pode sumir.
    final domingo = DateTime(2026, 9, 13);
    final atendimento = booking('a', DateTime(2026, 9, 13, 10), 30);
    final slots = buildDaySchedule(domingo, [atendimento], hours: fechado);

    expect(slots.whereType<BookedSlot>(), hasLength(1));
    expect(freeSlotsOf(slots), isEmpty);
  });

  test('a grade sai em ordem de horario', () {
    final slots = buildDaySchedule(day, [
      booking('a', at(9, 0), 50),
      booking('b', at(14, 30), 90),
      booking('c', at(16, 30), 15),
    ], hours: hours);

    for (var i = 1; i < slots.length; i++) {
      expect(slots[i].start.isAfter(slots[i - 1].start), isTrue);
    }
  });
}
