/// Quando um cliente conta como sumido.
///
/// Barbearia nenhuma tem o mesmo ritmo: quem corta a cada quinze dias sumiu
/// bem antes de quem corta a cada dois meses. Por isso o prazo é escolhido,
/// e não fixo no código — e por isso dá para desligar o aviso inteiro.
class DriftedRule {
  const new({required this.isOn, required this.days});

  /// Enquanto o banco não respondeu: calado.
  ///
  /// Desligado aqui não é o valor de fábrica — de fábrica ele vem ligado. É só
  /// o que se mostra sem saber ainda: quem desligou o aviso não pode vê-lo
  /// piscar na tela a cada abertura.
  const new unknown() : isOn = false, days = defaultDays;

  /// Dois meses sem aparecer. Trinta dias acusaria quase todo mundo — mês é o
  /// intervalo normal de quem corta cabelo.
  static const defaultDays = 60;

  /// Os prazos que a tela oferece.
  static const dayChoices = [30, 60, 90];

  final bool isOn;
  final int days;
}
