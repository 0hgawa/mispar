import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mispar/src/core/data/database/app_database.dart';
import 'package:mispar/src/features/agenda/domain/time_block.dart';

class TimeBlockRepository {
  const new(this._db);

  final AppDatabase _db;

  /// Os fechamentos que tocam a faixa pedida. [to] e exclusivo.
  ///
  /// A comparacao usa o cruzamento das duas faixas, e nao so o inicio: uma
  /// viagem que comecou semana passada e acaba amanha tem que aparecer na
  /// semana de hoje.
  Stream<List<TimeBlock>> watchRange(DateTime from, DateTime to) {
    final query = _db.select(_db.timeBlocks)
      ..where((b) => b.startsAt.isSmallerThanValue(to))
      ..where((b) => b.endsAt.isBiggerThanValue(from))
      ..orderBy([(b) => OrderingTerm.asc(b.startsAt)]);

    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  /// Os fechamentos que ainda estao por vir, para a tela de ajustes. O que ja
  /// passou nao se configura.
  Stream<List<TimeBlock>> watchUpcoming(DateTime now) {
    final query = _db.select(_db.timeBlocks)
      ..where((b) => b.endsAt.isBiggerThanValue(now))
      ..orderBy([(b) => OrderingTerm.asc(b.startsAt)]);

    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  Future<void> save(TimeBlock block) {
    return _db
        .into(_db.timeBlocks)
        .insertOnConflictUpdate(
          TimeBlocksCompanion.insert(
            id: block.id,
            startsAt: block.startsAt,
            endsAt: block.endsAt,
            reason: Value(block.reason),
          ),
        );
  }

  Future<void> delete(String id) =>
      (_db.delete(_db.timeBlocks)..where((b) => b.id.equals(id))).go();

  TimeBlock _toDomain(TimeBlockRow row) => TimeBlock(
    id: row.id,
    startsAt: row.startsAt,
    endsAt: row.endsAt,
    reason: row.reason,
  );
}

final timeBlockRepositoryProvider = Provider<TimeBlockRepository>(
  (ref) => TimeBlockRepository(ref.watch(appDatabaseProvider)),
);

/// Os fechamentos ainda por vir. E a lista de Ajustes.
final upcomingTimeBlocksProvider = StreamProvider<List<TimeBlock>>((ref) {
  return ref.watch(timeBlockRepositoryProvider).watchUpcoming(DateTime.now());
});
