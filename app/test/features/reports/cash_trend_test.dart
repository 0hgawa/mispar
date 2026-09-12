import 'package:flutter_test/flutter_test.dart';
import 'package:mispar/src/features/reports/domain/cash_trend.dart';

void main() {
  group('monthStarts', () {
    test('termina no mes de agora e volta seis', () {
      final starts = monthStarts(now: DateTime(2026, 9, 10));

      expect(starts, [
        DateTime(2026, 4),
        DateTime(2026, 5),
        DateTime(2026, 6),
        DateTime(2026, 7),
        DateTime(2026, 8),
        DateTime(2026, 9),
      ]);
    });

    test('atravessa a virada do ano', () {
      final starts = monthStarts(now: DateTime(2026, 2, 3), months: 4);

      expect(starts, [
        DateTime(2025, 11),
        DateTime(2025, 12),
        DateTime(2026),
        DateTime(2026, 2),
      ]);
    });
  });

  group('byMonth', () {
    final starts = monthStarts(now: DateTime(2026, 9, 10), months: 3);

    test('soma cada lancamento na casa do seu mes', () {
      final totals = byMonth(
        starts: starts,
        moves: [
          (at: DateTime(2026, 7, 4), cents: 4000),
          (at: DateTime(2026, 7, 30), cents: 6000),
          (at: DateTime(2026, 9), cents: 2500),
        ],
      );

      expect(totals, [10000, 0, 2500]);
    });

    test('mes sem nada fica zero, e nao some da fileira', () {
      expect(byMonth(starts: starts, moves: const []), [0, 0, 0]);
    });

    test('ignora o que cai fora da janela', () {
      final totals = byMonth(
        starts: starts,
        moves: [
          (at: DateTime(2026, 3, 9), cents: 9900),
          (at: DateTime(2026, 8, 9), cents: 100),
        ],
      );

      expect(totals, [0, 100, 0]);
    });
  });
}
