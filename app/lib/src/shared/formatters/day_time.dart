import 'package:intl/intl.dart';

final _hour = DateFormat.Hm('pt_BR');
final _weekdayAndDay = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');
final _shortWeekday = DateFormat('EEE', 'pt_BR');

String formatHour(DateTime time) => _hour.format(time);

/// "Quinta, 10 de setembro" — com inicial maiuscula, que o intl nao poe.
String formatLongDay(DateTime day) {
  final text = _weekdayAndDay.format(day);
  return text[0].toUpperCase() + text.substring(1);
}

String formatShortWeekday(DateTime day) =>
    _shortWeekday.format(day).replaceAll('.', '');

/// "50 min" ou "1h30".
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) return '$minutes min';
  return minutes == 0 ? '${hours}h' : '${hours}h$minutes';
}

/// "hoje", "ontem", "há 3 semanas", "há 5 meses".
///
/// Data exata nao ajuda ninguem a decidir; o que importa e quanto tempo faz.
String formatTimeAgo(DateTime moment) {
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(moment.year, moment.month, moment.day)).inDays;

  if (days < 0) return 'marcado';
  if (days == 0) return 'hoje';
  if (days == 1) return 'ontem';
  if (days < 7) return 'há $days dias';

  if (days < 30) {
    final weeks = days ~/ 7;
    return weeks == 1 ? 'há 1 semana' : 'há $weeks semanas';
  }

  final months = days ~/ 30;
  if (months < 12) return months == 1 ? 'há 1 mês' : 'há $months meses';

  final years = months ~/ 12;
  return years == 1 ? 'há 1 ano' : 'há $years anos';
}

/// "Hoje", "Ontem" ou "Sábado, 6 de setembro".
///
/// Cabeçalho de um dia numa lista: enquanto o dia tem nome próprio, o nome
/// ganha da data — ninguém precisa converter "10 de setembro" para saber que é
/// hoje.
String formatDayHeading(DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final days = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(day.year, day.month, day.day)).inDays;

  return switch (days) {
    0 => 'Hoje',
    1 => 'Ontem',
    _ => formatLongDay(day),
  };
}

/// "10/09" — data curta para a linha do histórico.
String formatShortDate(DateTime day) {
  final d = day.day.toString().padLeft(2, '0');
  final m = day.month.toString().padLeft(2, '0');
  return '$d/$m';
}

final _monthAndYear = DateFormat("MMMM 'de' y", 'pt_BR');

/// "Setembro de 2026" — o que a regua de dias nao consegue dizer.
String formatMonthAndYear(DateTime day) {
  final text = _monthAndYear.format(day);
  return text[0].toUpperCase() + text.substring(1);
}

/// "Quinta, 10" — dia da semana e numero, sem repetir o mes.
String formatWeekdayAndDay(DateTime day) {
  final weekday = formatShortWeekday(day);
  return '${weekday[0].toUpperCase()}${weekday.substring(1)}, ${day.day}';
}
