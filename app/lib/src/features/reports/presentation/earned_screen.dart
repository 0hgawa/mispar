import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/core/theme/status_colors.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/agenda/presentation/widgets/appointment_sheet.dart';
import 'package:marcos_barber/src/features/reports/domain/cash_days.dart';
import 'package:marcos_barber/src/features/reports/presentation/cash_view_model.dart';
import 'package:marcos_barber/src/features/reports/presentation/income_form.dart';
import 'package:marcos_barber/src/features/reports/presentation/widgets/money_heading.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:marcos_barber/src/shared/widgets/empty_state.dart';
import 'package:marcos_barber/src/shared/widgets/page_bar.dart';
import 'package:material_symbols_icons/symbols.dart';

/// O extrato do que entrou, dia a dia.
///
/// **É uma lista, não um relatório.** O painel já responde quanto entrou; aqui
/// a pergunta é outra — *de onde saiu esse número* — e quem responde é a
/// lista, com o total de cada dia ao lado do dia.
///
/// O que o painel já mostra não se repete aqui, e número que é conta de outro
/// número não entra: ticket médio é o total dividido pela contagem, e os dois
/// já estão na tela.
class EarnedScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => IncomeForm.show(context),
        tooltip: 'Lançar receita',
        child: const Icon(Symbols.add_rounded, weight: 600, size: 28),
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

    if (report.entries.isEmpty) {
      return CustomScrollView(
        slivers: [
          const PageBar(title: 'Entrou'),
          SliverToBoxAdapter(child: PageSubtitle(period)),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Symbols.account_balance_wallet_rounded,
              title: 'Nada entrou neste período',
              message: 'Escolha outro período, ou lance um atendimento.',
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

    return CustomScrollView(
      slivers: [
        const PageBar(title: 'Entrou'),
        SliverToBoxAdapter(child: PageSubtitle(period)),
        SliverPadding(
          // Espaco para o botao redondo nao tapar a ultima linha.
          padding: const EdgeInsets.only(bottom: 92),
          sliver: SliverList.list(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimens.screenGutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatMoney(report.earnedCents),
                      style: theme.textTheme.displayLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(_counted(report), style: theme.textTheme.titleMedium),
                    // Falta nao entra na soma, e e a unica coisa desta tela que o
                    // total nao conta. Uma linha, e so quando aconteceu.
                    if (report.noShowCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${formatMoney(report.lostCents)} perdidos em '
                        '${report.noShowCount == 1 ? '1 falta' : '${report.noShowCount} faltas'}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.status.alert,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              for (final day in days) ...[
                MoneyHeading(
                  label: formatDayHeading(day.day),
                  cents: day.totalCents,
                ),
                for (final appointment in day.items)
                  _Row(appointment: appointment),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "3 atendimentos · 1 venda" — e so o que houve.
///
/// Venda de produto contada como atendimento seria dizer que alguem sentou na
/// cadeira para comprar pomada. Separada quando nao houve nenhuma, seria um
/// zero ocupando espaco.
String _counted(CashReport report) {
  final served = report.servedCount;
  final sold = report.soldCount;

  final parts = <String>[];
  // Sem venda nenhuma, o zero de atendimentos ainda precisa aparecer: "0
  // atendimentos" e a resposta, e a lista vazia nao chega aqui.
  if (served > 0 || sold == 0) {
    parts.add(served == 1 ? '1 atendimento' : '$served atendimentos');
  }
  if (sold > 0) {
    parts.add(sold == 1 ? '1 venda' : '$sold vendas');
  }

  return parts.join(' · ');
}

/// Um atendimento do dia: hora, quem, o que, e quanto.
class _Row extends StatelessWidget {
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
          // O que foi digitado abre o formulário que o criou — o mesmo
          // caminho da despesa no Saiu. O que veio da agenda abre a folha do
          // horário, porque ali a pergunta é outra: concluir, remarcar,
          // falta. Componente igual para tarefa igual.
          onTap: () => unawaited(
            appointment.isWalkIn
                ? IncomeForm.show(context, entry: appointment)
                : AppointmentSheet.show(context, appointment),
          ),
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
            appointment.who,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            appointment.paidWith == null
                ? appointment.service.name
                : '${appointment.service.name} · ${appointment.paidWith!.label}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
