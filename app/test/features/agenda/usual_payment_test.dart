import 'package:flutter_test/flutter_test.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment_status.dart';
import 'package:marcos_barber/src/features/agenda/domain/payment_method.dart';
import 'package:marcos_barber/src/features/agenda/domain/usual_payment.dart';
import 'package:marcos_barber/src/features/services/domain/service.dart';
import 'package:marcos_barber/src/features/settings/domain/accepted_payments.dart';

Appointment _paid(PaymentMethod? method) {
  return Appointment(
    id: 'a',
    client: null,
    service: const Service(
      id: 's',
      name: 'Corte',
      duration: Duration(minutes: 30),
      priceCents: 4000,
      requiresDeposit: false,
    ),
    startsAt: DateTime(2026, 9, 11, 9),
    status: AppointmentStatus.done,
    duration: const Duration(minutes: 30),
    priceCents: 4000,
    paidWith: method,
  );
}

void main() {
  group('usualPayment', () {
    test('sem historico nao inventa padrao', () {
      expect(usualPayment(const []), isNull);
    });

    test('so atendimento sem forma anotada tambem nao inventa', () {
      expect(usualPayment([_paid(null), _paid(null)]), isNull);
    });

    test('a mais contada vence', () {
      final history = [
        _paid(PaymentMethod.pix),
        _paid(PaymentMethod.pix),
        _paid(PaymentMethod.cash),
        _paid(null),
      ];

      expect(usualPayment(history), PaymentMethod.pix);
    });

    test('empate fica com a ordem dos botoes, e nao pula de lugar', () {
      final history = [_paid(PaymentMethod.card), _paid(PaymentMethod.cash)];

      expect(usualPayment(history), PaymentMethod.cash);
    });
  });

  group('AcceptedPayments', () {
    test('de fabrica aceita as tres', () {
      expect(
        AcceptedPayments.read(AcceptedPayments.wireDefault),
        PaymentMethod.values,
      );
    });

    test('le na ordem dos botoes, nao na ordem gravada', () {
      expect(AcceptedPayments.read('card,cash'), [
        PaymentMethod.cash,
        PaymentMethod.card,
      ]);
    });

    test('nome desconhecido e ignorado em silencio', () {
      expect(AcceptedPayments.read('pix,vale'), [PaymentMethod.pix]);
    });

    test('texto vazio cai nas tres: sem forma nao ha como fechar', () {
      expect(AcceptedPayments.read(''), PaymentMethod.values);
    });

    test('ida e volta preserva a escolha', () {
      const escolhido = [PaymentMethod.cash, PaymentMethod.card];

      expect(
        AcceptedPayments.read(AcceptedPayments.write(escolhido)),
        escolhido,
      );
    });
  });
}
