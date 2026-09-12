import 'package:flutter_test/flutter_test.dart';
import 'package:mispar/src/features/clients/domain/client.dart';
import 'package:mispar/src/features/clients/domain/client_summary.dart';
import 'package:mispar/src/features/clients/presentation/clients_view_model.dart';

ClientSummary _client(String name, {String phone = '11999990000'}) {
  return ClientSummary(
    client: Client(id: name, name: name, phone: phone),
    visitCount: 0,
    spentCents: 0,
  );
}

final List<ClientSummary> _all = [
  _client('Rafael Lima', phone: '11 99640-2210'),
  _client('Douglas Prates'),
  _client('Jonas Beiral'),
  _client('Ney Cardoso'),
  _client('Iuri Mancuso'),
];

List<String> _names(List<ClientSummary> list) => [
  for (final summary in list) summary.client.name,
];

void main() {
  group('matchingClients', () {
    test('termo vazio devolve todo mundo', () {
      expect(matchingClients(_all, '  '), hasLength(5));
    });

    test('casa o começo do primeiro nome', () {
      expect(_names(matchingClients(_all, 'Ra')), ['Rafael Lima']);
    });

    test('não casa o meio da palavra', () {
      // "ra" está dentro de PRAtes e BeiRAl, mas ninguém busca cliente pelo
      // meio do sobrenome.
      final found = _names(matchingClients(_all, 'ra'));
      expect(found, isNot(contains('Douglas Prates')));
      expect(found, isNot(contains('Jonas Beiral')));
    });

    test('casa o começo do sobrenome também', () {
      expect(_names(matchingClients(_all, 'Prates')), ['Douglas Prates']);
    });

    test('ignora acento e caixa', () {
      expect(_names(matchingClients(_all, 'ÍURI')), ['Iuri Mancuso']);
    });

    test('acha pelo telefone, com ou sem pontuação', () {
      expect(_names(matchingClients(_all, '99640')), ['Rafael Lima']);
      expect(_names(matchingClients(_all, '11 99640-2210')), ['Rafael Lima']);
    });

    test('nome que não existe não devolve nada', () {
      expect(matchingClients(_all, 'Zeca'), isEmpty);
    });
  });
}
