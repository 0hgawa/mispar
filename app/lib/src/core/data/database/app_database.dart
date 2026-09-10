import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/data/database/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Services,
    Clients,
    Appointments,
    ShopHours,
    ShopSettings,
    TimeBlocks,
    ExpenseCategories,
    Expenses,
  ],
)
class AppDatabase extends _$AppDatabase {
  new() : super(driftDatabase(name: 'marcos_barber'));

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // v2: o horario de funcionamento saiu do codigo e virou tabela.
      if (from < 2) await m.createTable(shopHours);
      // v3: servico pode ser aposentado sem apagar o historico.
      if (from < 3) await m.addColumn(services, services.active);
      // v4: o caixa passou a contar o que sai, nao so o que entra.
      if (from < 4) await m.createTable(expenses);
      // v5: o tipo do gasto virou cadastro. Os ids sao os mesmos nomes que a
      // v4 gravava, entao o que ja foi lancado continua achando o seu tipo.
      if (from < 5) await m.createTable(expenseCategories);
      // v6: gasto que se repete todo mes.
      if (from < 6) {
        await m.addColumn(expenses, expenses.repeatsMonthly);
        await m.addColumn(expenses, expenses.seriesId);
      }
      // v7: como o cliente pagou.
      if (from < 7) {
        await m.addColumn(appointments, appointments.paymentMethod);
      }
      // v8: fechar um dia especifico — feriado, medico, viagem.
      if (from < 8) await m.createTable(timeBlocks);
      // v9: cliente pode sair da lista sem perder o historico.
      if (from < 9) await m.addColumn(clients, clients.active);
      // v10: o passo dos horarios saiu do codigo e virou ajuste.
      if (from < 10) await m.createTable(shopSettings);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
