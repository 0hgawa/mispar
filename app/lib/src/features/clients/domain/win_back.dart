import 'package:marcos_barber/src/features/clients/domain/client_summary.dart';
import 'package:marcos_barber/src/shared/whatsapp.dart';

/// Quem sumiu, na ordem de quem vale mais chamar.
///
/// Ordenado pelo que a pessoa já gastou, e não pelo tempo sem aparecer: o
/// cliente de platinado que some vale três cortes simples, e é ele que tem
/// que estar no topo da lista quando sobram cinco minutos para mandar
/// mensagem. Quem está fora da lista fica de fora — foi tirado de propósito.
List<ClientSummary> winBackList(List<ClientSummary> all) {
  final drifted = [
    for (final summary in all)
      if (summary.hasDrifted && summary.client.isActive) summary,
  ]..sort((a, b) => b.spentCents.compareTo(a.spentCents));

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
