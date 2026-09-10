import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/core/theme/status_colors.dart';
import 'package:marcos_barber/src/features/reports/data/expense_category_repository.dart';
import 'package:marcos_barber/src/features/reports/domain/expense.dart';
import 'package:marcos_barber/src/shared/formatters/text.dart';
import 'package:marcos_barber/src/shared/widgets/bottom_action.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Cadastrar ou corrigir um tipo de gasto.
class ExpenseCategoryForm extends ConsumerStatefulWidget {
  const new({this.category, super.key});

  final ExpenseCategory? category;

  static Future<void> show(BuildContext context, {ExpenseCategory? category}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseCategoryForm(category: category),
      ),
    );
  }

  @override
  ConsumerState<ExpenseCategoryForm> createState() =>
      _ExpenseCategoryFormState();
}

class _ExpenseCategoryFormState extends ConsumerState<ExpenseCategoryForm> {
  late final _name = TextEditingController(text: widget.category?.name ?? '');

  late bool _isActive = widget.category?.isActive ?? true;
  bool _saving = false;

  /// Quantos gastos usam este tipo. Nulo enquanto nao chegou.
  int? _usage;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    if (category == null) return;
    unawaited(
      ref.read(expenseCategoryRepositoryProvider).usageCount(category.id).then((
        count,
      ) {
        if (mounted) setState(() => _usage = count);
      }),
    );
  }

  bool get _isEditing => widget.category != null;

  bool get _isValid => _name.text.trim().length >= 2;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.close_rounded, weight: 500),
          tooltip: 'Fechar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
        children: [
          ScreenTitle(
            title: _isEditing ? 'Tipo de despesa' : 'Novo tipo de despesa',
          ),
          const SectionLabel('Nome'),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
            ),
            child: TextField(
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Contador, sindicato, uniforme…',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                prefixIcon: Icon(
                  Symbols.sell_rounded,
                  weight: 500,
                  color: colors.onSurfaceVariant,
                ),
                filled: true,
                fillColor: colors.secondaryContainer,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Dimens.pillRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_isEditing)
            SwitchListTile(
              contentPadding: const EdgeInsets.fromLTRB(
                Dimens.screenGutter,
                Dimens.gapLarge,
                Dimens.screenGutter,
                0,
              ),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              title: const Text('Na lista'),
              subtitle: Text(
                'Desligado, some do formulário de lançar — mas o que já foi '
                'lançado continua somando no Caixa.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          if (_isEditing) _DeleteZone(usage: _usage, onDelete: _confirmDelete),
        ],
      ),
      bottomNavigationBar: BottomAction(
        child: FilledButton(
          onPressed: _isValid && !_saving ? _save : null,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Salvar' : 'Cadastrar'),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final name = _name.text.trim();

    try {
      // Dois tipos com o mesmo nome partiriam o detalhamento do Caixa em dois
      // pedacos que ninguem consegue somar de cabeca.
      if (!_isEditing) {
        final clash = await ref
            .read(expenseCategoryRepositoryProvider)
            .findById(_idFrom(name));
        if (clash != null) {
          if (!mounted) return;
          setState(() => _saving = false);
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(content: Text('Já existe o tipo ${clash.name}.')),
            );
          return;
        }
      }

      await ref
          .read(expenseCategoryRepositoryProvider)
          .save(
            ExpenseCategory(
              // O id nasce do nome e nunca muda: e o que os lancamentos
              // guardam. Renomear o tipo nao pode soltar o que ja foi lancado.
              id: widget.category?.id ?? _idFrom(name),
              name: name,
              isActive: _isActive,
            ),
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('$name salvo.')));
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Não consegui salvar. Tente de novo.')),
        );
    }
  }

  Future<void> _confirmDelete() async {
    final category = widget.category!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar tipo?'),
        content: Text(
          '${category.name} some de vez. Como ninguém lançou nada nele, '
          'nada do Caixa se perde.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).status.alert,
            ),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(expenseCategoryRepositoryProvider).delete(category.id);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('${category.name} apagado.')));
  }

  String _idFrom(String name) =>
      normalizeForSearch(name)
          .replaceAll(RegExp('[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
}

/// Apagar de vez, e so quando ninguem lancou nada.
///
/// Com gasto atrelado o banco recusa, e mesmo que aceitasse aqueles
/// lancamentos sumiriam do Caixa — a consulta junta pelo tipo para pegar o
/// nome. Nesse caso o caminho e aposentar.
class _DeleteZone extends StatelessWidget {
  const new({required this.usage, required this.onDelete});

  final int? usage;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usage = this.usage;
    if (usage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        Dimens.gapLarge,
        Dimens.screenGutter,
        0,
      ),
      child: usage > 0
          ? Text(
              usage == 1
                  ? 'Não dá para apagar: 1 despesa está lançada neste tipo. '
                        'Para sumir do formulário, desligue "Na lista".'
                  : 'Não dá para apagar: $usage despesas estão lançadas neste '
                        'tipo. Para sumir do formulário, desligue "Na lista".',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: theme.status.alert,
                ),
                child: const Text('Apagar tipo'),
              ),
            ),
    );
  }
}
