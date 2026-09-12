import 'package:flutter_test/flutter_test.dart';
import 'package:mispar/src/shared/formatters/phone.dart';

void main() {
  group('phoneKey', () {
    test('o mesmo número escrito de jeitos diferentes dá a mesma chave', () {
      // É isto que impede o mesmo cliente de entrar duas vezes na importação.
      const same = '11996402210';
      expect(phoneKey('11996402210'), same);
      expect(phoneKey('(11) 9 9640-2210'), same);
      expect(phoneKey('+55 11 99640-2210'), same);
      expect(phoneKey('55 11 99640 2210'), same);
      expect(phoneKey(' 11 99640-2210 '), same);
    });

    test('números diferentes não colidem', () {
      expect(phoneKey('11996402210'), isNot(phoneKey('11996402211')));
    });

    test('fixo antigo que começa com 55 não perde o começo', () {
      // 8 dígitos: não é código de país, é o número.
      expect(phoneKey('5512-3456'), '55123456');
    });

    test('celular de DDD 55 mantém o DDD', () {
      // Santa Maria, RS. Onze dígitos com 55 na frente é DDD, não país.
      expect(phoneKey('55 99640-2210'), '55996402210');
    });

    test('com país e DDD 55 corta só o país', () {
      expect(phoneKey('+55 55 99640-2210'), '55996402210');
    });

    test('texto sem número vira vazio', () {
      expect(phoneKey('sem telefone'), '');
      expect(phoneKey(''), '');
    });
  });
}
