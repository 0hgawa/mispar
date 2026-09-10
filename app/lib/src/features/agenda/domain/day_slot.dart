import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';

part 'day_slot.freezed.dart';

/// Uma faixa do dia: tem cliente, esta vaga, ou esta fechada.
///
/// A vaga e tao importante quanto o horario marcado — e o que da para vender.
/// E o fechado precisa aparecer: buraco sem explicacao vira duvida.
@freezed
sealed class DaySlot with _$DaySlot {
  const factory booked(Appointment appointment) = BookedSlot;

  const factory free({required DateTime start, required DateTime end}) =
      FreeSlot;

  const factory blocked({
    required DateTime start,
    required DateTime end,
    String? reason,
  }) = BlockedSlot;

  const new _();

  DateTime get start => switch (this) {
    BookedSlot(:final appointment) => appointment.startsAt,
    FreeSlot(:final start) => start,
    BlockedSlot(:final start) => start,
  };
}
