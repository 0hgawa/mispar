/// Regras sobre o pedaço de tempo que o Caixa está olhando.
library;

/// Recorta a janela anterior no mesmo ponto em que a atual está.
///
/// Sem isso, "Este mês" compara dez dias de setembro contra **agosto inteiro**
/// e o mês vai sempre parecer ruim até o dia 30. O mesmo vale para a semana e
/// para o ano. Quando o período já terminou — "Ontem", "Mês passado" — não há
/// o que recortar e a janela volta inteira.
({DateTime from, DateTime to}) sameProgress({
  required ({DateTime from, DateTime to}) previous,
  required ({DateTime from, DateTime to}) current,
  required DateTime now,
}) {
  if (!now.isBefore(current.to)) return previous;

  final cut = previous.from.add(now.difference(current.from));
  if (!cut.isBefore(previous.to)) return previous;

  return (from: previous.from, to: cut);
}

/// O mês que um intervalo cobre por inteiro, ou nulo se ele não for um mês.
///
/// Serve para o intervalo que nasce de um toque no gráfico ter nome — "Agosto
/// de 2026" — em vez de duas datas que o Marcos teria que ler para descobrir
/// que são o mês inteiro. O fim aqui é **inclusivo**, como vem do calendário.
DateTime? wholeMonthOf({required DateTime start, required DateTime end}) {
  if (start.day != 1) return null;
  if (start.year != end.year || start.month != end.month) return null;

  // O dia 0 do mês seguinte é o último dia deste.
  final lastDay = DateTime(start.year, start.month + 1, 0).day;
  if (end.day != lastDay) return null;

  return DateTime(start.year, start.month);
}
