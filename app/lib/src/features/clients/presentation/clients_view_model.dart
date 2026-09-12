import 'package:mispar/src/features/clients/data/client_repository.dart';
import 'package:mispar/src/features/clients/domain/client_summary.dart';
import 'package:mispar/src/shared/formatters/text.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clients_view_model.g.dart';

/// Todos os clientes, sem filtro.
@riverpod
Stream<List<ClientSummary>> allClients(Ref ref) =>
    ref.watch(clientRepositoryProvider).watchSummaries();

/// Filtra por nome ou telefone. Fica aqui, e nao dentro de uma tela, porque
/// duas telas buscam cliente — e cada uma com o seu proprio termo.
List<ClientSummary> matchingClients(List<ClientSummary> all, String rawTerm) {
  final term = normalizeForSearch(rawTerm.trim());
  if (term.isEmpty) return all;
  final digits = digitsOf(term);

  return [
    for (final summary in all)
      if (_startsAnyWord(summary.client.name, term) ||
          (digits.isNotEmpty &&
              digitsOf(summary.client.phone).contains(digits)))
        summary,
  ];
}

/// O termo casa com o comeco de alguma palavra do nome.
///
/// Casar em qualquer pedaco traz gente demais: "ra" acharia Douglas P**ra**tes
/// e Jonas Bei**ra**l, e quem digitou queria o Rafael. Ninguem busca cliente
/// pelo meio do sobrenome.
bool _startsAnyWord(String name, String term) {
  for (final word in normalizeForSearch(name).split(' ')) {
    if (word.startsWith(term)) return true;
  }
  return false;
}

@riverpod
Stream<ClientSummary?> clientSummary(Ref ref, String clientId) =>
    ref.watch(clientRepositoryProvider).watchSummary(clientId);

@riverpod
Stream<List<ClientVisit>> clientVisits(Ref ref, String clientId) =>
    ref.watch(clientRepositoryProvider).watchVisits(clientId);
