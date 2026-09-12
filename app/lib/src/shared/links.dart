import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// O endereço do perfil no Instagram.
///
/// Link comum, e não a API: publicar ou ler pela API exige conta Business,
/// página no Facebook e revisão da Meta. O link abre o aplicativo quando ele
/// está instalado, e o navegador quando não — sem pedir nada a ninguém.
Uri instagramUri(String handle) => Uri.https('instagram.com', '/$handle');

/// O endereço no mapa, por busca de texto.
///
/// Busca e não coordenada: o que o Marcos digita é "Rua tal, 120" e não uma
/// latitude, e o `geo:` do Android com texto solto abre um mapa vazio em boa
/// parte dos aparelhos. Assim o mapa procura, como se alguém tivesse
/// digitado ali.
Uri mapsUri(String address) => Uri.https('www.google.com', '/maps/search/', {
  'api': '1',
  'query': address,
});

/// Abre um endereço em outro aplicativo.
///
/// Devolve `false` quando não há aplicativo para abrir. No Android o
/// `launchUrl` **nunca** devolve false — ele lança `ACTIVITY_NOT_FOUND` —,
/// então sem este catch quem chama testa um retorno que nunca vem.
Future<bool> openLink(Uri link) async {
  try {
    return await launchUrl(link, mode: LaunchMode.externalApplication);
  } on PlatformException {
    return false;
  }
}
