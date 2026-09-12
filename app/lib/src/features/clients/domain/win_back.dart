import 'package:marcos_barber/src/features/clients/domain/client_summary.dart';
import 'package:marcos_barber/src/features/settings/domain/drifted_rule.dart';
import 'package:marcos_barber/src/shared/whatsapp.dart';

/// Quem sumiu, na ordem de quem vale mais chamar.
///
/// Ordenado pelo que a pessoa deixa **por visita**, e não pelo total de
/// sempre nem pelo tempo sem aparecer.
///
/// Pelo total, quem veio vinte vezes há três anos passava na frente de quem
/// vinha todo mês até semestre passado — e é o segundo que ainda volta. O
/// gasto por visita diz quanto vale a cadeira quando ele senta nela, que é a
/// pergunta de quem tem cinco minutos para mandar mensagem: o cliente de
/// platinado vale três cortes simples.
///
/// Empate desempata por quem sumiu há mais tempo: com dois iguais em dinheiro,
/// o mais esquecido é o mais urgente — e a ordem para de dançar a cada
/// atendimento.
///
/// Quem está fora da lista fica de fora — foi tirado de propósito.
///
/// Com a regra desligada a lista é vazia, e some junto com ela tudo que
/// depende dela: a faixa no topo da aba de Clientes, e o caminho para cá.
List<ClientSummary> winBackList(List<ClientSummary> all, DriftedRule rule) {
  if (!rule.isOn) return const [];

  final drifted =
      [
        for (final summary in all)
          if (summary.hasDriftedAfter(rule.days) && summary.client.isActive)
            summary,
      ]..sort((a, b) {
        final porVisita = b.averageTicketCents.compareTo(a.averageTicketCents);
        if (porVisita != 0) return porVisita;
        return a.lastVisit!.compareTo(b.lastVisit!);
      });

  return drifted;
}

/// O que a barbearia perdeu de vista, somado.
///
/// É o que estes clientes já gastaram aqui — histórico, não promessa. Serve
/// de tamanho do problema: quatro nomes não dizem nada, R$ 480 dizem.
int winBackValueCents(List<ClientSummary> drifted) {
  var total = 0;
  for (final summary in drifted) {
    total += summary.spentCents;
  }
  return total;
}

/// A mensagem que chama o cliente de volta.
///
/// Vai pronta e **não** é enviada: quem manda é o Marcos, do WhatsApp dele.
/// Isso é de graça — a Meta só cobra o que sai do robô — e chega como pessoa
/// falando, que é o que faz alguém responder.
String winBackMessage({required String name, String? usualService}) {
  final quem = firstName(name);
  final oQue = usualService == null
      ? 'marcar um horário'
      : 'marcar o $usualService';

  return 'Oi, $quem! Faz tempo que você não passa aqui. Quer $oQue?';
}
