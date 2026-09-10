import 'package:marcos_barber/src/features/agenda/data/agenda_repository.dart';
import 'package:marcos_barber/src/features/agenda/data/shop_hours_repository.dart';
import 'package:marcos_barber/src/features/agenda/data/time_block_repository.dart';
import 'package:marcos_barber/src/features/agenda/domain/day_schedule.dart';
import 'package:marcos_barber/src/features/agenda/domain/day_slot.dart';
import 'package:marcos_barber/src/features/agenda/domain/shop_hours.dart';
import 'package:marcos_barber/src/features/agenda/domain/time_block.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'day_view_model.g.dart';

/// O dia pronto para desenhar.
class DayAgenda {
  const new({
    required this.date,
    required this.slots,
    required this.bookedCount,
    required this.forecastCents,
  });

  final DateTime date;
  final List<DaySlot> slots;
  final int bookedCount;
  final int forecastCents;
}

/// Quantos dias a regua do topo mostra de uma vez.
const kDayStripLength = 14;

DateTime _midnight(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// Os fechamentos que tocam um dia.
@riverpod
Stream<List<TimeBlock>> dayBlocks(Ref ref, DateTime day) {
  final start = DateTime(day.year, day.month, day.day);
  return ref
      .watch(timeBlockRepositoryProvider)
      .watchRange(start, start.add(const Duration(days: 1)));
}

@riverpod
class SelectedDay extends _$SelectedDay {
  @override
  DateTime build() => _midnight(DateTime.now());

  void select(DateTime day) => state = _midnight(day);
}

@riverpod
Stream<DayAgenda> dayAgenda(Ref ref) {
  final day = ref.watch(selectedDayProvider);
  final hours = ref
      .watch(weekHoursProvider)
      .maybeWhen(
        data: (week) => week.on(day),
        orElse: () => WeekHours.closed().on(day),
      );

  final blocks = ref
      .watch(dayBlocksProvider(day))
      .maybeWhen(data: (list) => list, orElse: () => const <TimeBlock>[]);

  return ref.watch(agendaRepositoryProvider).watchDay(day).map((appointments) {
    final schedule = buildDaySchedule(
      day,
      appointments,
      hours: hours,
      blocks: blocks,
    );

    // O faturamento previsto conta o dia inteiro, nunca o filtro: e o numero
    // do dia, nao da lista que esta na tela.
    final forecast = appointments
        .where((a) => a.status.stillStands)
        .fold<int>(0, (sum, a) => sum + a.priceCents);

    return DayAgenda(
      date: day,
      slots: schedule,
      bookedCount: appointments.length,
      forecastCents: forecast,
    );
  });
}
