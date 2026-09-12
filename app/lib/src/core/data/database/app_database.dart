import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mispar/src/core/data/database/tables.dart';

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
  new() : super(driftDatabase(name: 'mispar'));

  @override
  int get schemaVersion => 17;

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
      // v11: atendimento sem cliente — o que foi lancado direto no Caixa.
      // Coluna que deixa de ser obrigatoria exige refazer a tabela no SQLite;
      // o `columnTransformer` vazio copia o que ja esta la como esta.
      if (from < 11) {
        await m.alterTable(TableMigration(appointments));
      }
      // v12: o catalogo passou a ter produto, e nao so servico.
      if (from < 12) await m.addColumn(services, services.kind);
      // v13: o lembrete da véspera, com interruptor e hora escolhida.
      if (from < 13) {
        await m.addColumn(shopSettings, shopSettings.reminderEnabled);
        await m.addColumn(shopSettings, shopSettings.reminderHoursBefore);
      }
      // v14: o prazo de "sumiu" virou ajuste, e ganhou interruptor.
      if (from < 14) {
        await m.addColumn(shopSettings, shopSettings.driftedEnabled);
        await m.addColumn(shopSettings, shopSettings.driftedDays);
      }
      // v15: as formas de pagamento aceitas viraram ajuste.
      if (from < 15) {
        await m.addColumn(shopSettings, shopSettings.acceptedPayments);
      }
      // v16: lancamento de balcao passou a se declarar, em vez de ser
      // adivinhado pela falta de cliente.
      if (from < 16) {
        await m.addColumn(appointments, appointments.walkIn);
        // O que ja estava gravado sem cliente era lancamento de balcao: era
        // assim que o app reconhecia um ate agora. Sem isto, tudo que foi
        // lancado antes desta versao deixaria de abrir para corrigir.
        await customStatement(
          'update appointments set walk_in = 1 where client_id is null',
        );
      }
      // v17: o cadastro da barbearia — nome, endereço e o @ do Instagram.
      if (from < 17) {
        await m.addColumn(shopSettings, shopSettings.shopName);
        await m.addColumn(shopSettings, shopSettings.shopAddress);
        await m.addColumn(shopSettings, shopSettings.shopInstagram);
      }
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
