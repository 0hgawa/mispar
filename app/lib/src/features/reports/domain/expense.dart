/// No que o dinheiro da barbearia sai.
///
/// E cadastro, e nao lista fixa: os custos de cada barbearia sao os dela —
/// contador, sindicato, uniforme — e o que nao tem tipo proprio cai em
/// "Outros", que e onde o detalhamento para de servir.
class ExpenseCategory {
  const new({required this.id, required this.name, this.isActive = true});

  final String id;
  final String name;

  /// Tipo aposentado sai do formulario sem apagar o que ja foi lancado nele.
  final bool isActive;
}

/// Um gasto da barbearia. Valor em centavos, como todo dinheiro no app.
class Expense {
  const new({
    required this.id,
    required this.spentAt,
    required this.category,
    required this.cents,
    this.note,
    this.repeatsMonthly = false,
    this.seriesId,
  });

  final String id;
  final DateTime spentAt;
  final ExpenseCategory category;
  final int cents;

  /// "Pomada e talco" — o que a categoria sozinha nao conta.
  final String? note;

  /// Se o app deve lancar este gasto de novo todo mes.
  final bool repeatsMonthly;

  /// A qual serie mensal este lancamento pertence, se pertence a alguma.
  final String? seriesId;

  /// O que aparece na linha da lista.
  String get title =>
      note?.trim().isNotEmpty ?? false ? note!.trim() : category.name;
}
