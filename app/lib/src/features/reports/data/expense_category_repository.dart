import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/data/database/app_database.dart';
import 'package:marcos_barber/src/features/reports/domain/expense.dart';
import 'package:marcos_barber/src/shared/formatters/text.dart';

class ExpenseCategoryRepository {
  const new(this._db);

  final AppDatabase _db;

  /// Os tipos de gasto. Por padrao so os em uso — tipo aposentado nao aparece
  /// para lancar, mas o que ja foi lancado nele continua somando.
  Stream<List<ExpenseCategory>> watchAll({bool includeRetired = false}) {
    final query = _db.select(_db.expenseCategories);
    if (!includeRetired) query.where((c) => c.active.equals(true));

    // A ordem sai do Dart, e nao do SQL: para o SQLite "Água" vem depois de
    // "Produtos", e uma lista alfabetica com o A no fim nao parece alfabetica.
    return query.watch().map(
      (rows) => rows.map(_toDomain).toList()
        ..sort(
          (a, b) =>
              normalizeForSearch(a.name).compareTo(normalizeForSearch(b.name)),
        ),
    );
  }

  /// O tipo com este id, ou nulo. Mesmo raciocinio do catalogo de servicos:
  /// o id nasce do nome.
  Future<ExpenseCategory?> findById(String id) {
    final query = _db.select(_db.expenseCategories)
      ..where((c) => c.id.equals(id));
    return query.getSingleOrNull().then(
      (row) => row == null ? null : _toDomain(row),
    );
  }

  Future<void> save(ExpenseCategory category) {
    return _db
        .into(_db.expenseCategories)
        .insertOnConflictUpdate(
          ExpenseCategoriesCompanion.insert(
            id: category.id,
            name: category.name,
            active: Value(category.isActive),
          ),
        );
  }

  /// Quantos gastos ja foram lancados neste tipo.
  ///
  /// Serve para saber se da para apagar de vez: tipo que ninguem usou e erro
  /// de digitacao, nao historico.
  Future<int> usageCount(String id) {
    final total = _db.expenses.id.count();
    final query = _db.selectOnly(_db.expenses)
      ..addColumns([total])
      ..where(_db.expenses.categoryId.equals(id));
    return query.getSingle().then((row) => row.read(total) ?? 0);
  }

  ExpenseCategory _toDomain(ExpenseCategoryRow row) =>
      ExpenseCategory(id: row.id, name: row.name, isActive: row.active);

  /// Apaga de vez. So chame quando [usageCount] for zero — com gasto atrelado
  /// o banco recusa, e o lancamento sumiria do Caixa.
  Future<void> delete(String id) =>
      (_db.delete(_db.expenseCategories)..where((c) => c.id.equals(id))).go();
}

final expenseCategoryRepositoryProvider = Provider<ExpenseCategoryRepository>(
  (ref) => ExpenseCategoryRepository(ref.watch(appDatabaseProvider)),
);

/// Os tipos que aparecem no formulario de lancar.
final activeExpenseCategoriesProvider = StreamProvider<List<ExpenseCategory>>((
  ref,
) {
  return ref.watch(expenseCategoryRepositoryProvider).watchAll();
});

/// Todos os tipos, inclusive os aposentados. E a lista de Ajustes.
final allExpenseCategoriesProvider = StreamProvider<List<ExpenseCategory>>((
  ref,
) {
  return ref
      .watch(expenseCategoryRepositoryProvider)
      .watchAll(includeRetired: true);
});
