import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/features/reports/presentation/cash_view_model.dart';
import 'package:mispar/src/shared/widgets/app_sheet.dart';

/// O recorte de tempo do caixa.
///
/// Rotulo tocavel com a setinha, igual ao mes na Agenda: e a mesma pergunta
/// ("que pedaco do tempo eu estou olhando?") e merece o mesmo controle. Sete
/// periodos nao cabem em pilulas sem virar fileira que rola — e uma pilula que
/// muda de largura quando vira intervalo escolhido quebra a fileira inteira.
class CashPeriodPicker extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(cashFilterChoiceProvider);

    return InkWell(
      onTap: () => _choose(context, ref),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                filter.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Symbols.expand_more_rounded,
              size: 18,
              weight: 500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final current = ref.read(cashFilterChoiceProvider).period;

    final chosen = await showOptionSheet<CashPeriod>(
      context,
      title: 'Que período?',
      current: current,
      options: [
        for (final period in CashPeriod.values)
          (value: period, label: period.label),
      ],
    );

    if (chosen == null || !context.mounted) return;

    if (chosen != CashPeriod.custom) {
      ref.read(cashFilterChoiceProvider.notifier).selectPeriod(chosen);
      return;
    }

    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Escolher período',
      saveText: 'Aplicar',
    );

    if (range == null) return;
    ref.read(cashFilterChoiceProvider.notifier).selectRange(range);
  }
}
