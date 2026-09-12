import 'package:flutter/material.dart';
import 'package:mispar/src/core/theme/app_colors.dart';

/// Segmentado compacto: todos os rotulos ficam visiveis o tempo todo.
///
/// Icone que alterna entre estados nao diz em qual voce esta nem o que vai
/// acontecer — obriga a tocar para descobrir.
///
/// **Compacto vale tambem para a caixa.** Onde a largura chega apertada — num
/// formulario, dentro de uma lista — a pilula esticava ate a borda e deixava
/// um rastro cinza depois da ultima opcao; com duas opcoes, metade da tela. O
/// `widthFactor` faz ela se medir pelos rotulos em qualquer lugar.
class SegmentedToggle<T> extends StatelessWidget {
  const new({
    required this.options,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<({T value, String label})> options;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(Dimens.pillRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              GestureDetector(
                onTap: () => onSelect(option.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: option.value == selected
                        ? colors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(Dimens.pillRadius),
                  ),
                  child: Text(
                    option.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: option.value == selected
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
