/// Situacao de um horario marcado.
///
/// [wireName] e o nome usado no banco — o mesmo texto no Postgres do Supabase e
/// no SQLite local. Uma palavra so para cada situacao, em todo lugar.
enum AppointmentStatus {
  /// Marcado, mas sem resposta ate agora.
  awaiting('awaiting'),

  /// Cliente respondeu confirmando.
  confirmed('confirmed'),

  /// Pagou o sinal — nao some da agenda sem aviso.
  depositPaid('deposit_paid'),

  /// Atendido.
  done('done'),

  /// Nao apareceu.
  noShow('no_show'),

  /// Desmarcado a tempo. Sai da agenda e libera o horario.
  cancelled('cancelled');

  new(this.wireName);

  final String wireName;

  static AppointmentStatus fromWire(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    throw ArgumentError.value(value, 'value', 'situação desconhecida');
  }

  /// O horario ainda esta de pe. Desmarcado e falta nao contam: nem ocupam a
  /// cadeira, nem entram no faturamento previsto.
  bool get stillStands => this != cancelled && this != noShow;
}
