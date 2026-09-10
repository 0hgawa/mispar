import 'package:flutter/material.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';

/// Cabecalho das abas, no formato da referencia: titulo pesado alinhado a
/// esquerda com a informacao secundaria logo ao lado, na mesma linha de base.
class ScreenTitle extends StatelessWidget {
  const new({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        12,
        Dimens.screenGutter,
        Dimens.gapLarge,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: theme.textTheme.headlineMedium),
          if (subtitle != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rotulo que fica acima de um bloco de cards.
class SectionLabel extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        Dimens.gapLarge,
        Dimens.screenGutter,
        Dimens.gapSmall + 2,
      ),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
