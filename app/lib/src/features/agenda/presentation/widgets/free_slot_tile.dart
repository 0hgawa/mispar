import 'package:flutter/material.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/domain/day_slot.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';

/// A vaga.
///
/// Preenchimento cinza em vez do branco do card: buraco na agenda tem que
/// parecer buraco, nao mais um item da lista.
///
/// Vaga que ja terminou continua na grade — e o que aconteceu com o dia — mas
/// para de convidar: tocar levaria a um formulario que nao teria horario
/// nenhum para oferecer.
class FreeSlotTile extends StatelessWidget {
  const new(this.slot, {required this.onTap, super.key});

  final FreeSlot slot;

  /// Vaga e oportunidade: tocar leva direto para marcar.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isGone = slot.end.isBefore(DateTime.now());

    return Material(
      color: colors.secondaryContainer,
      borderRadius: BorderRadius.circular(Dimens.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isGone ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.cardPadding,
            vertical: 15,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatHour(slot.start)} — ${formatHour(slot.end)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                isGone
                    ? '${formatDuration(slot.end.difference(slot.start))} sem ninguém'
                    : '${formatDuration(slot.end.difference(slot.start))} livre',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isGone ? colors.onSurfaceVariant : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
