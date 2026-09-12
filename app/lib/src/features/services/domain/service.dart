import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mispar/src/features/services/domain/catalogue_kind.dart';

part 'service.freezed.dart';

@freezed
abstract class Service with _$Service {
  const factory({
    required String id,
    required String name,
    required Duration duration,
    required int priceCents,
    required bool requiresDeposit,
    @Default(true) bool isActive,
    @Default(CatalogueKind.service) CatalogueKind kind,
  }) = _Service;

  const new _();

  /// Produto nao ocupa cadeira: nao entra na agenda nem no que se marca.
  bool get isProduct => kind == CatalogueKind.product;
}
