import 'package:flutter/material.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:material_symbols_icons/symbols.dart';

/// O dia do lançamento, tocável, logo abaixo do título.
///
/// Fica em cima porque o teclado abre sozinho e come a metade de baixo da
/// tela: data que o Marcos não vê na hora de confirmar é data que ele não
/// confere.
class DayButton extends StatelessWidget {
  const new({required this.day, required this.onTap, super.key});

  final DateTime day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;

    return Material(
      color: colors.secondaryContainer,
      borderRadius: BorderRadius.circular(Dimens.pillRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Symbols.calendar_today_rounded,
                size: 18,
                weight: 500,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                // "Hoje" e o caso de quase sempre, e e mais rapido de ler que
                // a data por extenso.
                isToday ? 'Hoje' : formatLongDay(day),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
