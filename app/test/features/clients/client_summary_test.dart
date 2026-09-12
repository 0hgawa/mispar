import 'package:flutter_test/flutter_test.dart';
import 'package:mispar/src/features/clients/domain/client.dart';
import 'package:mispar/src/features/clients/domain/client_summary.dart';
import 'package:mispar/src/shared/formatters/text.dart';

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
    test('quem nunca veio nao derruba o ticket medio por divisao por zero', () {
      expect(summary(visits: 0, spent: 0).averageTicketCents, 0);
    });

    test('ticket medio e o gasto dividido pelas visitas', () {
      expect(summary(visits: 4, spent: 24000).averageTicketCents, 6000);
    });

    test('sumiu depois do prazo sem aparecer', () {
      final antigo = DateTime.now().subtract(const Duration(days: 90));
      expect(summary(lastVisit: antigo).hasDriftedAfter(60), isTrue);
    });

    test('quem veio semana passada nao sumiu', () {
      final recente = DateTime.now().subtract(const Duration(days: 7));
      expect(summary(lastVisit: recente).hasDriftedAfter(60), isFalse);
    });

    test('quem nunca veio nao conta como sumido', () {
      // Cliente novo ainda nao teve chance de sumir — marcar em vermelho
      // seria mentira.
      expect(summary(visits: 0, spent: 0).hasDriftedAfter(60), isFalse);
    });

    test('o dia do prazo ainda nao e sumico', () {
      final limite = DateTime.now().subtract(const Duration(days: 60));
      expect(summary(lastVisit: limite).hasDriftedAfter(60), isFalse);
    });

    test('quem manda e o prazo: 50 dias some com 30, nao com 60', () {
      final meio = DateTime.now().subtract(const Duration(days: 50));
      expect(summary(lastVisit: meio).hasDriftedAfter(30), isTrue);
      expect(summary(lastVisit: meio).hasDriftedAfter(60), isFalse);
    });
  });
}
