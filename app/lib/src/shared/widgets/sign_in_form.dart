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

  /// Entrar é o padrão: quem abre esta tela quase sempre já tem conta — só
  /// o primeiro dia de cada barbearia é cadastro.
  bool _novo = false;

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

  Future<void> _enviar() async {
    // A senha curta é o engano mais comum do cadastro, e o Supabase devolve
    // isso em inglês falando de "password". Melhor dizer antes de ir à rede.
    if (_novo && _password.text.length < 6) {
      showSnack(context, 'A senha precisa de pelo menos 6 letras ou números.');
      return;
    }

    _busy(value: true);

    try {
      final auth = ref.read(authRepositoryProvider);

      if (_novo) {
        final entrou = await auth.signUp(
          email: _email.text,
          password: _password.text,
        );

        await widget.onDone?.call();
        if (!mounted) return;
        _busy(value: false);
        _password.clear();
        showSnack(
          context,
          entrou
              ? 'Conta criada. A cópia começa agora.'
              : 'Conta criada. Confirme o e-mail para entrar.',
        );
        return;
      }

      await auth.signIn(email: _email.text, password: _password.text);

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
      showSnack(context, switch (e.statusCode) {
        '400' when _novo => 'Esse e-mail não serve, ou já tem conta.',
        '400' => 'E-mail ou senha não conferem.',
        '422' => 'Já existe uma conta com esse e-mail.',
        // O servidor limita quantos e-mails de confirmação saem por hora.
        // Mandar "tente de novo" aqui é mandar bater na mesma porta: só o
        // tempo abre.
        '429' => 'Muitas contas criadas agora. Tente daqui a alguns minutos.',
        _ =>
          _novo
              ? 'Não consegui criar a conta. Tente de novo.'
              : 'Não consegui entrar. Tente de novo.',
      });
    } on Object {
      if (!mounted) return;
      _busy(value: false);
      showSnack(context, 'Sem internet agora.');
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
          onSubmit: _enviar,
        ),
        const SizedBox(height: Dimens.gapLarge),
        FilledButton(
          onPressed: _working ? null : () => unawaited(_enviar()),
          child: _working
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_novo ? 'Criar conta' : 'Entrar'),
        ),
        TextButton(
          onPressed: _working ? null : () => setState(() => _novo = !_novo),
          child: Text(_novo ? 'Já tenho conta' : 'Ainda não tenho conta'),
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
