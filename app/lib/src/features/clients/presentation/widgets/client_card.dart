import 'package:flutter/material.dart';
import 'package:marcos_barber/src/core/theme/status_colors.dart';
import 'package:marcos_barber/src/features/clients/domain/client_summary.dart';
import 'package:marcos_barber/src/features/clients/presentation/widgets/client_row.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';

class ClientCard extends StatelessWidget {
  const new({required this.summary, required this.onTap, super.key});

  final ClientSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final client = summary.client;

    return ClientRow(
      name: client.name,
      // A anotacao ganha a linha de baixo. E o que faz o Marcos parecer que
      // lembra de todo mundo; sem ela, mostra o que a pessoa costuma pedir.
      detail: client.note ?? summary.usualService ?? client.phone,
      trailing: _Recency(summary: summary),
      onTap: onTap,
    );
  }
}

class _Recency extends StatelessWidget {
  const new({required this.summary});

  final ClientSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lastVisit = summary.lastVisit;

    // Fora da lista vem antes de tudo: e o que explica por que ele nao
    // aparece na busca ao marcar.
    if (!summary.client.isActive) {
      return Text(
        'fora da lista',
        style: theme.textTheme.labelMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      );
    }

    if (lastVisit == null) {
      return Text(
        'novo',
        style: theme.textTheme.labelMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      );
    }

    // Quem sumiu ganha o unico acento da tela: e o cliente que da para trazer
    // de volta com uma mensagem.
    if (summary.hasDrifted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: ShapeDecoration(
          color: theme.status.alert.withValues(alpha: 0.12),
          shape: const StadiumBorder(),
        ),
        child: Text(
          formatTimeAgo(lastVisit),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.status.alert,
          ),
        ),
      );
    }

    return Text(
      formatTimeAgo(lastVisit),
      style: theme.textTheme.labelMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    );
  }
}
