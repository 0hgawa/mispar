import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mispar/src/core/data/database/app_database.dart';
import 'package:mispar/src/features/services/domain/catalogue_kind.dart';
import 'package:mispar/src/features/services/domain/service.dart';

class ServiceRepository {
  const new(this._db);

  final AppDatabase _db;

  /// O catalogo. Por padrao so o que esta em uso — servico aposentado nao
  /// aparece para marcar, mas continua no historico de quem ja pagou.
  Stream<List<Service>> watchAll({
    bool includeRetired = false,
    CatalogueKind? only,
  }) {
    final query = _db.select(_db.services)
      ..orderBy([(s) => OrderingTerm.asc(s.priceCents)]);
    if (!includeRetired) query.where((s) => s.active.equals(true));
    if (only != null) query.where((s) => s.kind.equals(only.name));

    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  Stream<Service?> watchOne(String id) {
    final query = _db.select(_db.services)..where((s) => s.id.equals(id));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _toDomain(row),
    );
  }

  /// O servico com este id, ou nulo. O id nasce do nome, entao isto responde
  /// "ja existe um servico com este nome?" sem varrer o catalogo.
  Future<Service?> findById(String id) {
    final query = _db.select(_db.services)..where((s) => s.id.equals(id));
    return query.getSingleOrNull().then(
      (row) => row == null ? null : _toDomain(row),
    );
  }

  Future<void> save(Service service) {
    return _db
        .into(_db.services)
        .insertOnConflictUpdate(
          ServicesCompanion.insert(
            id: service.id,
            name: service.name,
            durationMinutes: service.duration.inMinutes,
            priceCents: service.priceCents,
            requiresDeposit: Value(service.requiresDeposit),
            active: Value(service.isActive),
            kind: Value(service.kind.name),
          ),
        );
  }

  /// Quantos atendimentos ja usaram este servico.
  ///
  /// Serve para saber se da para apagar de vez: servico que ninguem usou e
  /// erro de digitacao, nao historico.
  Future<int> usageCount(String id) {
    final total = _db.appointments.id.count();
    final query = _db.selectOnly(_db.appointments)
      ..addColumns([total])
      ..where(_db.appointments.serviceId.equals(id));
    return query.getSingle().then((row) => row.read(total) ?? 0);
  }

  /// Apaga de vez. So chame quando [usageCount] for zero — com atendimento
  /// atrelado, o banco recusa e o historico sumiria da lista.
  Future<void> delete(String id) =>
      (_db.delete(_db.services)..where((s) => s.id.equals(id))).go();

  /// Aposenta em vez de apagar: apagar quebraria o historico e o caixa.
  Future<void> setActive(String id, {required bool isActive}) {
    return (_db.update(_db.services)..where((s) => s.id.equals(id))).write(
      ServicesCompanion(active: Value(isActive)),
    );
  }

  Service _toDomain(ServiceRow row) => Service(
    id: row.id,
    name: row.name,
    duration: Duration(minutes: row.durationMinutes),
    priceCents: row.priceCents,
    requiresDeposit: row.requiresDeposit,
    isActive: row.active,
    kind: CatalogueKind.fromWire(row.kind),
  );
}

final serviceRepositoryProvider = Provider<ServiceRepository>(
  (ref) => ServiceRepository(ref.watch(appDatabaseProvider)),
);
