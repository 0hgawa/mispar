import 'package:flutter_test/flutter_test.dart';
import 'package:marcos_barber/src/features/clients/domain/client.dart';
import 'package:marcos_barber/src/features/clients/domain/client_summary.dart';
import 'package:marcos_barber/src/shared/formatters/text.dart';

void main() {
  const client = Client(id: 'c', name: 'Rafael Lima', phone: '+5511988124471');

  ClientSummary summary({
    int visits = 3,
    int spent = 18000,
    DateTime? lastVisit,
  }) => ClientSummary(
    client: client,
    visitCount: visits,
    spentCents: spent,
    lastVisit: lastVisit,
  );

  group('busca', () {
    test('acha com acento quando digitou sem', () {
      expect(normalizeForSearch('Jônatas'), 'jonatas');
      expect(normalizeForSearch('AÇÃO'), 'acao');
      expect(normalizeForSearch('  Wesley  '), '  wesley  '.toLowerCase());
    });

    test('telefone casa independente da pontuacao', () {
      expect(digitsOf('11 98812-4471'), '11988124471');
      expect(digitsOf('+55 (11) 98812 4471'), '5511988124471');
      expect(digitsOf('sem numero'), '');
    });
  });

  group('resumo do cliente', () {
    test('quem nunca veio e novo, e o ticket medio nao divide por zero', () {
      final novo = summary(visits: 0, spent: 0);
      expect(novo.isNew, isTrue);
      expect(novo.averageTicketCents, 0);
    });

    test('ticket medio e o gasto dividido pelas visitas', () {
      expect(summary(visits: 4, spent: 24000).averageTicketCents, 6000);
    });

    test('sumiu depois de 45 dias sem aparecer', () {
      final antigo = DateTime.now().subtract(const Duration(days: 60));
      expect(summary(lastVisit: antigo).hasDrifted, isTrue);
    });

    test('quem veio semana passada nao sumiu', () {
      final recente = DateTime.now().subtract(const Duration(days: 7));
      expect(summary(lastVisit: recente).hasDrifted, isFalse);
    });

    test('quem nunca veio nao conta como sumido', () {
      // Cliente novo ainda nao teve chance de sumir — marcar em vermelho
      // seria mentira.
      expect(summary(visits: 0, spent: 0).hasDrifted, isFalse);
    });

    test('exatamente 45 dias ainda nao e sumico', () {
      final limite = DateTime.now().subtract(const Duration(days: 45));
      expect(summary(lastVisit: limite).hasDrifted, isFalse);
    });
  });
}
