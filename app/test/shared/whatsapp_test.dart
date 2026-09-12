import 'package:flutter_test/flutter_test.dart';
import 'package:mispar/src/shared/whatsapp.dart';

void main() {
  group('whatsAppUri', () {
    test('põe o código do país quando falta', () {
      // Sem o 55 o WhatsApp abre a conversa de outra pessoa.
      expect(whatsAppUri('11 99640-2210').path, '/5511996402210');
    });

    test('não duplica o código que já veio', () {
      expect(whatsAppUri('5511996402210').path, '/5511996402210');
    });

    test('ignora pontuação do telefone', () {
      expect(whatsAppUri('+55 (11) 9 9640-2210').path, '/5511996402210');
    });

    test('sem mensagem não manda texto vazio', () {
      expect(whatsAppUri('11996402210').queryParameters, isEmpty);
    });

    test('a mensagem vai escapada na consulta', () {
      final uri = whatsAppUri(
        '11996402210',
        message: 'Oi, Rafael! Tudo certo?',
      );

      expect(uri.queryParameters['text'], 'Oi, Rafael! Tudo certo?');
      expect(uri.toString(), contains('wa.me/5511996402210?text='));
    });
  });
}
