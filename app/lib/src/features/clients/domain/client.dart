import 'package:freezed_annotation/freezed_annotation.dart';

part 'client.freezed.dart';

@freezed
abstract class Client with _$Client {
  const factory({
    required String id,
    required String name,
    required String phone,
    String? note,

    /// Fora da lista, some da busca ao marcar. O historico continua.
    @Default(true) bool isActive,
  }) = _Client;
}
