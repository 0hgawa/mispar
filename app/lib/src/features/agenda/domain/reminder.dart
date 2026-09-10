import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/whatsapp.dart';

/// O texto do lembrete que o Marcos manda para o cliente.
///
/// Falta é o que mais custa caro na cadeira, e lembrete é o que mais reduz.
/// A mensagem vai pronta, mas quem manda é ele.
String reminderMessage(Appointment appointment, {required DateTime now}) {
  return 'Oi, ${firstName(appointment.client.name)}! Passando para confirmar '
      'seu horário ${whenInWords(appointment.startsAt, now: now)} — '
      '${appointment.service.name}. Tudo certo?';
}

/// "hoje às 14:30", "amanhã às 09:00", "sex, 11/09 às 09:00".
///
/// Cliente entende "amanhã" na hora; data por extenso ele tem que traduzir.
String whenInWords(DateTime startsAt, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(startsAt.year, startsAt.month, startsAt.day);
  final hour = formatHour(startsAt);

  return switch (day.difference(today).inDays) {
    0 => 'hoje às $hour',
    1 => 'amanhã às $hour',
    _ => '${formatShortWeekday(day)}, ${formatShortDate(day)} às $hour',
  };
}
