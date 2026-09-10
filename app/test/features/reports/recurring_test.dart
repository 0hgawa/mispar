import 'package:flutter_test/flutter_test.dart';
import 'package:marcos_barber/src/features/reports/domain/recurring.dart';

void main() {
  group('monthsToCatchUp', () {
    test('lanca os meses que passaram desde o primeiro', () {
      final missing = monthsToCatchUp(
        first: DateTime(2026, 6, 5),
        now: DateTime(2026, 9, 10),
        alreadyLanced: {'2026-06'},
      );

      expect(missing, [
        DateTime(2026, 7, 5),
        DateTime(2026, 8, 5),
        DateTime(2026, 9, 5),
      ]);
    });

    test('nao lanca o mes atual antes do dia chegar', () {
      // Aluguel do dia 15, hoje e dia 10: o dinheiro ainda nao saiu.
      final missing = monthsToCatchUp(
        first: DateTime(2026, 7, 15),
        now: DateTime(2026, 9, 10),
        alreadyLanced: {'2026-07'},
      );

      expect(missing, [DateTime(2026, 8, 15)]);
    });

    test('nao repete o que ja foi lancado', () {
      final missing = monthsToCatchUp(
        first: DateTime(2026, 6, 5),
        now: DateTime(2026, 9, 10),
        alreadyLanced: {'2026-06', '2026-07', '2026-08', '2026-09'},
      );

      expect(missing, isEmpty);
    });

    test('dia 31 cai no ultimo dia de fevereiro', () {
      final missing = monthsToCatchUp(
        first: DateTime(2026, 1, 31),
        now: DateTime(2026, 3, 5),
        alreadyLanced: {'2026-01'},
      );

      // Marco 31 ainda nao chegou; fevereiro nao tem 31.
      expect(missing, [DateTime(2026, 2, 28)]);
    });

    test('atravessa a virada do ano', () {
      final missing = monthsToCatchUp(
        first: DateTime(2025, 11, 10),
        now: DateTime(2026, 1, 20),
        alreadyLanced: {'2025-11'},
      );

      expect(missing, [DateTime(2025, 12, 10), DateTime(2026, 1, 10)]);
    });

    test('gasto lancado hoje nao gera nada', () {
      final missing = monthsToCatchUp(
        first: DateTime(2026, 9, 10),
        now: DateTime(2026, 9, 10),
        alreadyLanced: {'2026-09'},
      );

      expect(missing, isEmpty);
    });
  });

  test('expenseMonthKey preenche o mes com zero', () {
    expect(expenseMonthKey(DateTime(2026, 3, 7)), '2026-03');
    expect(expenseMonthKey(DateTime(2026, 12, 31)), '2026-12');
  });
}
