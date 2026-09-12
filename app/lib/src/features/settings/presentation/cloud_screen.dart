import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/core/config/env.dart';
import 'package:mispar/src/core/data/database/backup.dart';
import 'package:mispar/src/core/data/database/restore.dart';
import 'package:mispar/src/core/data/remote/session.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/core/theme/status_colors.dart';
import 'package:mispar/src/shared/widgets/app_snack.dart';
import 'package:mispar/src/shared/widgets/confirm.dart';
import 'package:mispar/src/shared/widgets/page_bar.dart';
import 'package:mispar/src/shared/widgets/screen_title.dart';
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
                const _Arquivo(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A cópia que não depende de servidor nenhum.
///
/// A nuvem já copia sozinha, e é ela que devolve a barbearia num celular novo.
/// Este arquivo cobre o que ela não cobre: projeto pausado por inatividade,
/// conta perdida, ou o dono querendo os próprios dados fora de um serviço de
/// terceiro. Uma cópia que depende de a empresa continuar de pé não deveria
/// ser a única.
class _Arquivo extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_Arquivo> createState() => _ArquivoState();
}

class _ArquivoState extends ConsumerState<_Arquivo> {
  bool _working = false;

  /// Volta o aparelho para o que estava na cópia escolhida.
  ///
  /// Pergunta antes, e a pergunta diz o que se perde: isto substitui, não
  /// junta. Misturar as duas daria uma terceira barbearia, que nunca existiu.
  Future<void> _restore() async {
    final restore = ref.read(restoreProvider);

    final arquivo = await restore.pick();
    if (arquivo == null || !mounted) return;

    final confirmado = await askToConfirm(
      context,
      title: 'Voltar para esta cópia?',
      message:
          'A agenda, os clientes e o caixa que estão neste celular agora são '
          'substituídos pelo que está no arquivo. Não dá para desfazer.',
      // "Substituir" e nao "Voltar": o botao de cancelar ja se chama Voltar, e
      // os dois lado a lado com a mesma palavra pediam para o dedo errar
      // justamente na acao que nao se desfaz.
      confirmLabel: 'Substituir',
    );
    if (!confirmado || !mounted) return;

    setState(() => _working = true);
    try {
      await restore.from(arquivo);
      if (!mounted) return;
      showSnack(context, 'Pronto. O aparelho voltou para a cópia.');
    } on Object {
      if (!mounted) return;
      showSnack(context, 'Não consegui ler esse arquivo.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _share() async {
    setState(() => _working = true);
    try {
      await ref.read(backupProvider).share();
    } on Object {
      if (!mounted) return;
      showSnack(context, 'Não consegui gerar a cópia.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        Dimens.gapLarge * 2,
        Dimens.screenGutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Cópia em arquivo'),
          Text(
            'Gera um arquivo com tudo que está no aparelho e abre o '
            'compartilhar — mande para o seu WhatsApp, para o Drive, onde '
            'quiser. É a cópia que continua sua mesmo que este servidor saia '
            'do ar.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Dimens.gapMedium),
          OutlinedButton.icon(
            onPressed: _working ? null : () => unawaited(_share()),
            icon: const Icon(Symbols.download_rounded, size: 18, weight: 500),
            label: const Text('Guardar uma cópia'),
          ),
          const SizedBox(height: Dimens.gapSmall),
          TextButton(
            onPressed: _working ? null : () => unawaited(_restore()),
            style: TextButton.styleFrom(foregroundColor: theme.status.alert),
            child: const Text('Voltar de uma cópia'),
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
