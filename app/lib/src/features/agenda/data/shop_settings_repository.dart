import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/data/database/app_database.dart';
import 'package:marcos_barber/src/features/agenda/domain/shop_hours.dart';

/// O que se ajusta uma vez e vale para a barbearia inteira.
///
/// A tabela tem uma linha so, e o id dela **tem que ir escrito**. No SQLite,
/// uma coluna `integer` que e chave primaria vira apelido do rowid: omitir o
/// valor nao aplica o `default 1`, ele numera sozinho. Sem o id explicito,
/// cada gravacao criava uma linha nova em vez de atualizar a existente — e a
/// leitura, que espera uma linha so, parava de responder.
class ShopSettingsRepository {
  const new(this._db);

  final AppDatabase _db;

  /// O id da unica linha que esta tabela pode ter.
  static const _theRow = 1;

  /// De quanto em quanto tempo os horarios sao oferecidos.
  Stream<Duration> watchSlotStep() {
    final query = _db.select(_db.shopSettings)
      ..where((s) => s.id.equals(_theRow));

    return query.watchSingleOrNull().map(
      (row) =>
          row == null ? SlotRules.step : Duration(minutes: row.slotStepMinutes),
    );
  }

  Future<void> saveSlotStep(Duration step) {
    return _db
        .into(_db.shopSettings)
        .insertOnConflictUpdate(
          ShopSettingsCompanion.insert(
            id: const Value(_theRow),
            slotStepMinutes: Value(step.inMinutes),
          ),
        );
  }
}

final shopSettingsRepositoryProvider = Provider<ShopSettingsRepository>(
  (ref) => ShopSettingsRepository(ref.watch(appDatabaseProvider)),
);

/// O passo em uso. Cai no padrao enquanto o banco nao respondeu — a tela de
/// marcar nao pode ficar em branco esperando um numero.
final slotStepProvider = StreamProvider<Duration>((ref) {
  return ref.watch(shopSettingsRepositoryProvider).watchSlotStep();
});
