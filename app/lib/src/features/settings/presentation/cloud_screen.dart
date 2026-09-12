import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/core/config/env.dart';
import 'package:mispar/src/core/data/remote/session.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/core/theme/status_colors.dart';
import 'package:mispar/src/shared/widgets/app_snack.dart';
import 'package:mispar/src/shared/widgets/page_bar.dart';
import 'package:mispar/src/shared/widgets/sign_in_form.dart';

/// A cópia da barbearia no servidor.
///
/// Entrar não é condição para usar o app — a agenda abre sem sinal e sem
/// conta. É o que liga a cópia: com ela, celular quebrado volta inteiro; sem
/// ela, tudo vive num arquivo só, dentro de um aparelho só.
class CloudScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CloudScreen> createState() => _CloudScreenState();
}

class _CloudScreenState extends ConsumerState<CloudScreen> {
  bool _working = false;

  Future<void> _signOut() async {
    setState(() => _working = true);
    await ref.read(authRepositoryProvider).signOut();
    if (!mounted) return;
    setState(() => _working = false);
    showSnack(context, 'Desconectado. O aparelho continua com tudo.');
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(signedInEmailProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const PageBar(title: 'Cópia na nuvem'),
          const SliverToBoxAdapter(
            child: PageSubtitle('para não perder tudo com o celular'),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
            sliver: SliverList.list(
              children: [
                const _Why(),
                if (!Env.hasBackend)
                  const _NoBackend()
                else if (email != null)
                  _Connected(email: email, working: _working, onOut: _signOut)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimens.screenGutter,
                    ),
                    child: SignInForm(
                      onBusy: (busy) => setState(() => _working = busy),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Why extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        0,
        Dimens.screenGutter,
        Dimens.gapSmall,
      ),
      child: Text(
        'A agenda, os clientes e o caixa vivem no seu celular. Conectado, eles '
        'sobem também para o servidor — e num aparelho novo você entra com '
        'e-mail e senha e volta tudo. O app continua funcionando sem internet '
        'de qualquer jeito.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Build sem chaves: a tela existe, mas não tem para onde apontar.
class _NoBackend extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(Dimens.screenGutter),
      child: Text(
        'Este aplicativo foi gerado sem servidor. Ele grava tudo no aparelho e '
        'não tem para onde copiar.',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.status.alert),
      ),
    );
  }
}

class _Connected extends StatelessWidget {
  const new({required this.email, required this.working, required this.onOut});

  final String email;
  final bool working;
  final Future<void> Function() onOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Symbols.cloud_done_rounded,
                weight: 500,
                color: colors.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Conectado', style: theme.textTheme.bodyLarge),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimens.gapLarge),
          OutlinedButton(
            onPressed: working ? null : () => unawaited(onOut()),
            child: const Text('Sair da conta'),
          ),
          const SizedBox(height: Dimens.gapSmall),
          Text(
            'Sair não apaga nada do celular.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
