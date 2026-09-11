/// O que a barbearia vende: tempo na cadeira, ou coisa da prateleira.
///
/// Os dois entram no Caixa do mesmo jeito — é dinheiro que entrou —, mas só
/// um ocupa horário. Produto não tem duração, não se marca na agenda, e é por
/// isso que ele precisa existir como tipo, e não como serviço de zero minuto:
/// a regra tem que estar escrita, não deduzida do número.
enum CatalogueKind {
  service('Serviço'),
  product('Produto');

  new(this.label);

  final String label;

  /// O que o banco guardou. O que veio antes desta coluna é serviço: produto
  /// não existia.
  static CatalogueKind fromWire(String? name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return CatalogueKind.service;
  }
}
