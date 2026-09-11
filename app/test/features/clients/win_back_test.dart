import 'package:flutter_test/flutter_test.dart';
import 'package:marcos_barber/src/features/clients/domain/client.dart';
import 'package:marcos_barber/src/features/clients/domain/client_summary.dart';
import 'package:marcos_barber/src/features/clients/domain/win_back.dart';

ClientSummary _summary({
  required String name,
  required int daysAgo,
  int spentCents = 4000,
  bool isActive = true,
  String? usualService,
}) {
  return ClientSummary(
    client: Client(
      id: name,
      name: name,
      phone: '11988124471',
      isActive: isActive,
    ),
    visitCount: 1,
    spentCents: spentCents,
    lastVisit: DateTime.now().subtract(Duration(days: daysAgo)),
    usualService: usualService,
  );
}

void main() {
  group('winBackList', () {
    test('quem veio esta semana nao entra', () {
      final lista = winBackList([_summary(name: 'Rafael', daysAgo: 5)]);

      expect(lista, isEmpty);
    });

    test('quem passou de 45 dias entra', () {
      final lista = winBackList([_summary(name: 'Rafael', daysAgo: 60)]);

      expect(lista.single.client.name, 'Rafael');
    });

    test('quem foi tirado da lista nao entra', () {
      final lista = winBackList([
        _summary(name: 'Rafael', daysAgo: 60, isActive: false),
      ]);

      expect(lista, isEmpty);
    });

    test('quem nunca veio nao sumiu', () {
      final lista = winBackList([
        const ClientSummary(
          client: Client(id: 'n', name: 'Novo', phone: '11988124471'),
          visitCount: 0,
          spentCents: 0,
        ),
      ]);

      expect(lista, isEmpty);
    });

    test('o que gastou mais vem primeiro, e nao o que sumiu ha mais tempo', () {
      final lista = winBackList([
        _summary(name: 'Corte', daysAgo: 300, spentCents: 3000),
        _summary(name: 'Platinado', daysAgo: 50, spentCents: 24000),
        _summary(name: 'Barba', daysAgo: 90, spentCents: 9000),
      ]);

      expect(lista.map((s) => s.client.name), ['Platinado', 'Barba', 'Corte']);
    });
  });

  test('winBackValueCents soma o que o grupo ja deixou', () {
    final lista = winBackList([
      _summary(name: 'A', daysAgo: 60, spentCents: 12000),
      _summary(name: 'B', daysAgo: 60, spentCents: 3000),
      _summary(name: 'C', daysAgo: 5, spentCents: 99900),
    ]);

    expect(winBackValueCents(lista), 15000);
  });

  group('winBackMessage', () {
    test('chama pelo primeiro nome e oferece o de sempre', () {
      final texto = winBackMessage(
        name: 'Rafael Lima',
        usualService: 'Corte + Barba',
      );

      expect(texto, contains('Oi, Rafael!'));
      expect(texto, contains('marcar o Corte + Barba?'));
    });

    test('sem servico de sempre, convida do mesmo jeito', () {
      final texto = winBackMessage(name: 'Douglas');

      expect(texto, contains('marcar um horário?'));
    });
  });
}
