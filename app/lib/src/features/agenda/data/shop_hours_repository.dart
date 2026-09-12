import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mispar/src/core/data/database/app_database.dart';
import 'package:mispar/src/features/agenda/domain/shop_hours.dart';

/// O horario de funcionamento da loja.
///
/// Unica fonte da verdade do app. Quando o Supabase entrar, a sincronia
/// escreve nesta mesma tabela e o robo passa a ver o que o Marcos configurou.
class ShopHoursRepository {
  const new(this._db);

  final AppDatabase _db;

  Stream<WeekHours> watch() {
    final query = _db.select(_db.shopHours)
      ..orderBy([(h) => OrderingTerm.asc(h.weekday)]);

    return query.watch().map(
      (rows) =>
          WeekHours({for (final row in rows) row.weekday: _toDomain(row)}),
    );
  }

  Future<void> save(DayHours hours) {
    return _db
        .into(_db.shopHours)
        .insertOnConflictUpdate(
          ShopHoursCompanion.insert(
            weekday: Value(hours.weekday),
            isOpen: Value(hours.isOpen),
            opensMinutes: hours.opensAt.inMinutes,
            closesMinutes: hours.closesAt.inMinutes,
            lunchStartMinutes: Value(hours.lunchStart?.inMinutes),
            lunchEndMinutes: Value(hours.lunchEnd?.inMinutes),
          ),
        );
  }

  DayHours _toDomain(ShopHoursRow row) => DayHours(
    weekday: row.weekday,
    isOpen: row.isOpen,
    opensAt: Duration(minutes: row.opensMinutes),
    closesAt: Duration(minutes: row.closesMinutes),
    lunchStart: row.lunchStartMinutes == null
        ? null
        : Duration(minutes: row.lunchStartMinutes!),
    lunchEnd: row.lunchEndMinutes == null
        ? null
        : Duration(minutes: row.lunchEndMinutes!),
  );
}

final shopHoursRepositoryProvider = Provider<ShopHoursRepository>(
  (ref) => ShopHoursRepository(ref.watch(appDatabaseProvider)),
);

/// A semana de funcionamento, para quem precisa montar grade.
///
/// Enquanto o banco nao responde, tudo fechado: melhor nao oferecer nada do
/// que oferecer horario errado.
final weekHoursProvider = StreamProvider<WeekHours>(
  (ref) => ref.watch(shopHoursRepositoryProvider).watch(),
);
