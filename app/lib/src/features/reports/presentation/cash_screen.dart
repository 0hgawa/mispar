import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/core/theme/status_colors.dart';
import 'package:marcos_barber/src/features/reports/domain/cash_csv.dart';
import 'package:marcos_barber/src/features/reports/presentation/cash_view_model.dart';
import 'package:marcos_barber/src/features/reports/presentation/expense_form.dart';
import 'package:marcos_barber/src/features/reports/presentation/widgets/cash_period_chips.dart';
import 'package:marcos_barber/src/features/reports/presentation/widgets/earned_lane.dart';
import 'package:marcos_barber/src/features/reports/presentation/widgets/spent_lane.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// O dinheiro, dos dois lados.
///
/// Em cima, sempre visiveis: quanto entrou, quanto saiu e quanto sobrou. E a
/// pergunta que o Marcos faz — nao "quanto faturei", mas "quanto sobrou".
/// Tocar um dos dois numeros abre o detalhe daquele lado.
///
/// **Entrou** e **Saiu** sao listas diferentes de proposito: o que entra tem
/// cliente, servico e horario; o que sai tem tipo e nota. Misturar os dois num
/// controle so faria despesa parecer um tipo de receita.
class CashScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lane = ref.watch(cashLaneChoiceProvider);

    return Scaffold(
      // O botao so existe do lado de sair: e a unica coisa que se cadastra no
      // Caixa. Horario se marca na Agenda.
      floatingActionButton: lane == CashLane.spent
          ? FloatingActionButton(
              onPressed: () => ExpenseForm.show(context),
              tooltip: 'Lançar despesa',
              child: const Icon(Symbols.add_rounded, weight: 600, size: 28),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            const CashPeriodChips(),
            const SizedBox(height: Dimens.gapLarge),
            const _Summary(),
            const SizedBox(height: Dimens.gapLarge),
            Expanded(
              child: switch (lane) {
                CashLane.earned => const EarnedLane(),
                CashLane.spent => const SpentLane(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Titulo e a saida para o contador.
class _Header extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        const Expanded(child: ScreenTitle(title: 'Caixa')),
        Padding(
          padding: const EdgeInsets.only(right: Dimens.gapSmall),
          child: IconButton(
            icon: const Icon(Symbols.ios_share_rounded, weight: 500),
            tooltip: 'Exportar o período',
            onPressed: () => _export(context, ref),
          ),
        ),
      ],
    );
  }

  /// Uma planilha do periodo, entradas e saidas na mesma tabela.
  ///
  /// E o que o contador pede, e o que evita o Marcos ter que copiar numero a
  /// numero no fim do ano.
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final report = ref.read(cashReportProvider).value;
    final spent = ref.read(spentReportProvider).value;
    final messenger = ScaffoldMessenger.of(context);

    if (report == null || spent == null) return;
    if (report.entries.isEmpty && spent.expenses.isEmpty) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Nada para exportar neste período.')),
        );
      return;
    }

    final window = ref.read(cashFilterChoiceProvider).resolve();
    final name =
        'caixa-${window.from.year}-'
        '${window.from.month.toString().padLeft(2, '0')}-'
        '${window.from.day.toString().padLeft(2, '0')}.csv';

    try {
      final folder = await getTemporaryDirectory();
      final file = File('${folder.path}/$name');
      await file.writeAsString(
        cashCsv(earned: report.entries, spent: spent.expenses),
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Caixa da barbearia',
        ),
      );
    } on Object {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Não consegui gerar a planilha.')),
        );
    }
  }
}

/// Os dois lados e o resultado, sempre na tela.
///
/// Os cartoes sao o proprio seletor: o numero e o caminho para o detalhe dele,
/// entao nao precisa de um controle a parte dizendo a mesma coisa.
class _Summary extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lane = ref.watch(cashLaneChoiceProvider);
    final select = ref.read(cashLaneChoiceProvider.notifier).select;

    final earned = ref.watch(cashReportProvider).value?.earnedCents ?? 0;
    final spent = ref.watch(spentReportProvider).value?.totalCents ?? 0;
    final left = earned - spent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SideCard(
                  label: 'Entrou',
                  cents: earned,
                  isSelected: lane == CashLane.earned,
                  onTap: () => select(CashLane.earned),
                ),
              ),
              const SizedBox(width: Dimens.cardGap),
              Expanded(
                child: _SideCard(
                  label: 'Saiu',
                  cents: spent,
                  isSelected: lane == CashLane.spent,
                  onTap: () => select(CashLane.spent),
                ),
              ),
            ],
          ),
          // Sem despesa lancada, "sobrou" repetiria o numero da esquerda.
          if (spent > 0) ...[
            const SizedBox(height: Dimens.gapMedium),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    // Negativo nao e "sobrou": o periodo fechou no vermelho.
                    text: left >= 0 ? 'Sobrou ' : 'Faltou ',
                    style: theme.textTheme.titleMedium,
                  ),
                  TextSpan(
                    text: formatMoney(left.abs()),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: left >= 0
                          ? theme.colorScheme.onSurface
                          : theme.status.alert,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const _AgainstLastPeriod(),
        ],
      ),
    );
  }
}

/// Como este periodo esta contra o de tras.
///
/// Faturamento sozinho nao diz se o mes esta bom: R$ 4.000 e otimo depois de
/// R$ 3.000 e ruim depois de R$ 6.000.
class _AgainstLastPeriod extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final label = ref.watch(cashFilterChoiceProvider).previousLabel;
    if (label == null) return const SizedBox.shrink();

    final before = ref.watch(previousPeriodProvider).value;
    final now = ref.watch(cashReportProvider).value?.earnedCents ?? 0;
    if (before == null) return const SizedBox.shrink();

    final change = percentChange(before: before.earnedCents, now: now);
    if (change == null || change == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Dimens.gapSmall),
      child: Row(
        children: [
          Icon(
            change > 0
                ? Symbols.trending_up_rounded
                : Symbols.trending_down_rounded,
            size: 18,
            weight: 600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${change.abs()}% ${change > 0 ? 'a mais' : 'a menos'} $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  const new({
    required this.label,
    required this.cents,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int cents;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
        decoration: BoxDecoration(
          // Mesma marca de selecao da regua de dias: claro com contorno, para
          // o numero continuar legivel dos dois lados.
          color: isSelected
              ? colors.surfaceContainer
              : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(Dimens.cardRadius),
          border: isSelected
              ? Border.all(color: colors.onSurface, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatMoney(cents),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 26,
                letterSpacing: -0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
