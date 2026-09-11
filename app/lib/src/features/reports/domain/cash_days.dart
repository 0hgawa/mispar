/// Agrupamento por dia, para a lista de entradas.
library;

/// Um dia de trabalho e o que ele rendeu.
class DayTake<T> {
  const new({required this.day, required this.totalCents, required this.items});

  final DateTime day;
  final int totalCents;
  final List<T> items;
}

/// Junta os lançamentos por dia, do mais recente para o mais antigo.
///
/// Uma lista corrida de atendimentos não responde "como foi o sábado" — e é
/// essa a pergunta. Com o dia como cabeçalho e o total do dia ao lado, a mesma
/// lista passa a responder, sem nenhuma conta a mais na tela.
List<DayTake<T>> byDay<T>(
  Iterable<T> items, {
  required DateTime Function(T) when,
  required int Function(T) cents,
}) {
  final days = <DateTime, List<T>>{};

  for (final item in items) {
    final at = when(item);
    days.putIfAbsent(DateTime(at.year, at.month, at.day), () => []).add(item);
  }

  final ordered = days.keys.toList(growable: false)
    ..sort((a, b) => b.compareTo(a));

  return [
    for (final day in ordered)
      DayTake(
        day: day,
        totalCents: days[day]!.fold(0, (sum, item) => sum + cents(item)),
        items: days[day]!,
      ),
  ];
}
