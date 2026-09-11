import 'package:flutter/material.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/core/theme/status_colors.dart';

/// Os números secundários de uma tela de dinheiro, lado a lado.
///
/// Ficam numa fileira só, sem cartão: são de leitura, não de toque. O que não
/// tem o que dizer no período simplesmente não entra — "R$ 0 perdido em 0
/// faltas" ocupa a mesma área e não informa nada.
class MoneyStats extends StatelessWidget {
  const new({required this.stats, super.key});

  final List<({String value, String label, bool isAlert})> stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final stat in stats)
            Expanded(
              child: _Stat(
                value: stat.value,
                label: stat.label,
                isAlert: stat.isAlert,
              ),
            ),
          // Com um ou dois numeros a fileira nao se estica: eles ficam onde
          // estariam se fossem tres, e a coluna da esquerda sempre alinha.
          for (var i = stats.length; i < 3; i++) const Spacer(),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const new({
    required this.value,
    required this.label,
    required this.isAlert,
  });

  final String value;
  final String label;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: isAlert ? theme.status.alert : theme.colorScheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
