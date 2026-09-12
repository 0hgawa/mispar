import 'package:flutter_test/flutter_test.dart';
import 'package:mispar/src/features/reports/presentation/cash_view_model.dart';

void main() {
  group('percentChange', () {
    test('mede a subida', () {
      expect(percentChange(before: 100000, now: 112000), 12);
    });

    test('mede a queda', () {
      expect(percentChange(before: 100000, now: 92000), -8);
    });

    test('sem base nao ha comparacao', () {
      // "100% a mais" quando o mes passado foi zero nao diz nada: a barbearia
      // so nao tinha aberto.
      expect(percentChange(before: 0, now: 50000), isNull);
    });

    test('igual da zero', () {
      expect(percentChange(before: 40000, now: 40000), 0);
    });

    test('arredonda em vez de truncar', () {
      // 3/7 = 42,85...
      expect(percentChange(before: 70000, now: 100000), 43);
    });
  });
}
