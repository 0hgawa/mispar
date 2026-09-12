import 'package:flutter_test/flutter_test.dart';
import 'package:mispar/src/features/agenda/domain/appointment_status.dart';

void main() {
  test('cada situacao tem um nome de banco unico', () {
    final names = AppointmentStatus.values.map((s) => s.wireName).toSet();
    expect(names, hasLength(AppointmentStatus.values.length));
  });

  test('o nome de banco e snake_case, como o enum do Postgres', () {
    for (final status in AppointmentStatus.values) {
      expect(
        status.wireName,
        matches(RegExp(r'^[a-z]+(_[a-z]+)*$')),
        reason: '${status.name} virou "${status.wireName}"',
      );
    }
  });

  test('fromWire desfaz o que wireName faz', () {
    for (final status in AppointmentStatus.values) {
      expect(AppointmentStatus.fromWire(status.wireName), status);
    }
  });

  test('fromWire recusa valor desconhecido em vez de escolher um', () {
    // Situacao nova no servidor tem que estourar aqui, nao virar "confirmado"
    // sem ninguem perceber.
    expect(() => AppointmentStatus.fromWire('reagendado'), throwsArgumentError);
    expect(
      () => AppointmentStatus.fromWire('depositPaid'),
      throwsArgumentError,
    );
  });

  test('desmarcado e falta nao ficam de pe; o resto fica', () {
    expect(AppointmentStatus.cancelled.stillStands, isFalse);
    expect(AppointmentStatus.noShow.stillStands, isFalse);

    expect(AppointmentStatus.awaiting.stillStands, isTrue);
    expect(AppointmentStatus.confirmed.stillStands, isTrue);
    expect(AppointmentStatus.depositPaid.stillStands, isTrue);
    expect(AppointmentStatus.done.stillStands, isTrue);
  });
}
