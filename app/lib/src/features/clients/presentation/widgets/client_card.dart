import 'package:flutter/material.dart';
import 'package:marcos_barber/src/core/theme/status_colors.dart';
import 'package:marcos_barber/src/features/clients/domain/client_summary.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/widgets/app_card.dart';

class ClientCard extends StatelessWidget {
  const new({required this.summary, required this.onTap, super.key});

  final ClientSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final client = summary.client;

    // A anotacao ganha a linha de baixo. E o que faz o Marcos parecer que
    // lembra de todo mundo; sem ela, mostra o que a pessoa costuma pedir.
    final detail = client.note ?? summary.usualService ?? client.phone;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Initials(name: client.name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.name, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _Recency(summary: summary),
        ],
      ),
    );
  }
}

/// Iniciais no lugar de foto: a barbearia nao tem retrato de ninguem, e um
/// circulo vazio seria pior que nada.
class _Initials extends StatelessWidget {
  const new({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length == 1
        ? parts.first.characters.take(1).toString().toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
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
