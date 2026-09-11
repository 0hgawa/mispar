import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/reports/domain/cash_days.dart';
import 'package:marcos_barber/src/features/reports/presentation/cash_view_model.dart';
import 'package:marcos_barber/src/features/reports/presentation/widgets/money_stats.dart';
import 'package:marcos_barber/src/features/reports/presentation/widgets/tally_row.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:marcos_barber/src/shared/widgets/empty_state.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:marcos_barber/src/shared/widgets/segmented_toggle.dart';
import 'package:material_symbols_icons/symbols.dart';

/// O que entrou, e de onde veio.
///
/// A tela é **cronológica**: o dinheiro que entra vem em muitos pedaços
/// pequenos, vários no mesmo dia, e a pergunta que se faz dele é "como foi o
/// sábado". Por isso a lista é agrupada por dia, com o total do dia ao lado.
/// A tela de saída é o contrário — lá são poucos lançamentos e o que importa é
/// a natureza deles, não a data.
///
/// Uma regra manda aqui: **faturado é só o que foi concluído**. O que está
/// marcado aparece à parte, como "a receber" — somar os dois faria o Marcos
/// achar que ganhou dinheiro que ainda está por vir.
class EarnedScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded, weight: 500),
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AsyncView(
        value: ref.watch(cashReportProvider),
        onRetry: () => ref.invalidate(cashReportProvider),
        builder: (report) => _Body(report: report),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const new({required this.report});

  final CashReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final period = ref.watch(cashFilterChoiceProvider).label;
    final breakdown = ref.watch(cashBreakdownChoiceProvider);

    if (report.isEmpty) {
      return Column(
        children: [
          ScreenTitle(title: 'Entrou', subtitle: period),
          const Expanded(
            child: EmptyState(
              icon: Symbols.account_balance_wallet_rounded,
              title: 'Nada entrou neste período',
              message: 'Escolha outro período.',
            ),
          ),
        ],
      );
    }

    final days = byDay(
      report.entries,
      when: (entry) => entry.startsAt,
      cents: (entry) => entry.priceCents,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: Dimens.gapLarge * 2),
      children: [
        ScreenTitle(title: 'Entrou', subtitle: period),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
          child: Text(
            formatMoney(report.earnedCents),
            style: theme.textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: Dimens.gapLarge),
        MoneyStats(
          stats: [
            (
              value: '${report.servedCount}',
              label: report.servedCount == 1 ? 'atendimento' : 'atendimentos',
              isAlert: false,
            ),
            (
              value: formatMoney(report.averageTicketCents),
              label: 'ticket médio',
              isAlert: false,
            ),
            // Sem falta no periodo nao ha o que mostrar: "R$ 0 perdido em 0
            // faltas" ocupa a mesma area e nao diz nada.
            if (report.noShowCount > 0)
              (
                value: formatMoney(report.lostCents),
                label: report.noShowCount == 1
                    ? 'perdido em 1 falta'
                    : 'perdido em ${report.noShowCount} faltas',
                isAlert: true,
              ),
          ],
        ),
        if (report.expectedCents > 0) _ToCome(report: report),
        // Uma forma de pagamento so nao e detalhamento: a barra iria a 100%
        // dizendo o que o numero de cima ja disse.
        if (report.byPayment.length > 1) ...[
          const SectionLabel('Como te pagaram'),
          for (final tally in report.byPayment)
            TallyRow(tally: tally, total: report.earnedCents),
        ],
        const SectionLabel('De onde veio'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.screenGutter,
            0,
            Dimens.screenGutter,
            Dimens.gapSmall,
          ),
          child: SegmentedToggle(
            options: [
              for (final option in CashBreakdown.values)
                (value: option, label: option.label),
            ],
            selected: breakdown,
            onSelect: ref.read(cashBreakdownChoiceProvider.notifier).select,
          ),
        ),
        if (report.entries.isEmpty)
          const _NothingDoneYet()
        else ...[
          for (final tally in report.tallies(breakdown))
            TallyRow(tally: tally, total: report.earnedCents),
          const SectionLabel('Dia a dia'),
          for (final day in days) _Day(day: day),
        ],
      ],
    );
  }
}

/// O que esta marcado e ainda nao aconteceu.
///
/// Fora da fileira de numeros de proposito: nao e faturamento, e promessa. A
/// faixa separa as duas coisas sem precisar escrever isso.
class _ToCome extends StatelessWidget {
  const new({required this.report});

  final CashReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        Dimens.gapLarge,
        Dimens.screenGutter,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(Dimens.cardRadius),
        ),
        child: Row(
          children: [
            Icon(
              Symbols.schedule_rounded,
              size: 20,
              weight: 500,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ainda por vir: ${formatMoney(report.expectedCents)} '
                'em ${report.bookedCount} '
                '${report.bookedCount == 1 ? 'horário marcado' : 'horários marcados'}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
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

/// Um dia de trabalho: o cabecalho com o total, e os atendimentos embaixo.
class _Day extends StatelessWidget {
  const new({required this.day});

  final DayTake<Appointment> day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.screenGutter,
            Dimens.gapMedium,
            Dimens.screenGutter,
            6,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  formatDayHeading(day.day),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                formatMoney(day.totalCents),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        for (final appointment in day.items) _EntryRow(appointment: appointment),
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
              formatHour(appointment.startsAt),
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
            appointment.paidWith == null
                ? appointment.service.name
                : '${appointment.service.name} · ${appointment.paidWith!.label}',
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
