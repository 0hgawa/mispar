import 'package:flutter_test/flutter_test.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment_status.dart';
import 'package:marcos_barber/src/features/clients/domain/client.dart';
import 'package:marcos_barber/src/features/services/domain/service.dart';
import 'package:marcos_barber/src/features/settings/domain/reminder_settings.dart';

Appointment _appointment({
  required AppointmentStatus status,
  bool withClient = true,
}) {
  return Appointment(
    id: 'a',
    startsAt: DateTime(2026, 9, 12, 14),
    status: status,
    duration: const Duration(minutes: 30),
    priceCents: 4000,
    client: withClient
        ? const Client(id: 'c', name: 'Rafael Lima', phone: '11999999999')
        : null,
    service: const Service(
      id: 's',
      name: 'Corte',
      duration: Duration(minutes: 30),
      priceCents: 4000,
      requiresDeposit: false,
    ),
  );
}

void main() {
  group('quem gera lembrete', () {
    test('horario marcado com cliente gera', () {
      final agenda = [_appointment(status: AppointmentStatus.awaiting)];

      expect(remindersFor(agenda), 1);
    });

    test('venda de balcao nao gera: nao ha para quem mandar', () {
      final agenda = [
        _appointment(status: AppointmentStatus.done, withClient: false),
      ];

      expect(remindersFor(agenda), 0);
    });

    test('desmarcado e falta nao geram', () {
      final agenda = [
        _appointment(status: AppointmentStatus.cancelled),
        _appointment(status: AppointmentStatus.noShow),
      ];

      expect(remindersFor(agenda), 0);
    });

    test('o que ja foi atendido nao gera', () {
      final agenda = [_appointment(status: AppointmentStatus.done)];

      expect(remindersFor(agenda), 0);
    });

    test('conta so o que sobrou', () {
      final agenda = [
        _appointment(status: AppointmentStatus.awaiting),
        _appointment(status: AppointmentStatus.confirmed),
        _appointment(status: AppointmentStatus.depositPaid),
        _appointment(status: AppointmentStatus.cancelled),
      ];

      expect(remindersFor(agenda), 3);
    });
  });

  test('o lembrete nasce desligado, com 24 horas', () {
    const reminder = ReminderSettings.off();

    expect(reminder.isOn, isFalse);
    expect(reminder.hoursBefore, 24);
  });
}
