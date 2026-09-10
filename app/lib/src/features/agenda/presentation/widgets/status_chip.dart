import 'package:flutter/material.dart';
import 'package:marcos_barber/src/core/theme/status_colors.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment_status.dart';

/// Situacao do horario.
///
/// **Confirmado nao mostra nada** — e o estado normal, e marcar todo horario
/// normal com um selo so vira ruido. O acento vermelho aparece so onde ha
/// problema: falta e horario sem resposta.
class StatusChip extends StatelessWidget {
  const new(this.status, {super.key});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final alert = theme.status.alert;

    final (label, background, foreground) = switch (status) {
      AppointmentStatus.confirmed => (null, null, null),
      AppointmentStatus.awaiting => (
        'Aguardando',
        alert.withValues(alpha: 0.12),
        alert,
      ),
      AppointmentStatus.depositPaid => (
        'Sinal pago',
        colors.primary,
        colors.onPrimary,
      ),
      AppointmentStatus.done => (
        'Atendido',
        colors.secondaryContainer,
        colors.onSurfaceVariant,
      ),
      AppointmentStatus.noShow => ('Faltou', alert, colors.onError),
      AppointmentStatus.cancelled => (
        'Desmarcado',
        colors.secondaryContainer,
        colors.onSurfaceVariant,
      ),
    };

    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}
