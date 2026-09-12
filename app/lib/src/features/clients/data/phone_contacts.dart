import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:mispar/src/shared/formatters/phone.dart';
import 'package:mispar/src/shared/formatters/text.dart';

/// Um contato da agenda do celular, reduzido ao que a barbearia usa.
class PhoneContact {
  const new({required this.name, required this.phone});

  final String name;
  final String phone;

  /// Os digitos que identificam a linha. E por aqui que se sabe se este
  /// contato ja virou cliente.
  String get key => phoneKey(phone);
}

/// Por que a leitura da agenda nao aconteceu.
enum ContactsDenied {
  /// O Marcos recusou o pedido de permissao.
  refused,

  /// Nao ha o que importar: agenda vazia, ou so contatos sem telefone.
  empty,
}

/// O resultado de tentar ler a agenda: ou os contatos, ou o motivo de nao ter.
typedef ContactsResult = ({
  List<PhoneContact> contacts,
  ContactsDenied? denied,
});

/// Lê a agenda do celular.
///
/// **Pede só o telefone.** `getAll` já devolve id e nome por padrão; qualquer
/// propriedade a mais — e a foto acima de todas — custa uma consulta inteira
/// ao provedor de contatos do Android. Numa agenda de mil nomes isso é a
/// diferença entre abrir na hora e travar por segundos, para mostrar algo que
/// a barbearia nem usa.
///
/// Os contatos ficam no aparelho: viram linha no SQLite local e nada é
/// enviado para lugar nenhum.
Future<ContactsResult> readPhoneContacts() async {
  final status = await FlutterContacts.permissions.request(PermissionType.read);

  // `limited` e o iOS 18, em que o dono escolhe quais contatos compartilhar.
  // Serve: importar parte da agenda e melhor que nao importar nada.
  final allowed =
      status == PermissionStatus.granted || status == PermissionStatus.limited;
  if (!allowed) {
    return (contacts: const <PhoneContact>[], denied: ContactsDenied.refused);
  }

  final raw = await FlutterContacts.getAll(properties: {ContactProperty.phone});

  final seen = <String>{};
  final contacts = <PhoneContact>[];

  for (final contact in raw) {
    // Contato sem telefone nao serve: o robo do WhatsApp fala pelo numero.
    if (contact.phones.isEmpty) continue;

    final name = contact.displayName?.trim() ?? '';
    if (name.isEmpty) continue;

    final phone = contact.phones.first.number.trim();
    final key = phoneKey(phone);
    if (key.isEmpty) continue;

    // Mesmo numero em dois contatos e a mesma pessoa: entra uma vez so.
    if (!seen.add(key)) continue;

    contacts.add(PhoneContact(name: name, phone: phone));
  }

  contacts.sort(
    (a, b) => normalizeForSearch(a.name).compareTo(normalizeForSearch(b.name)),
  );

  return (
    contacts: contacts,
    denied: contacts.isEmpty ? ContactsDenied.empty : null,
  );
}
