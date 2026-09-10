import 'package:flutter/material.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/reports/presentation/cash_view_model.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';

/// Linha de detalhamento com barra de participacao.
///
/// Mostra de onde vem — ou para onde vai — o dinheiro sem precisar de
/// porcentagem escrita. Serve aos dois lados do Caixa.
class TallyRow extends StatelessWidget {
  const new({required this.tally, required this.total, super.key});

  final Tally tally;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final share = total == 0 ? 0.0 : tally.totalCents / total;

    return Column(
      children: [
        const Divider(
          height: 1,
          indent: Dimens.screenGutter,
          endIndent: Dimens.screenGutter,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.screenGutter,
            12,
            Dimens.screenGutter,
            12,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tally.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimens.gapSmall),
                  Text(
                    formatMoney(tally.totalCents),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: share,
                        minHeight: 5,
                        backgroundColor: colors.secondaryContainer,
                        valueColor: AlwaysStoppedAnimation(colors.onSurface),
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimens.gapMedium),
                  Text(
                    tally.count == 1 ? '1×' : '${tally.count}×',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
