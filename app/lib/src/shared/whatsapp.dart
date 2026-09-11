import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// O endereço que abre a conversa do WhatsApp com [phone].
///
/// Separado do lançamento para poder ser conferido em teste: o código do país
/// é a parte que, errada, abre a conversa de outra pessoa.
Uri whatsAppUri(String phone, {String? message}) {
  final digits = phone.replaceAll(RegExp('[^0-9]'), '');
  // Sem o codigo do pais o WhatsApp abre a conversa errada.
  final number = digits.startsWith('55') ? digits : '55$digits';

  return Uri.https('wa.me', '/$number', {'text': ?message});
}

/// Abre a conversa do WhatsApp, opcionalmente com [message] ja digitada.
///
/// O texto vai pronto mas **nao** e enviado: quem manda e o Marcos. Mensagem
/// que sai sozinha do celular dele seria o app falando no lugar dele.
///
/// Devolve `false` quando não há aplicativo para abrir o endereço. No Android
/// o `launchUrl` **nunca** devolve false — ele lança `ACTIVITY_NOT_FOUND`. Sem
/// este catch, quem chama testa um retorno que nunca vem: o aviso de "não
/// consegui abrir" não aparecia, e o botão simplesmente não fazia nada.
Future<bool> openWhatsApp(String phone, {String? message}) async {
  try {
    return await launchUrl(
      whatsAppUri(phone, message: message),
      mode: LaunchMode.externalApplication,
    );
  } on PlatformException {
    return false;
  }
}

/// O primeiro nome, que e como se fala com cliente.
String firstName(String name) {
  final trimmed = name.trim();
  final space = trimmed.indexOf(' ');
  return space == -1 ? trimmed : trimmed.substring(0, space);
}
