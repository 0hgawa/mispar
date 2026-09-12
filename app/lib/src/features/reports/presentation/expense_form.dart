import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/core/theme/status_colors.dart';
import 'package:marcos_barber/src/features/reports/data/expense_category_repository.dart';
import 'package:marcos_barber/src/features/reports/data/expense_repository.dart';
import 'package:marcos_barber/src/features/reports/domain/expense.dart';
import 'package:marcos_barber/src/shared/task_route.dart';
import 'package:marcos_barber/src/shared/widgets/app_snack.dart';
import 'package:marcos_barber/src/shared/widgets/bottom_action.dart';
import 'package:marcos_barber/src/shared/widgets/day_button.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:marcos_barber/src/shared/widgets/task_bar.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';

/// Lancar ou corrigir um gasto.
///
/// Tela cheia, igual a de marcar horario: e um formulario, nao uma pergunta
/// de sim ou nao.
class ExpenseForm extends ConsumerStatefulWidget {
  const new({this.expense, super.key});

  final Expense? expense;

  static Future<void> show(BuildContext context, {Expense? expense}) {
    return openTask(context, (_) => ExpenseForm(expense: expense));
  }

  @override
  ConsumerState<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<ExpenseForm> {
  late final _amount = TextEditingController(
    text: widget.expense == null
        ? ''
        : (widget.expense!.cents / 100).toStringAsFixed(0),
  );
  late final _note = TextEditingController(text: widget.expense?.note ?? '');

  late ExpenseCategory? _category = widget.expense?.category;
  late DateTime _spentAt = widget.expense?.spentAt ?? DateTime.now();
  late bool _repeats = widget.expense?.repeatsMonthly ?? false;
  bool _saving = false;

  bool get _isEditing => widget.expense != null;

  /// Valor e tipo, os dois. Nenhum tipo vem marcado de saida: um palpite
  /// errado passa despercebido e so aparece no fim do mes.
  bool get _isValid =>
      (int.tryParse(_amount.text) ?? 0) > 0 && _category != null;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final categories =
        ref.watch(activeExpenseCategoriesProvider).value ??
        const <ExpenseCategory>[];

    return Scaffold(
      appBar: TaskBar(title: _isEditing ? 'Despesa' : 'Nova despesa'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimens.screenGutter,
              0,
              Dimens.screenGutter,
              Dimens.gapSmall,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: DayButton(day: _spentAt, onTap: _pickDay),
            ),
          ),
          const SectionLabel('Quanto saiu'),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
            ),
            child: TextField(
              controller: _amount,
              autofocus: !_isEditing,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: theme.textTheme.displayMedium,
              decoration: InputDecoration(
                hintText: '0',
                prefixText: r'R$ ',
                prefixStyle: theme.textTheme.displayMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                hintStyle: theme.textTheme.displayMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                filled: true,
                fillColor: colors.secondaryContainer,
                contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Dimens.cardRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SectionLabel('Com o quê'),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
            ),
            child: categories.isEmpty
                ? Text(
                    'Nenhum tipo cadastrado. Ajustes → Despesas.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  )
                : Wrap(
                    spacing: Dimens.gapSmall,
                    runSpacing: Dimens.gapSmall,
                    children: [
                      for (final category in categories)
                        ChoiceChip(
                          label: Text(category.name),
                          selected: category.id == _category?.id,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                    ],
                  ),
          ),
          const SectionLabel('Quando'),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
            ),
            value: _repeats,
            onChanged: (value) => setState(() => _repeats = value),
            title: const Text('Todo mês'),
            subtitle: Text(
              'Aluguel, internet, contador: o app lança sozinho no mês que '
              'vem, no mesmo dia.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SectionLabel('Observação'),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
            ),
            child: TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Pomada, talco, navalha… (opcional)',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                prefixIcon: Icon(
                  Symbols.notes_rounded,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimens.screenGutter,
                Dimens.gapLarge,
                Dimens.screenGutter,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.status.alert,
                  ),
                  child: const Text('Apagar despesa'),
                ),
              ),
            ),
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
              : Text(_isEditing ? 'Salvar' : 'Lançar'),
        ),
      ),
    );
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      firstDate: DateTime(now.year - 3),
      // Gasto do futuro nao existe: ou ja saiu, ou ainda nao e despesa.
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Dia do gasto',
      cancelText: 'Voltar',
      confirmText: 'Usar',
    );
    if (chosen == null) return;
    setState(() => _spentAt = chosen);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final note = _note.text.trim();
    final id = widget.expense?.id ?? const Uuid().v4();

    try {
      await ref
          .read(expenseRepositoryProvider)
          .save(
            Expense(
              id: id,
              spentAt: _spentAt,
              category: _category!,
              cents: (int.tryParse(_amount.text) ?? 0) * 100,
              note: note.isEmpty ? null : note,
              repeatsMonthly: _repeats,
              // Um gasto que passa a se repetir abre a serie no proprio id.
              // Um que ja pertencia a uma continua nela mesmo se for desligado
              // — o que ja foi lancado nao muda de lugar.
              seriesId: widget.expense?.seriesId ?? (_repeats ? id : null),
            ),
          );

      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Não consegui salvar. Tente de novo.');
    }
  }

  Future<void> _delete() async {
    await ref.read(expenseRepositoryProvider).delete(widget.expense!.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    showSnack(context, 'Despesa apagada.');
  }
}
