import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mispar/src/core/config/env.dart';
import 'package:mispar/src/core/data/remote/session.dart';
import 'package:mispar/src/core/router/app_router.dart';
import 'package:mispar/src/core/theme/app_theme.dart';
import 'package:mispar/src/features/settings/presentation/welcome_screen.dart';

class MisparApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Mispar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
      // A tela de entrada fica **por cima** do app, e não no lugar dele.
      //
      // Assim a agenda já está montada por baixo: responder a pergunta é a
      // folha saindo da frente, e não o app começando. E se o banco demorar a
      // dizer se a pergunta já foi feita, o que aparece é a agenda — nunca uma
      // tela de login piscando para quem já entrou ontem.
      builder: (context, child) => _Entrada(child: child),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

/// A pergunta da primeira abertura, por cima do app.
///
/// Só existe onde há servidor: num build sem chaves não haveria onde entrar, e
/// perguntar seria pedir uma senha que não abre nada.
class _Entrada extends ConsumerWidget {
  const new({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tela = child ?? const SizedBox.shrink();
    if (!Env.hasBackend) return tela;

    // Já entrou: não pergunta, nem enquanto o banco responde.
    final entrou = ref.watch(sessionProvider).value != null;
    final falta = ref.watch(needsWelcomeProvider).value ?? false;
    if (entrou || !falta) return tela;

    return const WelcomeScreen();
  }
}
