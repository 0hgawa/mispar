import 'package:mispar/src/features/agenda/data/agenda_repository.dart';
import 'package:mispar/src/features/agenda/data/shop_hours_repository.dart';
import 'package:mispar/src/features/agenda/data/time_block_repository.dart';
import 'package:mispar/src/features/agenda/domain/day_schedule.dart';
import 'package:mispar/src/features/agenda/domain/day_slot.dart';
import 'package:mispar/src/features/agenda/domain/shop_hours.dart';
import 'package:mispar/src/features/agenda/domain/time_block.dart';
import 'package:mispar/src/features/agenda/presentation/day_view_model.dart';
import 'package:mispar/src/shared/week.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'week_view_model.g.dart';

/// Um dia da semana, do ponto de vista de quanto rende e quanto sobra.
class DayOverview {
  const new({
    required this.date,
    required this.bookedTime,
    required this.freeTime,
    required this.isToday,
    required this.isPast,
    required this.isClosed,
    required this.slots,
  });

  final DateTime date;
  final Duration bookedTime;
  final Duration freeTime;
  final bool isToday;

  /// Dia que ja acabou. Nao se vende horario para tras.
  final bool isPast;

  final bool isClosed;

  /// A grade do dia inteira. E o mesmo dado da visao de Dia, so que resumido —
  /// duas formas de olhar a mesma agenda, nao duas telas diferentes.
  final List<DaySlot> slots;

  /// Quanto da cadeira esta vendido, de 0 a 1.
  double get occupancy {
    final total = bookedTime + freeTime;
    if (total == Duration.zero) return 0;
    return bookedTime.inMinutes / total.inMinutes;
  }
}

class WeekOverview {
  const new({required this.days});

  final List<DayOverview> days;

  Duration get bookedTime =>
      days.fold(Duration.zero, (sum, day) => sum + day.bookedTime);

  Duration get freeTime =>
      days.fold(Duration.zero, (sum, day) => sum + day.freeTime);

  double get occupancy {
    final total = bookedTime + freeTime;
    if (total == Duration.zero) return 0;
    return bookedTime.inMinutes / total.inMinutes;
  }
}

/// Os fechamentos da semana que a agenda esta mostrando.
@riverpod
Stream<List<TimeBlock>> weekBlocks(Ref ref) {
  final anchor = ref.watch(selectedDayProvider);
  final sunday = startOfWeek(anchor);
  return ref
      .watch(timeBlockRepositoryProvider)
      .watchRange(sunday, sunday.add(const Duration(days: 7)));
}

@riverpod
Stream<WeekOverview> weekOverview(Ref ref) {
  final now = DateTime.now();
  final week = ref
      .watch(weekHoursProvider)
      .maybeWhen(data: (w) => w, orElse: WeekHours.closed);
  final today = DateTime(now.year, now.month, now.day);

  // A semana mostrada e a do dia escolhido. Dia e Semana sao duas formas de
  // olhar o mesmo ponto da agenda, entao dividem o mesmo estado.
  final anchor = ref.watch(selectedDayProvider);
  final sunday = startOfWeek(anchor);
  final nextSunday = sunday.add(const Duration(days: 7));

  final ofWeek = ref
      .watch(weekBlocksProvider)
      .maybeWhen(data: (list) => list, orElse: () => const <TimeBlock>[]);

  return ref.watch(agendaRepositoryProvider).watchRange(sunday, nextSunday).map(
    (appointments) {
      final days = <DayOverview>[];

      for (var index = 0; index < 7; index++) {
        final date = sunday.add(Duration(days: index));
        final ofDay = [
          for (final appointment in appointments)
            if (appointment.status.stillStands &&
                appointment.startsAt.year == date.year &&
                appointment.startsAt.month == date.month &&
                appointment.startsAt.day == date.day)
              appointment,
        ];

        final slots = buildDaySchedule(
          date,
          ofDay,
          hours: week.on(date),
          blocks: [
            for (final block in ofWeek)
              if (block.touches(date, date.add(const Duration(days: 1)))) block,
          ],
        );
        var booked = Duration.zero;
        var free = Duration.zero;

        for (final slot in slots) {
          switch (slot) {
            case BookedSlot(:final appointment):
              booked += appointment.duration;
            case FreeSlot(:final start, :final end):
              final length = end.difference(start);
              free += length;
            // Fechado nao e vaga nem venda: a cadeira nao estava a disposicao.
            // Contar como livre faria a ocupacao parecer pior do que foi.
            case BlockedSlot():
              break;
          }
        }

        days.add(
          DayOverview(
            date: date,
            bookedTime: booked,
            freeTime: free,
            isToday: date == today,
            isPast: date.isBefore(today),
            isClosed: !week.on(date).isOpen,
            slots: slots,
          ),
        );
      }

      return WeekOverview(days: days);
    },
  );
}
