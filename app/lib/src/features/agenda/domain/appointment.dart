import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment_status.dart';
import 'package:marcos_barber/src/features/agenda/domain/payment_method.dart';
import 'package:marcos_barber/src/features/clients/domain/client.dart';
import 'package:marcos_barber/src/features/services/domain/service.dart';

part 'appointment.freezed.dart';

@freezed
abstract class Appointment with _$Appointment {
  const factory({
    required String id,

    /// Nulo no que foi lançado direto no Caixa, sem hora marcada.
    required Client? client,
    required Service service,
    required DateTime startsAt,
    required AppointmentStatus status,

    /// Duracao e preco combinados na marcacao, nao os de hoje: se o Marcos
    /// subir o preco do corte, o que ja passou continua valendo o que foi
    /// cobrado.
    required Duration duration,
    required int priceCents,

    /// Como foi pago. Nulo enquanto o atendimento nao fechou, ou quando
    /// ninguem anotou.
    PaymentMethod? paidWith,

    /// Digitado direto no Caixa, sem ter passado pela agenda. E o que decide
    /// se tocar nele abre o formulario que o criou ou a folha do horario.
    @Default(false) bool isWalkIn,
  }) = _Appointment;

  const new _();

  DateTime get endsAt => startsAt.add(duration);

  /// Como chamar quem foi atendido. Inventar um nome seria pior que admitir
  /// que ninguém anotou.
  String get who => client?.name ?? 'Sem cadastro';
}
