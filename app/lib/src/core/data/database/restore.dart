import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mispar/src/core/data/database/app_database.dart';
import 'package:path_provider/path_provider.dart';

/// Volta o aparelho para o que estava numa cópia guardada.
///
/// **Substitui, não junta.** "Voltar de uma cópia" quer dizer que a barbearia
/// passa a ser aquela; misturar as duas daria uma terceira que nunca existiu,
/// com clientes apagados voltando e preços de duas épocas convivendo.
///
/// Por isso é destrutivo e pede confirmação: o que está no aparelho agora
/// some. Quem chama é responsável por perguntar antes.
class Restore {
  const new(this._database);

  final AppDatabase _database;

  /// As tabelas que o gatilho da lápide observa.
  ///
  /// Precisam ficar mudas durante a troca: apagar tudo para pôr a cópia no
  /// lugar geraria uma lápide por linha, e a próxima subida levaria a
  /// barbearia inteira do servidor junto. Restaurar apagaria a cópia.
  static const _comLapide = [
    'services',
    'clients',
    'time_blocks',
    'appointments',
    'expense_categories',
    'expenses',
  ];

  /// Pede o arquivo e devolve `null` se a pessoa desistir.
  ///
  /// Sem filtro de extensao: no Android o seletor de arquivos costuma nao
  /// reconhecer `.db` e esconderia justamente a copia que se quer abrir.
  Future<File?> pick() async {
    final escolha = await FilePicker.pickFile(
      dialogTitle: 'Escolha a cópia do Mispar',
    );
    final caminho = escolha?.path;
    return caminho == null ? null : File(caminho);
  }

  /// Lê a cópia e põe o aparelho igual a ela.
  Future<void> from(File copia) async {
    // Numa cópia da cópia: abrir o arquivo escolhido direto rodaria as
    // migrations dentro dele, mexendo num arquivo que é do Marcos e que ele
    // pode querer guardar do jeito que está.
    final pasta = await getTemporaryDirectory();
    final trabalho = File('${pasta.path}/restaurando.db');
    if (trabalho.existsSync()) await trabalho.delete();
    await copia.copy(trabalho.path);

    final origem = AppDatabase.aberto(NativeDatabase(trabalho));

    try {
      final servicos = await origem.select(origem.services).get();
      final clientes = await origem.select(origem.clients).get();
      final horarios = await origem.select(origem.shopHours).get();
      final bloqueios = await origem.select(origem.timeBlocks).get();
      final tipos = await origem.select(origem.expenseCategories).get();
      final despesas = await origem.select(origem.expenses).get();
      final atendimentos = await origem.select(origem.appointments).get();
      final ajustes = await origem.select(origem.shopSettings).get();

      await _database.transaction(() async {
        await _semLapides(() async {
          // Ordem inversa da dependência para apagar, e direta para pôr: o
          // banco tem chave estrangeira de verdade e recusa qualquer outra.
          await _database.delete(_database.appointments).go();
          await _database.delete(_database.expenses).go();
          await _database.delete(_database.timeBlocks).go();
          await _database.delete(_database.clients).go();
          await _database.delete(_database.services).go();
          await _database.delete(_database.expenseCategories).go();
          await _database.delete(_database.shopHours).go();

          await _database.batch((batch) {
            batch
              ..insertAll(_database.services, servicos)
              ..insertAll(_database.expenseCategories, tipos)
              ..insertAll(_database.clients, clientes)
              ..insertAll(_database.shopHours, horarios)
              ..insertAll(_database.timeBlocks, bloqueios)
              ..insertAll(_database.appointments, atendimentos)
              ..insertAll(_database.expenses, despesas)
              ..insertAllOnConflictUpdate(_database.shopSettings, ajustes);
          });
        });
      });
    } finally {
      await origem.close();
      if (trabalho.existsSync()) await trabalho.delete();
    }
  }

  /// Roda [acao] com os gatilhos de lápide desligados, e os religa depois.
  ///
  /// `finally` de propósito: se a troca falhar no meio, o banco não pode ficar
  /// sem os gatilhos — daí em diante nenhuma exclusão chegaria ao servidor, e
  /// ninguém perceberia.
  Future<void> _semLapides(Future<void> Function() acao) async {
    for (final tabela in _comLapide) {
      await _database.customStatement(
        'drop trigger if exists ${tabela}_tombstone',
      );
    }

    try {
      await acao();
    } finally {
      for (final tabela in _comLapide) {
        await _database.customStatement('''
          create trigger if not exists ${tabela}_tombstone
          after delete on $tabela
          begin
            insert or replace into deleted_rows (table_name, row_id, deleted_at)
            values ('$tabela', old.id, strftime('%s', 'now'));
          end;
        ''');
      }
    }
  }
}

final restoreProvider = Provider<Restore>(
  (ref) => Restore(ref.watch(appDatabaseProvider)),
);
