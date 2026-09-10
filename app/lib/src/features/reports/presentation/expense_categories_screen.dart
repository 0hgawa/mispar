import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/reports/data/expense_category_repository.dart';
import 'package:marcos_barber/src/features/reports/domain/expense.dart';
import 'package:marcos_barber/src/features/reports/presentation/expense_category_form.dart';
import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Os tipos de gasto da barbearia.
///
/// Vem com os sete que qualquer barbearia tem, e sao so o ponto de partida:
/// contador, sindicato, uniforme — cada um lanca o que de fato paga.
class ExpenseCategoriesScreen extends ConsumerWidget {
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
        onPressed: () => ExpenseCategoryForm.show(context),
        tooltip: 'Novo tipo',
        child: const Icon(Symbols.add_rounded, weight: 600, size: 28),
      ),
      body: AsyncView(
        value: ref.watch(allExpenseCategoriesProvider),
        onRetry: () => ref.invalidate(allExpenseCategoriesProvider),
        builder: (categories) => ListView(
          // Espaco para o botao redondo nao tapar a ultima linha.
          padding: const EdgeInsets.only(bottom: 92),
          children: [
            const ScreenTitle(
              title: 'Despesas',
              subtitle: 'os tipos que você lança',
            ),
            for (final category in categories) _Row(category: category),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const new({required this.category});

  final ExpenseCategory category;

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
            vertical: 6,
          ),
          onTap: () => ExpenseCategoryForm.show(context, category: category),
          title: Text(
            category.name,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: category.isActive
                  ? colors.onSurface
                  : colors.onSurfaceVariant,
            ),
          ),
          trailing: category.isActive
              ? null
              : Text(
                  'aposentado',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
        ),
      ],
    );
  }
}
