import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marcos_barber/src/core/router/app_router.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/core/theme/status_colors.dart';
import 'package:marcos_barber/src/features/reports/domain/cash_csv.dart';
import 'package:marcos_barber/src/features/reports/presentation/cash_view_model.dart';
import 'package:marcos_barber/src/features/reports/presentation/widgets/cash_period_picker.dart';
import 'package:marcos_barber/src/features/reports/presentation/widgets/profit_chart.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/widgets/app_card.dart';
import 'package:marcos_barber/src/shared/widgets/app_snack.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// O painel do dinheiro: só número e porta.
///
/// A pergunta que o Marcos faz não é "quanto faturei", é **"quanto sobrou"** —
/// por isso ela é o número grande, e não mais uma linha no meio da tela.
///
/// Extrato não mora aqui. Entrou e Saiu são cartões que **abrem** a tela
/// daquele lado, onde ficam o detalhamento e a lista. Painel e extrato na
/// mesma tela era o que fazia a aba parecer relatório.
class CashScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
          children: const [
            _Header(),
            SizedBox(height: Dimens.gapLarge),
            _Left(),
            SizedBox(height: Dimens.gapLarge),
            _Doors(),
            ProfitChart(),
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        12,
        Dimens.gapSmall,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Caixa', style: theme.textTheme.headlineMedium),
              ),
              IconButton(
                icon: const Icon(Symbols.ios_share_rounded, weight: 500),
                tooltip: 'Exportar o período',
                onPressed: () => _export(context, ref),
              ),
            ],
          ),
          const CashPeriodPicker(),
        ],
      ),
    );
  }

  /// Uma planilha do periodo, entradas e saidas na mesma tabela.
  ///
  /// E o que o contador pede, e o que evita o Marcos ter que copiar numero a
  /// numero no fim do ano.
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final report = ref.read(cashReportProvider).value;
    final spent = ref.read(spentReportProvider).value;

    if (report == null || spent == null) return;
    if (report.entries.isEmpty && spent.expenses.isEmpty) {
      showSnack(context, 'Nada para exportar neste período.');
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
      // Depois do await a tela pode ter saido: sem a guarda, o aviso
      // procuraria um Scaffold que nao existe mais.
      if (!context.mounted) return;
      showSnack(context, 'Não consegui gerar a planilha.');
    }
  }
}

/// O numero que resume o periodo, sozinho e grande.
///
/// Sem cartao em volta de proposito: o que se le fica no fundo, o que se toca
/// fica em cartao. E a diferenca que diz qual dos dois e qual.
class _Left extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final earned = ref.watch(cashReportProvider).value?.earnedCents ?? 0;
    final spent = ref.watch(spentReportProvider).value?.totalCents ?? 0;
    final left = earned - spent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // Negativo nao e "sobrou": o periodo fechou no vermelho.
            left >= 0 ? 'Sobrou' : 'Faltou',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            formatMoney(left.abs()),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.displaySmall?.copyWith(
              color: left >= 0
                  ? theme.colorScheme.onSurface
                  : theme.status.alert,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const _AgainstLastPeriod(),
        ],
      ),
    );
  }
}

/// Como este periodo esta contra o de tras.
///
/// Um numero sozinho nao diz se o mes esta bom: R$ 4.000 e otimo depois de
/// R$ 3.000 e ruim depois de R$ 6.000. A janela de tras vem recortada no mesmo
/// ponto — dez dias de setembro contra dez dias de agosto, nunca contra o mes
/// inteiro.
class _AgainstLastPeriod extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final label = ref.watch(cashFilterChoiceProvider).previousLabel;
    if (label == null) return const SizedBox.shrink();

    final before = ref.watch(previousPeriodProvider).value;
    if (before == null) return const SizedBox.shrink();

    final earned = ref.watch(cashReportProvider).value?.earnedCents ?? 0;
    final spent = ref.watch(spentReportProvider).value?.totalCents ?? 0;

    final change = percentChange(
      before: before.earnedCents - before.spentCents,
      now: earned - spent,
    );
    if (change == null || change == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
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

/// Os dois lados da conta, cada um a uma porta de distancia.
class _Doors extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(cashReportProvider).value;
    final spent = ref.watch(spentReportProvider).value;

    final served = report?.servedCount ?? 0;
    final booked = report?.bookedCount ?? 0;
    final expected = report?.expectedCents ?? 0;
    final lanced = spent?.expenses.length ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Door(
                label: 'Entrou',
                cents: report?.earnedCents ?? 0,
                // O que esta marcado e a noticia mais util deste lado: e o que
                // ainda pode entrar antes do periodo fechar.
                note: expected > 0
                    ? '+ ${formatMoney(expected)} a receber, em $booked '
                          '${booked == 1 ? 'horário' : 'horários'}'
                    : served == 1
                    ? '1 atendimento'
                    : '$served atendimentos',
                onTap: () => context.push(Routes.earned),
              ),
            ),
            const SizedBox(width: Dimens.cardGap),
            Expanded(
              child: _Door(
                label: 'Saiu',
                cents: spent?.totalCents ?? 0,
                note: lanced == 1 ? '1 lançamento' : '$lanced lançamentos',
                onTap: () => context.push(Routes.spent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Door extends StatelessWidget {
  const new({
    required this.label,
    required this.cents,
    required this.note,
    required this.onTap,
  });

  final String label;
  final int cents;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                Symbols.chevron_right_rounded,
                size: 18,
                weight: 600,
                color: colors.onSurfaceVariant,
              ),
            ],
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
          const SizedBox(height: 4),
          Text(
            note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
