import 'package:flutter_test/flutter_test.dart';
import 'package:mispar/src/features/reports/domain/cash_window.dart';

void main() {
  group('sameProgress', () {
    test('recorta o mes de tras no mesmo dia em que o de agora esta', () {
      final now = DateTime(2026, 9, 10, 14, 30);

      final cut = sameProgress(
        previous: (from: DateTime(2026, 8), to: DateTime(2026, 9)),
        current: (from: DateTime(2026, 9), to: DateTime(2026, 10)),
        now: now,
      );

      expect(cut.from, DateTime(2026, 8));
      expect(cut.to, DateTime(2026, 8, 10, 14, 30));
    });

    test('periodo ja fechado compara com o anterior inteiro', () {
      // "Mes passado", olhado em setembro: agosto ja acabou.
      final cut = sameProgress(
        previous: (from: DateTime(2026, 7), to: DateTime(2026, 8)),
        current: (from: DateTime(2026, 8), to: DateTime(2026, 9)),
        now: DateTime(2026, 9, 10),
      );

      expect(cut.from, DateTime(2026, 7));
      expect(cut.to, DateTime(2026, 8));
    });

    test('nao estica a janela de tras quando ela e mais curta', () {
      // Fevereiro tem 28 dias; o dia 30 de marco nao existe la.
      final cut = sameProgress(
        previous: (from: DateTime(2026, 2), to: DateTime(2026, 3)),
        current: (from: DateTime(2026, 3), to: DateTime(2026, 4)),
        now: DateTime(2026, 3, 31),
      );

      expect(cut.to, DateTime(2026, 3));
    });

    test('hoje de manha compara com ontem ate a mesma hora', () {
      final cut = sameProgress(
        previous: (from: DateTime(2026, 9, 9), to: DateTime(2026, 9, 10)),
        current: (from: DateTime(2026, 9, 10), to: DateTime(2026, 9, 11)),
        now: DateTime(2026, 9, 10, 11),
      );

      expect(cut.to, DateTime(2026, 9, 9, 11));
    });
  });

  group('wholeMonthOf', () {
    test('reconhece o mes inteiro', () {
      expect(
        wholeMonthOf(start: DateTime(2026, 8), end: DateTime(2026, 8, 31)),
        DateTime(2026, 8),
      );
    });

    test('reconhece fevereiro de ano bissexto', () {
      expect(
        wholeMonthOf(start: DateTime(2028, 2), end: DateTime(2028, 2, 29)),
        DateTime(2028, 2),
      );
    });

    test('nao reconhece pedaco de mes', () {
      expect(
        wholeMonthOf(start: DateTime(2026, 8), end: DateTime(2026, 8, 30)),
        isNull,
      );
      expect(
        wholeMonthOf(start: DateTime(2026, 8, 2), end: DateTime(2026, 8, 31)),
        isNull,
      );
    });

    test('nao reconhece intervalo que cruza meses', () {
      expect(
        wholeMonthOf(start: DateTime(2026, 8), end: DateTime(2026, 9, 30)),
        isNull,
      );
    });
  });
}
