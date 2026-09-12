import 'package:flutter_test/flutter_test.dart';
import 'package:mispar/src/shared/formatters/day_time.dart';

void main() {
  group('hasPassed', () {
    // Onze da manha: a manha inteira ja venceu, mas o dia nao.
    final agora = DateTime(2026, 9, 12, 11);

    test('ontem passou', () {
      expect(hasPassed(DateTime(2026, 9, 11), now: agora), isTrue);
    });

    test('hoje nao passou, mesmo com a manha inteira vencida', () {
      expect(hasPassed(DateTime(2026, 9, 12), now: agora), isFalse);
    });

    test('a hora do dia nao conta: hoje as 8h continua sendo hoje', () {
      expect(hasPassed(DateTime(2026, 9, 12, 8), now: agora), isFalse);
    });

    test('amanha nao passou', () {
      expect(hasPassed(DateTime(2026, 9, 13), now: agora), isFalse);
    });

    test('virada de mes conta como dia, e nao como numero', () {
      expect(
        hasPassed(DateTime(2026, 8, 31), now: DateTime(2026, 9, 1, 0, 5)),
        isTrue,
      );
    });
  });
}
