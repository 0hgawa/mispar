import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:marcos_barber/src/features/agenda/domain/free_slots_message.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  final hoje = DateTime(2026, 9, 12, 8);

  String mensagem(List<int> horas, {DateTime? dia}) {
    return freeSlotsMessage(
      day: dia ?? DateTime(2026, 9, 12),
      hours: [for (final h in horas) DateTime(2026, 9, 12, h)],
      now: hoje,
    );
  }

  group('freeSlotsMessage', () {
    test('um horario so fica numa linha, sem virar lista', () {
      expect(
        mensagem([16]),
        'Tenho um horário hoje: 16:00. Chama aqui pra marcar.',
      );
    });

    test('mais de um vira uma hora por linha', () {
      expect(
        mensagem([9, 10, 16]),
        'Tenho horário hoje:\n'
        '\n'
        '09:00\n'
        '10:00\n'
        '16:00\n'
        '\n'
        'Chama aqui pra marcar.',
      );
    });

    test('a lista guarda a ordem em que os horarios chegaram', () {
      expect(mensagem([9, 16]), contains('09:00\n16:00'));
    });

    test('outro dia vira o dia curto, e nao "hoje"', () {
      expect(
        mensagem([9], dia: DateTime(2026, 9, 14)),
        'Tenho um horário seg 14: 09:00. Chama aqui pra marcar.',
      );
    });
  });
}
