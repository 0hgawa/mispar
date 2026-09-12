import 'package:flutter_test/flutter_test.dart';
import 'package:marcos_barber/src/features/reports/domain/cash_days.dart';

typedef _Take = ({DateTime at, int cents});

List<DayTake<_Take>> _group(List<_Take> takes) =>
    byDay(takes, when: (t) => t.at, cents: (t) => t.cents);

void main() {
  group('byDay', () {
    test('junta o mesmo dia e soma o total dele', () {
      final days = _group([
        (at: DateTime(2026, 9, 10, 9), cents: 6000),
        (at: DateTime(2026, 9, 10, 14, 30), cents: 4000),
      ]);

      expect(days, hasLength(1));
      expect(days.single.day, DateTime(2026, 9, 10));
      expect(days.single.totalCents, 10000);
      expect(days.single.items, hasLength(2));
    });

    test('o dia mais recente vem primeiro', () {
      final days = _group([
        (at: DateTime(2026, 9, 8, 10), cents: 100),
        (at: DateTime(2026, 9, 10, 10), cents: 200),
        (at: DateTime(2026, 9, 9, 10), cents: 300),
      ]);

      expect(days.map((d) => d.day.day), [10, 9, 8]);
    });

    test(
      'a hora nao separa dias, e a meia-noite nao vaza para o dia de tras',
      () {
        final days = _group([
          (at: DateTime(2026, 9, 10), cents: 100),
          (at: DateTime(2026, 9, 10, 23, 59), cents: 100),
        ]);

        expect(days, hasLength(1));
        expect(days.single.totalCents, 200);
      },
    );

    test('sem lancamento nao ha dia', () {
      expect(_group(const []), isEmpty);
    });

    test('guarda a ordem em que os itens chegaram dentro do dia', () {
      final days = _group([
        (at: DateTime(2026, 9, 10, 9), cents: 1),
        (at: DateTime(2026, 9, 10, 8), cents: 2),
      ]);

      expect(days.single.items.map((t) => t.cents), [1, 2]);
    });
  });
}
