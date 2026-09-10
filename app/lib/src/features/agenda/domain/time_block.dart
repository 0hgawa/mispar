import 'package:marcos_barber/src/features/agenda/domain/shop_hours.dart'
    show DayHours;

/// Uma faixa em que a barbearia nao atende, fora do horario normal.
///
/// Feriado, medico, viagem: o horario existe na semana padrao, mas neste dia
/// nao. E a excecao — a regra que se repete mora em [DayHours].
class TimeBlock {
  const new({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    this.reason,
  });

  /// Fecha os dias de [from] a [to], ambos inclusive.
  factory days({
    required String id,
    required DateTime from,
    required DateTime to,
    String? reason,
  }) {
    return TimeBlock(
      id: id,
      startsAt: DateTime(from.year, from.month, from.day),
      // O fim e exclusivo: a meia-noite do dia seguinte fecha o ultimo dia
      // inteiro sem invadir o proximo.
      endsAt: DateTime(to.year, to.month, to.day + 1),
      reason: reason,
    );
  }

  final String id;
  final DateTime startsAt;

  /// Exclusivo, como todo fim de faixa no app.
  final DateTime endsAt;

  /// "Médico", "Viagem". Opcional — o Marcos nao deve nada a ninguem.
  final String? reason;

  /// O ultimo dia fechado, ja que [endsAt] e exclusivo.
  DateTime get lastDay => endsAt.subtract(const Duration(days: 1));

  bool get isWholeDays =>
      startsAt == DateTime(startsAt.year, startsAt.month, startsAt.day) &&
      endsAt == DateTime(endsAt.year, endsAt.month, endsAt.day);

  bool touches(DateTime dayStart, DateTime dayEnd) =>
      startsAt.isBefore(dayEnd) && endsAt.isAfter(dayStart);
}
