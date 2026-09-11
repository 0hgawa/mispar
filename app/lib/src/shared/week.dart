/// Onde a semana começa, para o app inteiro.
library;

/// O domingo da semana de [day].
///
/// **Uma definição só.** A régua do topo começa no domingo, e por um tempo a
/// lista da Semana e o "Esta semana" do Caixa começavam na segunda — a mesma
/// palavra apontando para dois intervalos diferentes na mesma tela.
///
/// `DateTime.sunday` é 7, então o resto por 7 dá zero no domingo e cresce até
/// seis no sábado.
DateTime startOfWeek(DateTime day) =>
    DateTime(day.year, day.month, day.day - day.weekday % 7);
