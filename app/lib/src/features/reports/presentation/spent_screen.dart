import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/reports/domain/expense.dart';
import 'package:marcos_barber/src/features/reports/presentation/cash_view_model.dart';
import 'package:marcos_barber/src/features/reports/presentation/expense_form.dart';
import 'package:marcos_barber/src/features/reports/presentation/widgets/money_stats.dart';
import 'package:marcos_barber/src/features/reports/presentation/widgets/tally_row.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:marcos_barber/src/shared/widgets/empty_state.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:material_symbols_icons/symbols.dart';

/// O que saiu, e com o quê.
///
/// A tela é organizada **por natureza**, não por data: são poucos lançamentos
/// no mês, e a pergunta deles não é "que dia foi" — é *quanto disso volta no
/// mês que vem*. O que se repete é o piso da barbearia, o quanto ela precisa
/// faturar antes de sobrar alguma coisa.
///
/// É a única parte do Caixa onde se cadastra: por isso o botão redondo mora
/// aqui, e não na aba.
class SpentScreen extends ConsumerWidget {
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => ExpenseForm.show(context),
        tooltip: 'Lançar despesa',
        child: const Icon(Symbols.add_rounded, weight: 600, size: 28),
      ),
      body: AsyncView(
        value: ref.watch(spentReportProvider),
        onRetry: () => ref.invalidate(spentReportProvider),
        builder: (spent) => _Body(spent: spent),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const new({required this.spent});

  final SpentReport spent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final period = ref.watch(cashFilterChoiceProvider).label;

    if (spent.isEmpty) {
      return Column(
        children: [
          ScreenTitle(title: 'Saiu', subtitle: period),
          const Expanded(
            child: EmptyState(
              icon: Symbols.receipt_long_rounded,
              title: 'Nada saiu neste período',
              message:
                  'Lance o aluguel, os produtos, a maquininha. '
                  'Sem isso o Caixa mostra só metade da conta.',
            ),
          ),
        ],
      );
    }

    final fixed = spent.expenses.where((e) => e.repeatsMonthly).toList();
    final loose = spent.expenses.where((e) => !e.repeatsMonthly).toList();

    return ListView(
      // Espaco para o botao redondo nao tapar o ultimo lancamento.
      padding: const EdgeInsets.only(bottom: 92),
      children: [
        ScreenTitle(title: 'Saiu', subtitle: period),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
          child: Text(
            formatMoney(spent.totalCents),
            style: theme.textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: Dimens.gapLarge),
        MoneyStats(
          stats: [
            (
              value: '${spent.expenses.length}',
              label: spent.expenses.length == 1 ? 'lançamento' : 'lançamentos',
              isAlert: false,
            ),
            // Sem nenhuma despesa fixa nao ha divisao para mostrar: os dois
            // numeros seriam o total e zero.
            if (spent.fixedCents > 0) ...[
              (
                value: formatMoney(spent.fixedCents),
                label: 'todo mês',
                isAlert: false,
              ),
              (
                value: formatMoney(spent.looseCents),
                label: 'deste mês só',
                isAlert: false,
              ),
            ],
          ],
        ),
        // Um tipo so nao e detalhamento: a barra iria a 100% dizendo o que o
        // numero de cima ja disse.
        if (spent.byCategory.length > 1) ...[
          const SectionLabel('Com o quê'),
          for (final tally in spent.byCategory)
            TallyRow(tally: tally, total: spent.totalCents),
        ],
        if (fixed.isNotEmpty) ...[
          const SectionLabel('Todo mês'),
          for (final expense in fixed) _ExpenseRow(expense: expense),
        ],
        if (loose.isNotEmpty) ...[
          SectionLabel(fixed.isEmpty ? 'Lançamentos' : 'Só deste período'),
          for (final expense in loose) _ExpenseRow(expense: expense),
        ],
      ],
    );
  }
}

/// Um gasto. Tocar abre o mesmo formulario, ja preenchido.
class _ExpenseRow extends StatelessWidget {
  const new({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // O titulo ja diz o tipo quando nao ha nota. "Todo mes" nao entra: a
    // secao em que a linha esta ja disse isso.
    final hasNote = expense.title != expense.category.name;

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
          onTap: () => ExpenseForm.show(context, expense: expense),
          leading: SizedBox(
            width: 44,
            child: Text(
              formatShortDate(expense.spentAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          title: Text(
            expense.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: hasNote
              ? Text(
                  expense.category.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                )
              : null,
          trailing: Text(
            '− ${formatMoney(expense.cents)}',
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
