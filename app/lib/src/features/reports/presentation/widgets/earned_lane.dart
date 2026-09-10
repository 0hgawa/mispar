import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/core/theme/status_colors.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/reports/presentation/cash_view_model.dart';
import 'package:marcos_barber/src/features/reports/presentation/widgets/tally_row.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:marcos_barber/src/shared/widgets/empty_state.dart';
import 'package:marcos_barber/src/shared/widgets/segmented_toggle.dart';
import 'package:material_symbols_icons/symbols.dart';

/// O que entrou, e de onde veio.
///
/// Uma regra manda aqui: **faturado e so o que foi concluido**. O que esta
/// marcado aparece separado, como "a receber" — somar os dois faria o Marcos
/// achar que ganhou dinheiro que ainda esta por vir.
class EarnedLane extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(cashReportProvider),
      onRetry: () => ref.invalidate(cashReportProvider),
      builder: (report) => _Earned(report: report),
    );
  }
}

class _Earned extends ConsumerWidget {
  const new({required this.report});

  final CashReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final breakdown = ref.watch(cashBreakdownChoiceProvider);

    if (report.isEmpty) {
      return const EmptyState(
        icon: Symbols.account_balance_wallet_rounded,
        title: 'Nada entrou neste período',
        message: 'Escolha outro período.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.servedCount == 1
                    ? '1 atendimento concluído'
                    : '${report.servedCount} atendimentos concluídos',
                style: theme.textTheme.titleMedium,
              ),
              if (report.expectedCents > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '+ ${formatMoney(report.expectedCents)} a receber, '
                  'em ${report.bookedCount} '
                  '${report.bookedCount == 1 ? 'horário marcado' : 'horários marcados'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Dimens.gapLarge),
        _Numbers(report: report),
        const SizedBox(height: Dimens.gapLarge),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
          child: SegmentedToggle(
            options: [
              for (final option in CashBreakdown.values)
                (value: option, label: option.label),
            ],
            selected: breakdown,
            onSelect: ref.read(cashBreakdownChoiceProvider.notifier).select,
          ),
        ),
        const SizedBox(height: Dimens.gapMedium),
        if (report.entries.isEmpty)
          const _NothingDoneYet()
        else if (breakdown == CashBreakdown.entries)
          for (final entry in report.entries) _EntryRow(appointment: entry)
        else
          for (final tally in report.tallies(breakdown))
            TallyRow(tally: tally, total: report.earnedCents),
      ],
    );
  }
}

/// O periodo so tem horario marcado, nada concluido. O numero de cima ja e
/// zero; isto explica por que a lista tambem esta.
class _NothingDoneYet extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.screenGutter,
        vertical: Dimens.gapSmall,
      ),
      child: Text(
        'Nenhum atendimento concluído neste período ainda.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Numbers extends StatelessWidget {
  const new({required this.report});

  final CashReport report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
      child: Row(
        children: [
          Expanded(
            child: _Number(
              value: formatMoney(report.averageTicketCents),
              label: 'ticket médio',
            ),
          ),
          // Sem falta no periodo nao ha o que mostrar: "R$ 0 perdido em 0
          // faltas" ocupa a mesma area e nao diz nada.
          if (report.noShowCount > 0)
            Expanded(
              child: _Number(
                value: formatMoney(report.lostCents),
                label: report.noShowCount == 1
                    ? 'perdido em 1 falta'
                    : 'perdido em ${report.noShowCount} faltas',
                isAlert: true,
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }
}

class _Number extends StatelessWidget {
  const new({required this.value, required this.label, this.isAlert = false});

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

/// Um atendimento que formou o total. Numero sem lista nao da para conferir.
class _EntryRow extends StatelessWidget {
  const new({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        const Divider(
          height: 1,
          indent: Dimens.screenGutter,
          endIndent: Dimens.screenGutter,
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Dimens.screenGutter,
            vertical: 2,
          ),
          leading: SizedBox(
            width: 44,
            child: Text(
              formatShortDate(appointment.startsAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          title: Text(
            appointment.client.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            appointment.service.name,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          trailing: Text(
            formatMoney(appointment.priceCents),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
