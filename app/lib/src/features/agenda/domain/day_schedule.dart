import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/agenda/domain/day_slot.dart';
import 'package:marcos_barber/src/features/agenda/domain/shop_hours.dart';
import 'package:marcos_barber/src/features/agenda/domain/time_block.dart';

/// Monta o dia intercalando horarios marcados e vagas.
///
/// Funcao pura: recebe o horario de funcionamento e os agendamentos ja
/// ordenados por inicio, e devolve a grade completa. O almoco nao vira vaga.
List<DaySlot> buildDaySchedule(
  DateTime day,
  List<Appointment> appointments, {
  required DayHours hours,
  List<TimeBlock> blocks = const [],
}) {
  // Dia fechado nao tem vaga nem grade. Sem isto o app ofereceria horario num
  // domingo e deixaria marcar. O que ja estiver marcado continua aparecendo:
  // se o Marcos abriu por excecao, o cliente nao pode sumir.
  if (!hours.isOpen) {
    return [for (final a in appointments) DaySlot.booked(a)];
  }

  final midnight = DateTime(day.year, day.month, day.day);
  final opens = midnight.add(hours.opensAt);
  final closes = midnight.add(hours.closesAt);

  // Bloqueio ocupa a cadeira igual a um cliente: entra na mesma fila, em
  // ordem de horario. Assim uma consulta medica no meio da tarde parte a vaga
  // em duas em vez de sumir sem explicacao.
  final taken = <({DateTime start, DateTime end, DaySlot slot})>[
    for (final appointment in appointments)
      (
        start: appointment.startsAt,
        end: appointment.endsAt,
        slot: DaySlot.booked(appointment),
      ),
    for (final block in blocks)
      if (block.touches(opens, closes))
        () {
          // Recortado ao expediente: fechar a noite toda nao muda o dia.
          final start = block.startsAt.isAfter(opens) ? block.startsAt : opens;
          final end = block.endsAt.isBefore(closes) ? block.endsAt : closes;
          return (
            start: start,
            end: end,
            slot: DaySlot.blocked(start: start, end: end, reason: block.reason),
          );
        }(),
  ]..sort((a, b) => a.start.compareTo(b.start));

  final slots = <DaySlot>[];
  var cursor = opens;

  void addGap(DateTime from, DateTime to) {
    // Corta o almoco de dentro da vaga em vez de oferecer o horario.
    for (final (start, end) in _minusLunch(from, to, midnight, hours)) {
      if (end.difference(start) >= SlotRules.shortestUsefulGap) {
        slots.add(DaySlot.free(start: start, end: end));
      }
    }
  }

  for (final entry in taken) {
    if (entry.start.isAfter(cursor)) addGap(cursor, entry.start);
    slots.add(entry.slot);
    if (entry.end.isAfter(cursor)) cursor = entry.end;
  }

  if (cursor.isBefore(closes)) addGap(cursor, closes);

  return slots;
}

/// Devolve [from]–[to] sem a faixa do almoco, em ate dois pedacos.
List<(DateTime, DateTime)> _minusLunch(
  DateTime from,
  DateTime to,
  DateTime midnight,
  DayHours hours,
) {
  if (!hours.hasLunch) return [(from, to)];

  final lunchStart = midnight.add(hours.lunchStart!);
  final lunchEnd = midnight.add(hours.lunchEnd!);

  if (!to.isAfter(lunchStart) || !from.isBefore(lunchEnd)) {
    return [(from, to)];
  }

  return [
    if (from.isBefore(lunchStart)) (from, lunchStart),
    if (to.isAfter(lunchEnd)) (lunchEnd, to),
  ];
}

/// Horarios em que um servico de [duration] cabe no dia.
///
/// E a mesma regra que o robo usa no Postgres: percorre as vagas da grade e
/// oferece inicios de [SlotRules.step] em [SlotRules.step].
List<DateTime> availableStarts(
  List<DaySlot> schedule,
  Duration duration, {
  Duration step = SlotRules.step,
  DateTime? notBefore,
}) {
  final starts = <DateTime>[];

  for (final slot in schedule) {
    if (slot is! FreeSlot) continue;

    var candidate = slot.start;
    while (!candidate.add(duration).isAfter(slot.end)) {
      if (notBefore == null || candidate.isAfter(notBefore)) {
        starts.add(candidate);
      }
      candidate = candidate.add(step);
    }
  }

  return starts;
}
