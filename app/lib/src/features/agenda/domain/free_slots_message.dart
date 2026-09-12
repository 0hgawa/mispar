import 'package:marcos_barber/src/shared/formatters/day_time.dart';

/// Os horários livres em uma mensagem, para colar numa conversa.
///
/// Texto e não imagem porque o lugar onde isto funciona é a conversa de um
/// para um: ali o cliente copia a hora, responde "16:30" citando, e fecha.
/// Imagem no chat parece panfleto — ela é para o Stories, onde texto solto de
/// outro app nem entra.
///
/// **Uma hora por linha**, e não tudo numa frase. Em bloco corrido o olho tem
/// que separar as horas das vírgulas antes de escolher; empilhadas, elas viram
/// uma lista para percorrer com o polegar — e é o mesmo desenho do cartaz, o
/// que faz os dois parecerem a mesma coisa mandada de dois jeitos.
///
/// Sem negrito nem marcador: o `*` do WhatsApp sai como asterisco cru no
/// Instagram e no SMS, e a folha de compartilhar do Android não promete onde
/// isto vai cair.
///
/// Vai pronta e **não** é enviada: quem manda é o Marcos, do WhatsApp dele.
///
/// [now] entra por fora para o teste não depender do relógio.
String freeSlotsMessage({
  required DateTime day,
  required List<DateTime> hours,
  required DateTime now,
}) {
  final isToday =
      day.year == now.year && day.month == now.month && day.day == now.day;
  // "hoje" no dia, e o dia curto no resto — o mesmo rótulo do cartaz. Data
  // cheia numa mensagem curta soa a aviso de banco.
  final quando = isToday
      ? 'hoje'
      : '${formatShortWeekday(day).toLowerCase()} ${day.day}';

  // Um horário só não vira lista: três linhas para dizer uma hora parece
  // recado de empresa.
  if (hours.length == 1) {
    return 'Tenho um horário $quando: ${formatHour(hours.first)}. '
        'Chama aqui pra marcar.';
  }

  final lista = hours.map(formatHour).join('\n');
  return 'Tenho horário $quando:\n\n$lista\n\nChama aqui pra marcar.';
}
