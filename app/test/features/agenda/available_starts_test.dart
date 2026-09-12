import 'package:flutter_test/flutter_test.dart';
import 'package:mispar/src/features/agenda/domain/appointment.dart';
import 'package:mispar/src/features/agenda/domain/appointment_status.dart';
import 'package:mispar/src/features/agenda/domain/day_schedule.dart';
import 'package:mispar/src/features/agenda/domain/shop_hours.dart';
import 'package:mispar/src/features/clients/domain/client.dart';
import 'package:mispar/src/features/services/domain/service.dart';

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
  final day = DateTime(2027, 3, 11);
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2027, 3, 11, hour, minute);

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

  test('dia vazio oferece de 15 em 15 a partir da abertura', () {
    final starts = availableStarts(
      buildDaySchedule(day, const [], hours: hours),
      const Duration(minutes: 30),
    );

    expect(starts.first, at(9));
    expect(starts[1], at(9, 15));
    expect(starts[2], at(9, 30));
  });

  test('o ultimo horario cabe inteiro antes de fechar', () {
    final starts = availableStarts(
      buildDaySchedule(day, const [], hours: hours),
      const Duration(minutes: 30),
    );

    // Fecha as 19h; um corte de 30min nao pode comecar as 18:45.
    expect(starts.last, at(18, 30));
    for (final start in starts) {
      expect(start.add(const Duration(minutes: 30)).isAfter(at(19)), isFalse);
    }
  });

  test('servico longo tem menos opcoes que servico curto', () {
    final schedule = buildDaySchedule(day, [
      booking('a', at(10), 60),
    ], hours: hours);

    final curto = availableStarts(schedule, const Duration(minutes: 15));
    final longo = availableStarts(schedule, const Duration(minutes: 90));

    expect(curto.length, greaterThan(longo.length));
  });

  test('nao oferece horario que invade o que ja esta marcado', () {
    final schedule = buildDaySchedule(day, [
      booking('a', at(14), 60),
    ], hours: hours);
    final starts = availableStarts(schedule, const Duration(minutes: 30));

    for (final start in starts) {
      final ends = start.add(const Duration(minutes: 30));
      final invade = start.isBefore(at(15)) && ends.isAfter(at(14));
      expect(invade, isFalse, reason: 'ofereceu $start em cima do horario');
    }
  });

  test('nao oferece durante o almoco', () {
    final starts = availableStarts(
      buildDaySchedule(day, const [], hours: hours),
      const Duration(minutes: 30),
    );

    for (final start in starts) {
      final ends = start.add(const Duration(minutes: 30));
      final noAlmoco = start.isBefore(at(13, 30)) && ends.isAfter(at(12, 10));
      expect(noAlmoco, isFalse, reason: 'ofereceu $start no almoco');
    }
  });

  test('notBefore corta o que ja passou', () {
    final starts = availableStarts(
      buildDaySchedule(day, const [], hours: hours),
      const Duration(minutes: 30),
      notBefore: at(15),
    );

    expect(starts.first.isAfter(at(15)), isTrue);
    expect(starts.any((s) => s.isBefore(at(15))), isFalse);
  });

  test('dia lotado nao oferece nada', () {
    // Um platinado de 9h as 12h10 e outro de 13h30 as 19h enchem o dia.
    final schedule = buildDaySchedule(day, [
      booking('a', at(9), 190),
      booking('b', at(13, 30), 330),
    ], hours: hours);

    expect(availableStarts(schedule, const Duration(minutes: 15)), isEmpty);
  });
}
