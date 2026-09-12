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
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _working = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _working = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _email.text, password: _password.text);
      if (!mounted) return;
      setState(() => _working = false);
      _password.clear();
      showSnack(context, 'Conectado. A cópia começa agora.');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      // A mensagem da Meta vem em inglês e fala de "credentials". Quem lê é o
      // barbeiro, e o que ele precisa saber é o que digitar de novo.
      showSnack(
        context,
        e.statusCode == '400'
            ? 'E-mail ou senha não conferem.'
            : 'Não consegui entrar. Tente de novo.',
      );
    } on Object {
      if (!mounted) return;
      setState(() => _working = false);
      showSnack(context, 'Sem internet para entrar agora.');
    }
  }

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
                  _SignInForm(
                    email: _email,
                    password: _password,
                    working: _working,
                    onIn: _signIn,
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

class _SignInForm extends StatelessWidget {
  const new({
    required this.email,
    required this.password,
    required this.working,
    required this.onIn,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool working;
  final Future<void> Function() onIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(
            controller: email,
            hint: 'seu@email.com',
            icon: Symbols.mail_rounded,
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: Dimens.gapSmall),
          _Field(
            controller: password,
            hint: 'senha',
            icon: Symbols.lock_rounded,
            obscure: true,
            onSubmit: onIn,
          ),
          const SizedBox(height: Dimens.gapLarge),
          FilledButton(
            onPressed: working ? null : () => unawaited(onIn()),
            child: working
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Entrar'),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatefulWidget {
  const new({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.obscure = false,
    this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboard;
  final bool obscure;
  final Future<void> Function()? onSubmit;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  /// Senha escondida por padrao, com o olho para conferir.
  ///
  /// Existe porque digitar senha no vidro do celular erra, e errar tres vezes
  /// sem ver o que se digitou e o jeito mais rapido de desistir do login. O
  /// padrao continua escondido: quem esta no balcao tem gente do outro lado.
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final controller = widget.controller;

    return TextField(
      controller: controller,
      keyboardType: widget.keyboard,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.obscure
          ? TextInputAction.done
          : TextInputAction.next,
      onSubmitted: (_) =>
          unawaited(widget.onSubmit?.call() ?? Future<void>.value()),
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        prefixIcon: Icon(
          widget.icon,
          weight: 500,
          color: colors.onSurfaceVariant,
        ),
        suffixIcon: widget.obscure
            ? IconButton(
                onPressed: () => setState(() => _hidden = !_hidden),
                tooltip: _hidden ? 'Mostrar senha' : 'Esconder senha',
                icon: Icon(
                  _hidden
                      ? Symbols.visibility_rounded
                      : Symbols.visibility_off_rounded,
                  weight: 500,
                  color: colors.onSurfaceVariant,
                ),
              )
            : null,
        filled: true,
        fillColor: colors.secondaryContainer,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.pillRadius),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
