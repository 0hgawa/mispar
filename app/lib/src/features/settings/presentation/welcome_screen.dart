import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mispar/src/core/data/database/app_database.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/shared/widgets/sign_in_form.dart';

/// Onde a cópia na nuvem começa: a primeira abertura do app.
///
/// Existe porque backup escondido não protege ninguém. Enquanto entrar era só
/// um item no fim de Ajustes, a barbearia só tinha cópia se o Marcos fosse
/// procurar — e quem perde o celular é justamente quem nunca procurou.
///
/// **Uma vez só, e com saída.** Não é tranca: sem internet no dia em que ele
/// instalar, o app tem que abrir do mesmo jeito. Quem dispensa segue para a
/// agenda e pode entrar depois em Ajustes; a pergunta não volta.
class WelcomeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _working = false;

  Future<void> _later() async {
    setState(() => _working = true);
    await _marcar();
  }

  /// Guarda que a pergunta já foi feita.
  ///
  /// No banco, e não em memória: fechar o app e abrir de novo não pode trazer
  /// a mesma tela de volta para quem já respondeu.
  Future<void> _marcar() async {
    await ref
        .read(appDatabaseProvider)
        .into(ref.read(appDatabaseProvider).syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion.insert(
            id: const Value(1),
            welcomed: const Value(true),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text('Mispar', style: theme.textTheme.displaySmall),
              const SizedBox(height: Dimens.gapSmall),
              Text(
                'Entre para a sua barbearia ter cópia no servidor. Celular '
                'quebrado, celular novo: você entra de novo e volta tudo — '
                'agenda, clientes e caixa.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Dimens.gapLarge),
              SignInForm(
                onDone: _marcar,
                onBusy: (busy) => setState(() => _working = busy),
              ),
              const SizedBox(height: Dimens.gapMedium),
              TextButton(
                onPressed: _working ? null : () => unawaited(_later()),
                child: const Text('Agora não'),
              ),
              const Spacer(),
              Text(
                'Sem conta o app funciona igual, só não tem cópia. Dá para '
                'entrar depois em Ajustes.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Dimens.gapLarge),
            ],
          ),
        ),
      ),
    );
  }
}

/// Se a tela de entrada ainda tem que aparecer.
///
/// Some para sempre depois da primeira resposta — e nem chega a existir num
/// build sem servidor, onde não haveria onde entrar.
final needsWelcomeProvider = StreamProvider<bool>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final query = database.select(database.syncState)
    ..where((s) => s.id.equals(1));

  return query.watchSingleOrNull().map((linha) => !(linha?.welcomed ?? false));
});
