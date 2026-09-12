import 'package:flutter_test/flutter_test.dart';
import 'package:mispar/src/features/services/domain/catalogue_kind.dart';

void main() {
  group('CatalogueKind.fromWire', () {
    test('lê o que o banco guardou', () {
      expect(CatalogueKind.fromWire('service'), CatalogueKind.service);
      expect(CatalogueKind.fromWire('product'), CatalogueKind.product);
    });

    test('o que veio antes da coluna é serviço', () {
      // Produto nao existia: tudo que estava no catalogo ocupava a cadeira.
      expect(CatalogueKind.fromWire(null), CatalogueKind.service);
      expect(CatalogueKind.fromWire(''), CatalogueKind.service);
    });

    test('valor estranho não derruba o catálogo', () {
      expect(CatalogueKind.fromWire('pacote'), CatalogueKind.service);
    });
  });
}
