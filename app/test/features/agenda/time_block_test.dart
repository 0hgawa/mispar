import 'package:flutter_test/flutter_test.dart';
import 'package:mispar/src/features/agenda/domain/day_schedule.dart';
import 'package:mispar/src/features/agenda/domain/day_slot.dart';
import 'package:mispar/src/features/agenda/domain/shop_hours.dart';
import 'package:mispar/src/features/agenda/domain/time_block.dart';

final _day = DateTime(2026, 9, 10);

const _open = DayHours(
  weekday: DateTime.thursday,
  isOpen: true,
  opensAt: Duration(hours: 9),
  closesAt: Duration(hours: 18),
);

TimeBlock _block(int fromHour, int toHour, {String? reason}) => TimeBlock(
  id: 'b',
  startsAt: DateTime(2026, 9, 10, fromHour),
  endsAt: DateTime(2026, 9, 10, toHour),
  reason: reason,
);

void main() {
  group('buildDaySchedule com bloqueio', () {
    test('sem bloqueio o dia e uma vaga so', () {
      final slots = buildDaySchedule(_day, const [], hours: _open);

      expect(slots, hasLength(1));
      expect(slots.single, isA<FreeSlot>());
    });

    test('bloqueio no meio parte a vaga em duas', () {
      final slots = buildDaySchedule(
        _day,
        const [],
        hours: _open,
        blocks: [_block(14, 16, reason: 'Médico')],
      );

      expect(slots, hasLength(3));
      expect(slots[0], isA<FreeSlot>());
      expect(slots[1], isA<BlockedSlot>());
      expect(slots[2], isA<FreeSlot>());

      final blocked = slots[1] as BlockedSlot;
      expect(blocked.start, DateTime(2026, 9, 10, 14));
      expect(blocked.end, DateTime(2026, 9, 10, 16));
      expect(blocked.reason, 'Médico');
    });

    test('dia inteiro fechado nao sobra vaga', () {
      final slots = buildDaySchedule(
        _day,
        const [],
        hours: _open,
        blocks: [
          TimeBlock.days(id: 'b', from: _day, to: _day, reason: 'Feriado'),
        ],
      );

      expect(slots.whereType<FreeSlot>(), isEmpty);
      expect(slots.whereType<BlockedSlot>(), hasLength(1));
    });

    test('o bloqueio nao passa do expediente', () {
      // Fecha o dia inteiro, mas a barbearia so abre das 9 as 18.
      final slots = buildDaySchedule(
        _day,
        const [],
        hours: _open,
        blocks: [TimeBlock.days(id: 'b', from: _day, to: _day)],
      );

      final blocked = slots.whereType<BlockedSlot>().single;
      expect(blocked.start, DateTime(2026, 9, 10, 9));
      expect(blocked.end, DateTime(2026, 9, 10, 18));
    });

    test('bloqueio de outro dia nao entra', () {
      final slots = buildDaySchedule(
        _day,
        const [],
        hours: _open,
        blocks: [
          TimeBlock.days(
            id: 'b',
            from: DateTime(2026, 9, 12),
            to: DateTime(2026, 9, 13),
          ),
        ],
      );

      expect(slots.whereType<BlockedSlot>(), isEmpty);
    });

    test('horario fechado nao e oferecido para marcar', () {
      final slots = buildDaySchedule(
        _day,
        const [],
        hours: _open,
        blocks: [_block(9, 18)],
      );

      final starts = availableStarts(
        slots,
        const Duration(minutes: 30),
        notBefore: DateTime(2026, 9, 10, 8),
      );

      expect(starts, isEmpty);
    });
  });

  group('TimeBlock.days', () {
    test('fecha do primeiro ao ultimo dia, inclusive', () {
      final block = TimeBlock.days(
        id: 'b',
        from: DateTime(2026, 9, 12),
        to: DateTime(2026, 9, 14),
      );

      expect(block.startsAt, DateTime(2026, 9, 12));
      // O fim e exclusivo: a meia-noite do dia 15 fecha o dia 14 inteiro.
      expect(block.endsAt, DateTime(2026, 9, 15));
      expect(block.lastDay, DateTime(2026, 9, 14));
    });

    test('toca o dia do meio da viagem', () {
      final block = TimeBlock.days(
        id: 'b',
        from: DateTime(2026, 9, 12),
        to: DateTime(2026, 9, 14),
      );

      expect(
        block.touches(DateTime(2026, 9, 13), DateTime(2026, 9, 14)),
        isTrue,
      );
      expect(
        block.touches(DateTime(2026, 9, 15), DateTime(2026, 9, 16)),
        isFalse,
      );
    });
  });
}
