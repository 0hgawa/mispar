import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/reports/domain/expense.dart';
import 'package:marcos_barber/src/features/reports/presentation/cash_view_model.dart';
import 'package:marcos_barber/src/features/reports/presentation/expense_form.dart';
import 'package:marcos_barber/src/features/reports/presentation/widgets/tally_row.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:marcos_barber/src/shared/widgets/empty_state.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:material_symbols_icons/symbols.dart';

/// O que saiu, e com o quê.
class SpentLane extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(spentReportProvider),
      onRetry: () => ref.invalidate(spentReportProvider),
      builder: (spent) => spent.isEmpty
          ? const EmptyState(
              icon: Symbols.receipt_long_rounded,
              title: 'Nada saiu neste período',
              message:
                  'Lance o aluguel, os produtos, a maquininha. '
                  'Sem isso o Caixa mostra só metade da conta.',
            )
          : _Spent(spent: spent),
    );
  }
}

class _Spent extends StatelessWidget {
  const new({required this.spent});

  final SpentReport spent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = spent.expenses.length;

    return ListView(
      // Espaco para o botao redondo nao tapar o ultimo lancamento.
      padding: const EdgeInsets.only(bottom: 92),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
          child: Text(
            count == 1 ? '1 despesa lançada' : '$count despesas lançadas',
            style: theme.textTheme.titleMedium,
          ),
        ),
        // Um tipo so nao e detalhamento: a barra iria a 100% dizendo o que o
        // numero de cima ja disse.
        if (spent.byCategory.length > 1) ...[
          const SectionLabel('Com o quê'),
          for (final tally in spent.byCategory)
            TallyRow(tally: tally, total: spent.totalCents),
        ],
        const SectionLabel('Lançamentos'),
        for (final expense in spent.expenses) _ExpenseRow(expense: expense),
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

    // O titulo ja diz o tipo quando nao ha nota. A segunda linha so existe
    // para o que ela ainda tem a dizer: "todo mes" explica por que este
    // lancamento apareceu sem ninguem digitar.
    final hasNote = expense.title != expense.category.name;
    final subtitle = [
      if (hasNote) expense.category.name,
      if (expense.repeatsMonthly) 'todo mês',
    ].join(' · ');

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
          subtitle: subtitle.isEmpty
              ? null
              : Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
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
