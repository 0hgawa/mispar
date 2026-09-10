import 'package:freezed_annotation/freezed_annotation.dart';

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
  }) = _Service;
}
