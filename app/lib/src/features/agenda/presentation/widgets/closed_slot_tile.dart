import 'package:flutter/material.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/domain/day_slot.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';

/// Uma faixa fechada — feriado, médico, viagem.
///
/// Aparece na grade em vez de virar buraco: horário que some sem explicação
/// vira dúvida, e daqui a uma semana ninguém lembra por que a tarde estava
/// vazia.
class ClosedSlotTile extends StatelessWidget {
  const new(this.slot, {super.key});

  final BlockedSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.cardPadding),
      height: 52,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(Dimens.cardRadius),
      ),
      child: Row(
        children: [
          Icon(Icons.block_rounded, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: Dimens.gapSmall),
          Text(
            '${formatHour(slot.start)} — ${formatHour(slot.end)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              slot.reason ?? 'Fechado',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
