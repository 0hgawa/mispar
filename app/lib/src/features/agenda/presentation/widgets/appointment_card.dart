import 'package:flutter/material.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment_status.dart';
import 'package:marcos_barber/src/features/agenda/presentation/widgets/status_chip.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/widgets/app_card.dart';

class AppointmentCard extends StatelessWidget {
  const new({required this.appointment, required this.onTap, super.key});

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isPast =
        appointment.status == AppointmentStatus.done ||
        appointment.status == AppointmentStatus.noShow;

    return AppCard(
      onTap: onTap,
      child: Opacity(
        // Atendido e falta ja passaram: continuam legiveis, param de disputar
        // atencao com o que ainda vai acontecer.
        opacity: isPast ? 0.45 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha de dados: hora, duracao e preco. Tudo na grotesca.
            Row(
              children: [
                Text(
                  formatHour(appointment.startsAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  formatDuration(appointment.duration),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  formatMoney(appointment.priceCents),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // O nome e o heroi do card.
            Text(appointment.client.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    appointment.service.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                StatusChip(appointment.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
