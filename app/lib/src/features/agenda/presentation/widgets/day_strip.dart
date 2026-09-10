import 'package:flutter/material.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/presentation/day_view_model.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';

/// Regua de dias do topo.
///
/// Duas semanas a frente, comecando hoje. O dia escolhido fica **claro com
/// contorno grosso**, nao preenchido de preto: e assim que a referencia marca
/// a selecao, e o numero continua legivel.
class DayStrip extends StatefulWidget {
  const new({required this.selected, required this.onSelect, super.key});

  /// Recebe o dia por parametro em vez de ler o provider: a tela de marcar
  /// escolhe um dia sem mexer no que a agenda esta mostrando por tras.
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  static const _cellWidth = 58.0;
  static const _cellHeight = 66.0;

  @override
  State<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<DayStrip> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  @override
  void didUpdateWidget(DayStrip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _revealSelected();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Rola ate o dia escolhido aparecer.
  ///
  /// Sem isto a regua guarda a rolagem antiga e o titulo diz um dia enquanto a
  /// regua mostra outro.
  void _revealSelected() {
    if (!_controller.hasClients) return;
    final index = widget.selected.difference(_first).inDays;
    if (index < 0) return;

    const cell = DayStrip._cellWidth + Dimens.gapSmall;
    // Deixa uma celula de folga a esquerda, para nao colar na borda.
    final target = (index * cell - cell).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  DateTime get _first {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonday = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    final lastShown = thisMonday.add(const Duration(days: kDayStripLength));
    final selected = widget.selected;
    final isWithinDefault =
        !selected.isBefore(thisMonday) && selected.isBefore(lastShown);

    return isWithinDefault
        ? thisMonday
        : selected.subtract(Duration(days: selected.weekday - DateTime.monday));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final first = _first;

    return SizedBox(
      height: DayStrip._cellHeight + Dimens.gapLarge,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          Dimens.screenGutter,
          0,
          Dimens.screenGutter,
          Dimens.gapLarge,
        ),
        itemCount: kDayStripLength,
        separatorBuilder: (_, _) => const SizedBox(width: Dimens.gapSmall),
        itemBuilder: (context, index) {
          final day = first.add(Duration(days: index));
          return _DayCell(
            day: day,
            isSelected: day == widget.selected,
            isToday: day == today,
            onTap: () => widget.onSelect(day),
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const new({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isClosed = day.weekday == DateTime.sunday;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: DayStrip._cellWidth,
        height: DayStrip._cellHeight,
        decoration: BoxDecoration(
          color: isSelected
              ? colors.surfaceContainer
              : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(Dimens.cardRadius),
          border: isSelected
              ? Border.all(color: colors.onSurface, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatShortWeekday(day),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '${day.day}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 18,
                // Domingo fechado nao some da regua, so recua.
                color: isClosed ? colors.onSurfaceVariant : colors.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            // Ponto embaixo do dia de hoje, para ele nunca se perder na regua.
            SizedBox(
              height: 6,
              child: isToday && !isSelected
                  ? Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: colors.onSurface,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
