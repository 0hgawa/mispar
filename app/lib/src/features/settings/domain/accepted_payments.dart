import 'package:mispar/src/features/agenda/domain/payment_method.dart';

/// As formas de pagamento que a barbearia aceita.
///
/// Nem toda barbearia aceita as três: muita gente não tem maquininha, e ficar
/// vendo "Cartão" na tela de fechar atendimento é uma opção a mais para errar
/// o toque, todo dia, para sempre.
///
/// Guardado como texto separado por vírgula, e não como três colunas: o dia em
/// que entrar uma quarta forma — vale-alimentação, fiado — não vira migração.
abstract final class AcceptedPayments {
  /// De fábrica, as três. Tirar é decisão de quem atende; o app não adivinha
  /// quem tem maquininha.
  static const wireDefault = 'cash,pix,card';

  /// Lê o que está gravado, na ordem do enum — que é a ordem dos botões.
  ///
  /// Nome desconhecido é ignorado em silêncio: é o que sobra de uma forma que
  /// deixou de existir, e derrubar a tela de fechar atendimento por causa
  /// disso seria pior que esquecer o nome.
  static List<PaymentMethod> read(String wire) {
    final names = wire.split(',');
    final accepted = [
      for (final method in PaymentMethod.values)
        if (names.contains(method.name)) method,
    ];

    // Nenhuma aceita deixaria o atendimento sem como fechar. A tela impede
    // desligar a última, e isto é a rede embaixo dela.
    return accepted.isEmpty ? PaymentMethod.values : accepted;
  }

  /// O texto para gravar.
  static String write(List<PaymentMethod> accepted) {
    return [
      for (final method in PaymentMethod.values)
        if (accepted.contains(method)) method.name,
    ].join(',');
  }
}
