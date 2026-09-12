import 'package:mispar/src/features/agenda/domain/appointment.dart';
import 'package:mispar/src/features/agenda/domain/payment_method.dart';

/// Como a barbearia costuma receber.
///
/// Sai do histórico, e não de um ajuste: ajuste de "forma padrão" fica no
/// valor de fábrica para sempre, porque ninguém entra em Ajustes para
/// configurar o que já funciona — e quando o movimento muda, ele continua
/// apontando para o lado errado. Contado, ele se corrige sozinho.
///
/// Nulo enquanto não houver pagamento anotado **suficiente**. Sem histórico
/// não se inventa um padrão: as três formas aparecem com o mesmo peso, que é a
/// verdade.
/// Quantos pagamentos anotados antes de chamar aquilo de costume.
///
/// Um nao e habito, e nem tres sao. Uma barbearia recebe de dez a vinte vezes
/// por semana, entao cinco chegam em poucos dias — e antes disso um cliente
/// atipico decidiria sozinho qual botao nasce preto.
const _minimoParaCostume = 5;

PaymentMethod? usualPayment(List<Appointment> history) {
  final counted = <PaymentMethod, int>{};
  var total = 0;

  for (final appointment in history) {
    final method = appointment.paidWith;
    if (method == null) continue;
    counted[method] = (counted[method] ?? 0) + 1;
    total++;
  }

  if (total < _minimoParaCostume) return null;

  // Percorrido na ordem do enum, que é a ordem dos botões, e trocando só com
  // contagem **maior**: assim o empate fica com o primeiro botão em vez de
  // pular de lugar a cada atendimento, numa barbearia que recebe metade em
  // dinheiro e metade em Pix.
  PaymentMethod? best;
  for (final method in PaymentMethod.values) {
    final count = counted[method] ?? 0;
    if (count == 0) continue;
    if (best == null || count > (counted[best] ?? 0)) best = method;
  }
  return best;
}
