import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/data/database/app_database.dart';
import 'package:marcos_barber/src/features/reports/domain/expense.dart';
import 'package:marcos_barber/src/features/reports/domain/recurring.dart';

class ExpenseRepository {
  const new(this._db);

  final AppDatabase _db;

  /// Os gastos de um periodo, do mais recente para o mais antigo. [to] e
  /// exclusivo, igual ao resto do app.
  Stream<List<Expense>> watchRange(DateTime from, DateTime to) {
    final categories = _db.expenseCategories;
    final query =
        _db.select(_db.expenses).join([
            innerJoin(
              categories,
              categories.id.equalsExp(_db.expenses.categoryId),
            ),
          ])
          ..where(
            _db.expenses.spentAt.isBiggerOrEqualValue(from) &
                _db.expenses.spentAt.isSmallerThanValue(to),
          )
          ..orderBy([OrderingTerm.desc(_db.expenses.spentAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => _toDomain(
              row.readTable(_db.expenses),
              row.readTable(categories),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> save(Expense expense) {
    return _db
        .into(_db.expenses)
        .insertOnConflictUpdate(
          ExpensesCompanion.insert(
            id: expense.id,
            spentAt: expense.spentAt,
            categoryId: expense.category.id,
            cents: expense.cents,
            note: Value(expense.note),
            repeatsMonthly: Value(expense.repeatsMonthly),
            seriesId: Value(expense.seriesId),
          ),
        );
  }

  /// Lanca os meses que faltam dos gastos que se repetem.
  ///
  /// Roda na abertura do app. Sem isto o aluguel so apareceria no mes em que
  /// foi digitado, e o lucro dos outros meses ficaria alto demais.
  ///
  /// A serie continua enquanto o **ultimo** lancamento dela ainda estiver
  /// marcado como mensal: desligar o "todo mes" no ultimo encerra a serie sem
  /// mexer no que ja passou. Quais datas entram e [monthsToCatchUp] quem diz.
  Future<void> catchUpRecurring(DateTime now) async {
    final query = _db.select(_db.expenses)
      ..where((e) => e.seriesId.isNotNull())
      ..orderBy([(e) => OrderingTerm.asc(e.spentAt)]);

    final rows = await query.get();
    if (rows.isEmpty) return;

    final series = <String, List<ExpenseRow>>{};
    for (final row in rows) {
      (series[row.seriesId!] ??= <ExpenseRow>[]).add(row);
    }

    final pending = <ExpensesCompanion>[];

    for (final entries in series.values) {
      final last = entries.last;
      if (!last.repeatsMonthly) continue;

      final first = entries.first;
      final missing = monthsToCatchUp(
        first: first.spentAt,
        now: now,
        alreadyLanced: {
          for (final entry in entries) expenseMonthKey(entry.spentAt),
        },
      );

      for (final day in missing) {
        pending.add(
          ExpensesCompanion.insert(
            // O id vem da serie e do mes: rodar duas vezes no mesmo dia nao
            // duplica o aluguel.
            id: '${first.seriesId}-${expenseMonthKey(day)}',
            spentAt: day,
            // O valor que vale e o do ultimo lancamento: aluguel que subiu
            // sobe para os meses seguintes.
            categoryId: last.categoryId,
            cents: last.cents,
            note: Value(last.note),
            repeatsMonthly: const Value(true),
            seriesId: Value(first.seriesId),
          ),
        );
      }
    }

    if (pending.isEmpty) return;
    await _db.batch((batch) => batch.insertAll(_db.expenses, pending));
  }

  /// Gasto nao tem historico atrelado: apagar e apagar mesmo.
  Future<void> delete(String id) =>
      (_db.delete(_db.expenses)..where((e) => e.id.equals(id))).go();

  Expense _toDomain(ExpenseRow row, ExpenseCategoryRow category) => Expense(
    id: row.id,
    spentAt: row.spentAt,
    category: ExpenseCategory(
      id: category.id,
      name: category.name,
      isActive: category.active,
    ),
    cents: row.cents,
    note: row.note,
    repeatsMonthly: row.repeatsMonthly,
    seriesId: row.seriesId,
  );
}

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(ref.watch(appDatabaseProvider)),
);
