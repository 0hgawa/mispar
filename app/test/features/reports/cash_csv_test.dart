import 'package:flutter_test/flutter_test.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment_status.dart';
import 'package:marcos_barber/src/features/agenda/domain/payment_method.dart';
import 'package:marcos_barber/src/features/clients/domain/client.dart';
import 'package:marcos_barber/src/features/reports/domain/cash_csv.dart';
import 'package:marcos_barber/src/features/reports/domain/expense.dart';
import 'package:marcos_barber/src/features/services/domain/service.dart';

Appointment _appointment({
  required DateTime startsAt,
  required int priceCents,
  String clientName = 'Rafael Lima',
  String serviceName = 'Corte',
  PaymentMethod? paidWith,
}) {
  return Appointment(
    id: 'a',
    startsAt: startsAt,
    status: AppointmentStatus.done,
    duration: const Duration(minutes: 30),
    priceCents: priceCents,
    paidWith: paidWith,
    client: Client(id: 'c', name: clientName, phone: '11999999999'),
    service: Service(
      id: 's',
      name: serviceName,
      duration: const Duration(minutes: 30),
      priceCents: priceCents,
      requiresDeposit: false,
    ),
  );
}

Expense _expense({
  required DateTime spentAt,
  required int cents,
  String category = 'Aluguel',
  String? note,
}) {
  return Expense(
    id: 'e',
    spentAt: spentAt,
    category: ExpenseCategory(id: 'rent', name: category),
    cents: cents,
    note: note,
  );
}

void main() {
  group('cashCsv', () {
    test('junta entradas e saidas em ordem de data', () {
      final csv = cashCsv(
        earned: [
          _appointment(startsAt: DateTime(2026, 9, 10, 9), priceCents: 4000),
        ],
        spent: [_expense(spentAt: DateTime(2026, 9, 5), cents: 80000)],
      );

      final lines = csv.split('\n');
      expect(lines.first, 'Data;Tipo;O quê;Cliente;Detalhe;Valor');
      // O gasto do dia 5 vem antes do atendimento do dia 10.
      expect(lines[1], startsWith('05/09/2026;Saída;'));
      expect(lines[2], startsWith('10/09/2026;Entrada;'));
    });

    test('saida sai negativa para a coluna somar o que sobrou', () {
      final csv = cashCsv(
        earned: const [],
        spent: [_expense(spentAt: DateTime(2026, 9, 5), cents: 80000)],
      );

      expect(csv.split('\n')[1], endsWith(';-800,00'));
    });

    test('valor usa virgula decimal, como o Excel em portugues espera', () {
      final csv = cashCsv(
        earned: [
          _appointment(startsAt: DateTime(2026, 9, 10), priceCents: 4550),
        ],
        spent: const [],
      );

      expect(csv.split('\n')[1], endsWith(';45,50'));
    });

    test('anota a forma de pagamento quando existe', () {
      final csv = cashCsv(
        earned: [
          _appointment(
            startsAt: DateTime(2026, 9, 10),
            priceCents: 4000,
            paidWith: PaymentMethod.pix,
          ),
        ],
        spent: const [],
      );

      expect(csv, contains(';Pix;'));
    });

    test('ponto e virgula na anotacao nao quebra a coluna', () {
      final csv = cashCsv(
        earned: const [],
        spent: [
          _expense(
            spentAt: DateTime(2026, 9, 5),
            cents: 5000,
            note: 'pomada; talco',
          ),
        ],
      );

      expect(csv, contains('"pomada; talco"'));
      expect(csv.split('\n')[1].split(';').length, 7);
    });

    test('sem movimento sobra so o cabecalho', () {
      expect(
        cashCsv(earned: const [], spent: const []),
        'Data;Tipo;O quê;Cliente;Detalhe;Valor',
      );
    });
  });
}
