import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mispar/src/app.dart';
import 'package:mispar/src/core/config/env.dart';
import 'package:mispar/src/core/data/database/app_database.dart';
import 'package:mispar/src/core/data/database/seed.dart';
import 'package:mispar/src/core/data/remote/session.dart';
import 'package:mispar/src/core/data/sync/agenda_sync.dart';
import 'package:mispar/src/features/reports/data/expense_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  // As barras do sistema somem no fundo da tela: a cor da pagina vai de ponta
  // a ponta, como na referencia.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // O banco local abre antes da arvore de providers: nenhuma tela espera
  // arquivo, e a agenda aparece mesmo sem sinal.
  final database = AppDatabase();
  await seedDatabase(database);

  // O aluguel do mes novo entra sozinho: e o unico jeito de o lucro estar
  // certo sem o Marcos ter que lembrar de digitar todo dia primeiro.
  await ExpenseRepository(database).catchUpRecurring(DateTime.now());

  if (Env.hasBackend) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  }

  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
  );

  // A copia anda com a sessao, e nao com o app.
  //
  // Sem login o app e `anon`, e `anon` nao le nada — e de proposito: a chave
  // publicavel viaja dentro do APK, e sozinha ela nao pode valer a agenda
  // inteira. Comecar a sincronia antes de entrar so gastaria bateria pedindo
  // 401.
  //
  // `fireImmediately` porque o Supabase devolve a sessao ja guardada no
  // aparelho no primeiro evento: quem entrou ontem nao entra de novo hoje.
  if (Env.hasBackend) {
    container.listen(sessionProvider, (_, session) {
      final sync = container.read(agendaSyncProvider);
      unawaited(session.value == null ? sync.dispose() : sync.start());
    }, fireImmediately: true);
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const MisparApp()),
  );
}
