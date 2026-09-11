import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/reports/domain/expense.dart';
import 'package:marcos_barber/src/features/reports/presentation/cash_view_model.dart';
import 'package:marcos_barber/src/features/reports/presentation/expense_form.dart';
import 'package:marcos_barber/src/features/reports/presentation/widgets/money_heading.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:marcos_barber/src/shared/widgets/empty_state.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:material_symbols_icons/symbols.dart';

/// O extrato do que saiu.
///
/// Mesma ideia da tela do Entrou — uma lista, não um relatório —, mas com
/// outro corte: **o que volta todo mês, e o que não volta**. Despesa não se
/// agrupa por dia como atendimento; são poucas, e a pergunta delas é se vão
/// aparecer de novo. O que se repete é o piso da barbearia.
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
    final count = spent.expenses.length;

    return ListView(
      // Espaco para o botao redondo nao tapar a ultima linha.
      padding: const EdgeInsets.only(bottom: 92),
      children: [
        ScreenTitle(title: 'Saiu', subtitle: period),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatMoney(spent.totalCents),
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 2),
              Text(
                count == 1 ? '1 despesa' : '$count despesas',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
        // Com um grupo so, o cabecalho repetiria o total de cima. A lista
        // entra direto.
        if (fixed.isEmpty || loose.isEmpty)
          for (final expense in spent.expenses) _Row(expense: expense)
        else ...[
          MoneyHeading(label: 'Todo mês', cents: spent.fixedCents),
          for (final expense in fixed) _Row(expense: expense),
          MoneyHeading(label: 'Só deste período', cents: spent.looseCents),
          for (final expense in loose) _Row(expense: expense),
        ],
      ],
    );
  }
}

/// Um gasto. Tocar abre o mesmo formulario, ja preenchido.
class _Row extends StatelessWidget {
  const new({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // O titulo ja diz o tipo quando nao ha nota; repetir seria uma linha
    // dizendo o que a de cima disse.
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
