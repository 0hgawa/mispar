import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/reports/presentation/cash_view_model.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';

/// O recorte de tempo do caixa. E a unica coisa que se escolhe aqui em cima.
class CashPeriodChips extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(cashFilterChoiceProvider);

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
        children: [
          for (final period in CashPeriod.values)
            Padding(
              padding: const EdgeInsets.only(right: Dimens.gapSmall),
              child: ChoiceChip(
                label: Text(_label(period, filter)),
                selected: period == filter.period,
                onSelected: (_) => period == CashPeriod.custom
                    ? _pickRange(context, ref)
                    : ref
                          .read(cashFilterChoiceProvider.notifier)
                          .selectPeriod(period),
              ),
            ),
        ],
      ),
    );
  }

  String _label(CashPeriod period, CashFilter filter) {
    final range = filter.range;
    if (period != CashPeriod.custom ||
        range == null ||
        filter.period != CashPeriod.custom) {
      return period.label;
    }
    return '${formatShortDate(range.start)} – ${formatShortDate(range.end)}';
  }

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final chosen = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Escolher período',
      saveText: 'Aplicar',
    );
    if (chosen == null) return;
    ref.read(cashFilterChoiceProvider.notifier).selectRange(chosen);
  }
}
