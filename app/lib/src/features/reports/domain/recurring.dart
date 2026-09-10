/// A chave de mes usada para saber o que ja foi lancado: "2026-09".
String expenseMonthKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}';

/// Que datas ainda faltam lancar de um gasto que se repete todo mes.
///
/// Duas regras seguram o numero do Caixa honesto:
///
/// - **Nada do futuro.** O aluguel do dia 15 nao entra no dia 10: dinheiro que
///   ainda nao saiu nao pode aparecer como saida.
/// - **Dia 31 cai no ultimo dia do mes.** Fevereiro nao tem 31, e pular o mes
///   faria o aluguel sumir de fevereiro.
List<DateTime> monthsToCatchUp({
  required DateTime first,
  required DateTime now,
  required Set<String> alreadyLanced,
}) {
  final thisMonth = DateTime(now.year, now.month);
  final missing = <DateTime>[];

  var month = DateTime(first.year, first.month + 1);
  while (!month.isAfter(thisMonth)) {
    final day = sameDayIn(month, first.day);
    if (!alreadyLanced.contains(expenseMonthKey(month)) && !day.isAfter(now)) {
      missing.add(day);
    }
    month = DateTime(month.year, month.month + 1);
  }

  return missing;
}

/// O mesmo dia do mes, sem estourar para o mes seguinte.
DateTime sameDayIn(DateTime month, int day) {
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(month.year, month.month, day < lastDay ? day : lastDay);
}
