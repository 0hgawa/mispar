import 'package:flutter/material.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';

/// Rodape das telas de tarefa: o botao principal, sempre no mesmo lugar.
///
/// Calcula o recuo da barra do sistema na mao em vez de confiar no `SafeArea`:
/// com o app desenhando de ponta a ponta, o `minimum` do SafeArea nem sempre
/// recebe o encaixe e o botao acaba colado nos botoes do Android.
class BottomAction extends StatelessWidget {
  const new({required this.child, this.caption, super.key});

  final Widget child;

  /// Linha curta acima do botao — resumo do que vai ser gravado.
  final Widget? caption;

  @override
  Widget build(BuildContext context) {
    final systemInset = MediaQuery.paddingOf(context).bottom;
    final caption = this.caption;

    return DecoratedBox(
      // O mesmo fundo da tela: a lista rola por baixo sem parecer buraco.
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Dimens.screenGutter,
          Dimens.gapMedium,
          Dimens.screenGutter,
          systemInset + Dimens.gapLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (caption != null) ...[
              caption,
              const SizedBox(height: Dimens.gapSmall),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
