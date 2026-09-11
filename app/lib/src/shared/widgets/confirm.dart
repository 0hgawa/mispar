import 'package:flutter/material.dart';
import 'package:marcos_barber/src/core/theme/status_colors.dart';

/// Pergunta antes de fazer o que nao tem volta.
///
/// Dialogo no centro de proposito: ele interrompe, escurece o resto e nao deixa
/// passar batido. Para "apagar de vez" e exatamente o que se quer — folha de
/// baixo seria confortavel demais para uma decisao dessas.
///
/// Devolve `true` so quando o Marcos confirma; fechar por fora e "nao".
Future<bool> askToConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Voltar',

  /// A acao apaga ou desmarca algo? Entao o botao vai na cor de alerta.
  bool isDestructive = true,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);

      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: theme.status.alert)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return answer ?? false;
}
