import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/core/data/remote/session.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/shared/widgets/app_snack.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// E-mail, senha e o botão de entrar.
///
/// Um componente só porque a mesma pergunta aparece em dois lugares: na
/// primeira abertura e em Ajustes. Duas cópias do mesmo formulário viram duas
/// mensagens de erro diferentes para o mesmo engano de senha.
class SignInForm extends ConsumerStatefulWidget {
  const new({this.onDone, this.onBusy, super.key});

  /// Chamado depois de entrar. A tela de boas-vindas usa para se despedir.
  final Future<void> Function()? onDone;

  /// Avisa quem está em volta para desabilitar os próprios botões enquanto a
  /// rede responde.
  final ValueChanged<bool>? onBusy;

  @override
  ConsumerState<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<SignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _working = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _busy({required bool value}) {
    setState(() => _working = value);
    widget.onBusy?.call(value);
  }

  Future<void> _signIn() async {
    _busy(value: true);

    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _email.text, password: _password.text);

      await widget.onDone?.call();
      if (!mounted) return;
      _busy(value: false);
      _password.clear();
      showSnack(context, 'Conectado. A cópia começa agora.');
    } on AuthException catch (e) {
      if (!mounted) return;
      _busy(value: false);
      // A mensagem do Supabase vem em inglês e fala de "credentials". Quem lê
      // é o barbeiro, e o que ele precisa saber é o que digitar de novo.
      showSnack(
        context,
        e.statusCode == '400'
            ? 'E-mail ou senha não conferem.'
            : 'Não consegui entrar. Tente de novo.',
      );
    } on Object {
      if (!mounted) return;
      _busy(value: false);
      showSnack(context, 'Sem internet para entrar agora.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          controller: _email,
          hint: 'seu@email.com',
          icon: Symbols.mail_rounded,
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: Dimens.gapSmall),
        _Field(
          controller: _password,
          hint: 'senha',
          icon: Symbols.lock_rounded,
          obscure: true,
          onSubmit: _signIn,
        ),
        const SizedBox(height: Dimens.gapLarge),
        FilledButton(
          onPressed: _working ? null : () => unawaited(_signIn()),
          child: _working
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Entrar'),
        ),
      ],
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
  /// Senha escondida por padrão, com o olho para conferir.
  ///
  /// Existe porque digitar senha no vidro do celular erra, e errar três vezes
  /// sem ver o que se digitou é o jeito mais rápido de desistir do login. O
  /// padrão continua escondido: quem está no balcão tem gente do outro lado.
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return TextField(
      controller: widget.controller,
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
