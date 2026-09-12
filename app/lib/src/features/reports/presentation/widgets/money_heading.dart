import 'package:flutter/material.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/shared/formatters/money.dart';

/// Cabeçalho de um grupo do extrato: o nome do grupo e o que ele soma.
///
/// O total ao lado é o que faz o agrupamento valer a pena — sem ele, o
/// cabeçalho só empurra a lista para baixo.
class MoneyHeading extends StatelessWidget {
  const new({required this.label, required this.cents, super.key});

  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        Dimens.gapLarge,
        Dimens.screenGutter,
        6,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
          Text(
            formatMoney(cents),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
