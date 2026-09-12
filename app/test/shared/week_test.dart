import 'package:flutter_test/flutter_test.dart';
import 'package:marcos_barber/src/shared/week.dart';

void main() {
  group('startOfWeek', () {
    test('domingo é o começo dele mesmo', () {
      expect(startOfWeek(DateTime(2026, 9, 6)), DateTime(2026, 9, 6));
    });

    test('sábado volta seis dias', () {
      expect(startOfWeek(DateTime(2026, 9, 12)), DateTime(2026, 9, 6));
    });

    test('segunda volta um dia, e nao sete', () {
      expect(startOfWeek(DateTime(2026, 9, 7)), DateTime(2026, 9, 6));
    });

    test('atravessa a virada do mes', () {
      // Terca, 1 de setembro: a semana comeca em 30 de agosto.
      expect(startOfWeek(DateTime(2026, 9)), DateTime(2026, 8, 30));
    });

    test('atravessa a virada do ano', () {
      // Sexta, 1 de janeiro de 2027: a semana comeca em 27 de dezembro.
      expect(startOfWeek(DateTime(2027)), DateTime(2026, 12, 27));
    });

    test('a hora nao entra na conta', () {
      expect(startOfWeek(DateTime(2026, 9, 11, 23, 59)), DateTime(2026, 9, 6));
    });
  });
}
