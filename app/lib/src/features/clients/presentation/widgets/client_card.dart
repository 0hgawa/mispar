import 'package:flutter/material.dart';
import 'package:marcos_barber/src/features/clients/domain/client_summary.dart';
import 'package:marcos_barber/src/features/clients/presentation/widgets/client_row.dart';

class ClientCard extends StatelessWidget {
  const new({required this.summary, required this.onTap, super.key});

  final ClientSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final client = summary.client;

    return ClientRow(
      name: client.name,
      // Sempre o telefone, e nunca a anotacao ou o servico de sempre.
      //
      // A linha de baixo tinha tres significados possiveis, um por cliente, e
      // o olho nao consegue confiar num lugar que muda de assunto. O telefone
      // e o unico campo que todo mundo tem, e e ele que separa dois "Joao" na
      // lista. A anotacao fica na ficha, que e o que se abre antes de atender.
      detail: client.phone,
      detailLines: 1,
      onTap: onTap,
    );
  }
}
