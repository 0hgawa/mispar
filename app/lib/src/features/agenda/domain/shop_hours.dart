/// Horario de funcionamento de um dia da semana.
///
/// Sai do banco, nao do codigo: e o mesmo dado que o robo do WhatsApp le no
/// Postgres, e o Marcos precisa poder mudar sem app novo. Enquanto isto era
/// constante em Dart **e** tabela no Postgres ao mesmo tempo, os dois
/// discordavam sobre quando a barbearia abre.
class DayHours {
  const new({
    required this.weekday,
    required this.isOpen,
    required this.opensAt,
    required this.closesAt,
    this.lunchStart,
    this.lunchEnd,
  });

  /// Dia fechado — tambem serve de estado enquanto o banco nao responde.
  const new closed(this.weekday)
    : isOpen = false,
      opensAt = Duration.zero,
      closesAt = Duration.zero,
      lunchStart = null,
      lunchEnd = null;

  /// 1 = segunda ... 7 = domingo (isoweekday).
  final int weekday;
  final bool isOpen;
  final Duration opensAt;
  final Duration closesAt;
  final Duration? lunchStart;
  final Duration? lunchEnd;

  bool get hasLunch => lunchStart != null && lunchEnd != null;

  /// Quanto o dia rende, ja fora o almoco.
  Duration get workingTime {
    if (!isOpen) return Duration.zero;
    final open = closesAt - opensAt;
    return hasLunch ? open - (lunchEnd! - lunchStart!) : open;
  }

  DayHours copyWith({
    bool? isOpen,
    Duration? opensAt,
    Duration? closesAt,
    Duration? lunchStart,
    Duration? lunchEnd,
    bool clearLunch = false,
  }) => DayHours(
    weekday: weekday,
    isOpen: isOpen ?? this.isOpen,
    opensAt: opensAt ?? this.opensAt,
    closesAt: closesAt ?? this.closesAt,
    lunchStart: clearLunch ? null : (lunchStart ?? this.lunchStart),
    lunchEnd: clearLunch ? null : (lunchEnd ?? this.lunchEnd),
  );
}

/// A semana inteira, indexada pelo dia.
class WeekHours {
  const new(this.days);

  /// Tudo fechado — o que vale enquanto o banco nao respondeu. Melhor nao
  /// oferecer nada do que oferecer horario errado.
  factory closed() =>
      WeekHours({for (var day = 1; day <= 7; day++) day: DayHours.closed(day)});

  final Map<int, DayHours> days;

  DayHours on(DateTime day) =>
      days[day.weekday] ?? DayHours.closed(day.weekday);

  List<DayHours> get inOrder => [
    for (var day = 1; day <= 7; day++) days[day] ?? DayHours.closed(day),
  ];
}

/// Regras de encaixe que nao dependem do dia da semana.
abstract final class SlotRules {
  /// Vaga menor que isto nao vale a pena mostrar: nao cabe nem um pezinho.
  static const shortestUsefulGap = Duration(minutes: 15);

  /// Vaga a partir daqui vale uma mensagem para a fila de espera.
  static const gapWorthSelling = Duration(minutes: 30);

  /// De quanto em quanto tempo os horarios sao oferecidos. Passo curto demais
  /// vira uma lista impossivel de ler; longo demais perde encaixe de pezinho.
  static const step = Duration(minutes: 15);
}
