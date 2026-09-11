/// A série de meses que vira gráfico no Caixa.
library;

/// Quantos meses o gráfico mostra. Seis cabem no celular sem virar risco.
const trendMonths = 6;

/// O primeiro dia de cada mês da série, do mais antigo para o mais novo.
///
/// O último é sempre o mês em que [now] está — o gráfico termina em "agora",
/// não num mês fechado, senão o mês que está sendo vivido não apareceria.
List<DateTime> monthStarts({required DateTime now, int months = trendMonths}) {
  return [
    for (var back = months - 1; back >= 0; back--)
      DateTime(now.year, now.month - back),
  ];
}

/// Soma de cada mês de [starts], em centavos, na mesma ordem.
///
/// Mês sem nada devolve zero em vez de sumir: é o buraco na fileira que mostra
/// o mês fraco. O que cai fora da série é ignorado — quem consulta já pediu só
/// a janela, isto aqui é a rede de segurança.
List<int> byMonth({
  required List<DateTime> starts,
  required Iterable<({DateTime at, int cents})> moves,
}) {
  final totals = List<int>.filled(starts.length, 0);
  if (starts.isEmpty) return totals;

  // Índice pela chave ano*12+mês: uma passada pelos lançamentos, sem procurar
  // a casa de cada um dentro da lista.
  final slot = <int, int>{
    for (var i = 0; i < starts.length; i++)
      starts[i].year * 12 + starts[i].month: i,
  };

  for (final move in moves) {
    final at = slot[move.at.year * 12 + move.at.month];
    if (at != null) totals[at] += move.cents;
  }

  return totals;
}
