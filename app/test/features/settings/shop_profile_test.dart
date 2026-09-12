import 'package:flutter_test/flutter_test.dart';
import 'package:mispar/src/features/settings/domain/shop_profile.dart';

void main() {
  group('readHandle', () {
    test('a arroba digitada nao entra no endereco', () {
      expect(readHandle('@mispar'), 'mispar');
    });

    test('so o nome ja serve', () {
      expect(readHandle('mispar'), 'mispar');
    });

    test('o link inteiro do perfil vira o nome', () {
      expect(readHandle('https://www.instagram.com/mispar/'), 'mispar');
    });

    test('o link sem http tambem', () {
      expect(readHandle('instagram.com/mispar'), 'mispar');
    });

    test('o rastreio pendurado no link compartilhado cai fora', () {
      expect(
        readHandle('https://instagram.com/mispar?igshid=abc123'),
        'mispar',
      );
    });

    test('maiuscula vira minuscula, que e como o endereco e escrito', () {
      expect(readHandle('  Mispar '), 'mispar');
    });

    test('ponto e traco baixo ficam, que o Instagram aceita', () {
      expect(readHandle('marcos.barber_1'), 'marcos.barber_1');
    });

    test('espaco no meio e engano de digitacao, e nao endereco', () {
      expect(readHandle('barbearia do marcos'), 'barbeariadomarcos');
    });

    test('campo vazio continua vazio', () {
      expect(readHandle('   '), '');
    });
  });

  group('ShopProfile.signature', () {
    test('o @ vem primeiro: da para fazer algo com ele', () {
      const shop = ShopProfile(name: 'Marcos Barbearia', instagram: 'marcos');
      expect(shop.signature, '@marcos');
    });

    test('sem @, assina com o nome', () {
      const shop = ShopProfile(name: 'Marcos Barbearia');
      expect(shop.signature, 'Marcos Barbearia');
    });

    test('sem nada, nao assina — e o cartaz esconde a linha', () {
      expect(const ShopProfile.unknown().signature, '');
    });
  });

  group('shopAddressMessage', () {
    test('sem endereco nao ha mensagem', () {
      const shop = ShopProfile(name: 'Marcos Barbearia');
      expect(shopAddressMessage(shop), '');
    });

    test('leva nome, endereco e o link do mapa', () {
      const shop = ShopProfile(
        name: 'Marcos Barbearia',
        address: 'Rua das Flores, 120',
      );

      expect(
        shopAddressMessage(shop),
        'Marcos Barbearia\n'
        'Rua das Flores, 120\n'
        '\n'
        'https://www.google.com/maps/search/'
        '?api=1&query=Rua+das+Flores%2C+120',
      );
    });

    test('sem nome, comeca pelo endereco', () {
      const shop = ShopProfile(address: 'Rua das Flores, 120');
      expect(shopAddressMessage(shop), startsWith('Rua das Flores, 120\n'));
    });
  });
}
