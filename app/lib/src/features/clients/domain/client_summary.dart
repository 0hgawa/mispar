import 'package:marcos_barber/src/features/clients/domain/client.dart';

/// O cliente com o que a barbearia sabe sobre ele.
///
/// Os numeros saem do que esta gravado no aparelho — a sincronia guarda os
/// ultimos 90 dias, entao "gasto" e "visitas" falam desse periodo.
class ClientSummary {
  const new({
    required this.client,
    required this.visitCount,
    required this.spentCents,
    this.lastVisit,
    this.usualService,
  });

  final Client client;
  final int visitCount;
  final int spentCents;
  final DateTime? lastVisit;

  /// O que ele mais pede. E o que o robo oferece primeiro na conversa.
  final String? usualService;

  int get averageTicketCents => visitCount == 0 ? 0 : spentCents ~/ visitCount;

  /// Sumiu: passou de 45 dias sem aparecer, tendo vindo antes.
  ///
  /// E o cliente que da para trazer de volta com uma mensagem — o mais barato
  /// que existe, porque ele ja conhece a barbearia.
  bool get hasDrifted {
    final last = lastVisit;
    if (last == null) return false;
    return DateTime.now().difference(last).inDays > 45;
  }
}
