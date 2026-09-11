import 'package:marcos_barber/src/features/agenda/data/agenda_repository.dart';
import 'package:marcos_barber/src/features/agenda/data/shop_hours_repository.dart';
import 'package:marcos_barber/src/features/agenda/data/time_block_repository.dart';
import 'package:marcos_barber/src/features/agenda/domain/day_schedule.dart';
import 'package:marcos_barber/src/features/agenda/domain/day_slot.dart';
import 'package:marcos_barber/src/features/agenda/domain/shop_hours.dart';
import 'package:marcos_barber/src/features/agenda/domain/time_block.dart';
import 'package:marcos_barber/src/features/agenda/presentation/day_view_model.dart';
import 'package:marcos_barber/src/shared/week.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'week_view_model.g.dart';

/// Um dia da semana, do ponto de vista de quanto rende e quanto sobra.
class DayOverview {
  const new({
    required this.date,
    required this.bookedCount,
    required this.revenueCents,
    required this.bookedTime,
    required this.freeTime,
    required this.isToday,
    required this.isPast,
    required this.isClosed,
    required this.gaps,
    required this.slots,
  });

  final DateTime date;
  final int bookedCount;
  final int revenueCents;
  final Duration bookedTime;
  final Duration freeTime;
  final bool isToday;

  /// Dia que ja acabou. Nao se vende horario para tras.
  final bool isPast;

  final bool isClosed;

  /// As brechas do dia que ainda da para vender.
  final List<SellableGap> gaps;

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

/// Uma vaga grande o bastante para valer uma mensagem.
class SellableGap {
  const new({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get length => end.difference(start);
}

class WeekOverview {
  const new({required this.days, required this.revenueCents});

  final List<DayOverview> days;
  final int revenueCents;

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
      var revenue = 0;

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

        final gaps = <SellableGap>[];
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
        var earned = 0;

        for (final slot in slots) {
          switch (slot) {
            case BookedSlot(:final appointment):
              booked += appointment.duration;
              earned += appointment.priceCents;
            case FreeSlot(:final start, :final end):
              final length = end.difference(start);
              free += length;
              // Vaga no passado nao da para vender.
              if (length >= SlotRules.gapWorthSelling && start.isAfter(now)) {
                gaps.add(SellableGap(start: start, end: end));
              }
            // Fechado nao e vaga nem venda: a cadeira nao estava a disposicao.
            // Contar como livre faria a ocupacao parecer pior do que foi.
            case BlockedSlot():
              break;
          }
        }

        revenue += earned;
        days.add(
          DayOverview(
            date: date,
            bookedCount: ofDay.length,
            revenueCents: earned,
            bookedTime: booked,
            freeTime: free,
            isToday: date == today,
            isPast: date.isBefore(today),
            isClosed: !week.on(date).isOpen,
            // Maior primeiro: e a que vale a mensagem.
            gaps: gaps..sort((a, b) => b.length.compareTo(a.length)),
            slots: slots,
          ),
        );
      }

      return WeekOverview(days: days, revenueCents: revenue);
    },
  );
}
