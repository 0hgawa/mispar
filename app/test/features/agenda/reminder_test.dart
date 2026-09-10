import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment_status.dart';
import 'package:marcos_barber/src/features/agenda/domain/reminder.dart';
import 'package:marcos_barber/src/features/clients/domain/client.dart';
import 'package:marcos_barber/src/features/services/domain/service.dart';
import 'package:marcos_barber/src/shared/whatsapp.dart';

Appointment _appointment({
  required DateTime startsAt,
  String clientName = 'Rafael Lima',
  String serviceName = 'Corte + Barba',
}) {
  return Appointment(
    id: 'a',
    startsAt: startsAt,
    status: AppointmentStatus.confirmed,
    duration: const Duration(minutes: 50),
    priceCents: 6000,
    client: Client(id: 'c', name: clientName, phone: '11999999999'),
    service: Service(
      id: 's',
      name: serviceName,
      duration: const Duration(minutes: 50),
      priceCents: 6000,
      requiresDeposit: false,
    ),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('whenInWords', () {
    final now = DateTime(2026, 9, 10, 8);

    test('hoje', () {
      expect(
        whenInWords(DateTime(2026, 9, 10, 14, 30), now: now),
        'hoje às 14:30',
      );
    });

    test('amanha', () {
      expect(
        whenInWords(DateTime(2026, 9, 11, 9), now: now),
        'amanhã às 09:00',
      );
    });

    test('depois disso vai com data, que nao deixa duvida', () {
      expect(
        whenInWords(DateTime(2026, 9, 14, 9), now: now),
        'seg, 14/09 às 09:00',
      );
    });

    test('a hora do dia nao muda o "hoje"', () {
      // 23h de hoje ainda e hoje, mesmo faltando uma hora para virar.
      expect(
        whenInWords(DateTime(2026, 9, 10, 23), now: DateTime(2026, 9, 10, 22)),
        'hoje às 23:00',
      );
    });
  });

  group('reminderMessage', () {
    test('chama pelo primeiro nome e diz quando e o quê', () {
      final message = reminderMessage(
        _appointment(startsAt: DateTime(2026, 9, 11, 10)),
        now: DateTime(2026, 9, 10, 8),
      );

      expect(
        message,
        'Oi, Rafael! Passando para confirmar seu horário amanhã às 10:00 — '
        'Corte + Barba. Tudo certo?',
      );
    });

    test('nome sem sobrenome nao quebra', () {
      final message = reminderMessage(
        _appointment(startsAt: DateTime(2026, 9, 10, 10), clientName: 'Ney'),
        now: DateTime(2026, 9, 10, 8),
      );

      expect(message, startsWith('Oi, Ney!'));
    });
  });

  group('firstName', () {
    test('corta no primeiro espaço', () {
      expect(firstName('Douglas Prates'), 'Douglas');
      expect(firstName('  Wesley  '), 'Wesley');
      expect(firstName('Ney'), 'Ney');
    });
  });
}
