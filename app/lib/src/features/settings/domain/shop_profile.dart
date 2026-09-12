import 'package:marcos_barber/src/shared/links.dart';

/// O cadastro da barbearia: como ela se chama, onde fica, e o @ dela.
///
/// Só existe campo que alguma coisa lê. O nome e o @ assinam o cartaz de
/// divulgar horário — sem eles, uma imagem encaminhada não diz de quem é. O
/// endereço abre o mapa e vira mensagem pronta, que é o que o Marcos digita
/// na mão toda semana.
///
/// Vazio quer dizer "não preenchido", e cada campo se vira sozinho com isso:
/// quem não pôs o @ simplesmente não vê a assinatura.
class ShopProfile {
  const new({this.name = '', this.address = '', this.instagram = ''});

  /// Enquanto o banco não respondeu. Tudo vazio, que é o mesmo que a tela
  /// mostra para quem nunca preencheu — nada pisca ao abrir.
  const new unknown() : name = '', address = '', instagram = '';

  final String name;
  final String address;

  /// Sem arroba e em minúscula. Ver [readHandle].
  final String instagram;

  /// O que assina o cartaz: o @ quando existe, e o nome quando não.
  ///
  /// O @ vem primeiro porque dá para fazer algo com ele — abrir o perfil,
  /// mandar mensagem. Nome sozinho só diz de quem é.
  String get signature {
    if (instagram.isNotEmpty) return '@$instagram';
    return name;
  }

  ShopProfile copyWith({String? name, String? address, String? instagram}) {
    return ShopProfile(
      name: name ?? this.name,
      address: address ?? this.address,
      instagram: instagram ?? this.instagram,
    );
  }
}

/// Tira do que foi digitado o @ que serve para montar um endereço.
///
/// Aceita as três formas que alguém cola ali sem pensar: `@marcos`,
/// `marcos`, e o link inteiro do perfil. Guardar já limpo evita que cada
/// lugar que usa tenha que limpar de novo — e é limpando na entrada que o
/// link colado deixa de virar `instagram.com/https://instagram.com/marcos`.
String readHandle(String typed) {
  var text = typed.trim().toLowerCase();
  if (text.isEmpty) return '';

  // O link do perfil, com ou sem http e com ou sem barra no fim.
  final link = RegExp(r'^(?:https?://)?(?:www\.)?instagram\.com/');
  text = text.replaceFirst(link, '');
  // O que vier depois da barra é aba do perfil, e não faz parte do nome.
  text = text.split('/').first;
  // Parâmetro de rastreio que o Instagram pendura no link compartilhado.
  text = text.split('?').first;
  text = text.replaceFirst('@', '');

  // O Instagram só aceita letra, número, ponto e traço baixo. Qualquer outra
  // coisa é engano de digitação, e passaria adiante como endereço quebrado.
  return text.replaceAll(RegExp('[^a-z0-9._]'), '');
}

/// O endereço pronto para mandar no WhatsApp.
///
/// Leva o link do mapa junto: sem ele o cliente teria que copiar o endereço e
/// colar na busca, e é nesse pulo que ele desiste e pergunta de novo.
///
/// Vazio quando não há endereço — quem chama esconde o botão, em vez de
/// mandar uma mensagem só com o nome.
String shopAddressMessage(ShopProfile shop) {
  if (shop.address.isEmpty) return '';

  final cabeca = shop.name.isEmpty ? '' : '${shop.name}\n';
  return '$cabeca${shop.address}\n\n${mapsUri(shop.address)}';
}
