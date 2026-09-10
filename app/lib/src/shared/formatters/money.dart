import 'package:intl/intl.dart';

final _whole = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: r'R$',
  decimalDigits: 0,
);
final _withCents = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

/// Formata centavos em real. Esconde os centavos quando sao zero — preco de
/// barbearia e redondo, "R$ 60,00" so ocupa espaco.
///
/// Os dois [NumberFormat] sao instanciados uma vez: isto roda por item de lista.
String formatMoney(int cents) =>
    (cents % 100 == 0 ? _whole : _withCents).format(cents / 100);
