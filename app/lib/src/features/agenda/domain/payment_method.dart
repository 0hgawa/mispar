/// Como o cliente pagou.
///
/// Lista fixa, ao contrario dos tipos de despesa: sao as formas que existem no
/// balcao, e o Marcos precisa conferir a maquininha contra o que anotou.
enum PaymentMethod {
  cash('Dinheiro'),
  pix('Pix'),
  card('Cartão');

  new(this.label);

  final String label;

  /// O que o banco guardou. Nulo quando ninguem anotou — atendimento antigo,
  /// ou o Marcos concluiu com pressa.
  static PaymentMethod? parse(String? name) {
    if (name == null) return null;
    for (final method in values) {
      if (method.name == name) return method;
    }
    return null;
  }
}
