import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mispar/src/core/data/database/app_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Uma cópia do banco inteiro, num arquivo que o Marcos guarda onde quiser.
///
/// A nuvem já copia sozinha, e é ela que devolve a barbearia num celular novo.
/// Este arquivo existe para o caso que a nuvem não cobre: o projeto no
/// servidor pausado por inatividade, uma conta perdida, ou simplesmente o dono
/// querer os próprios dados fora de um serviço de terceiro.
///
/// Uma cópia que depende de a empresa continuar de pé não é a única cópia que
/// alguém deveria ter.
class Backup {
  const new(this._database);

  final AppDatabase _database;

  /// Gera o arquivo e abre a folha de compartilhar.
  ///
  /// `vacuum into` em vez de copiar o arquivo com o sistema: o banco está
  /// aberto e pode estar no meio de uma escrita, e copiar byte a byte nessa
  /// hora dá um arquivo quebrado — que só se descobre no dia de restaurar. O
  /// próprio SQLite monta uma cópia consistente, já compactada.
  Future<void> share() async {
    final pasta = await getTemporaryDirectory();
    final quando = DateTime.now();
    final nome =
        'mispar-${quando.year}-${_dois(quando.month)}-${_dois(quando.day)}.db';
    final destino = File('${pasta.path}/$nome');

    // O SQLite recusa gravar por cima; a cópia da semana passada não serve
    // para nada, e apagá-la é mais honesto que dar erro.
    if (destino.existsSync()) await destino.delete();

    await _database.customStatement("vacuum into '${destino.path}'");

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(destino.path, mimeType: 'application/x-sqlite3')],
        text: 'Cópia do Mispar de ${_dois(quando.day)}/${_dois(quando.month)}.',
      ),
    );
  }

  static String _dois(int n) => n.toString().padLeft(2, '0');
}

final backupProvider = Provider<Backup>(
  (ref) => Backup(ref.watch(appDatabaseProvider)),
);
