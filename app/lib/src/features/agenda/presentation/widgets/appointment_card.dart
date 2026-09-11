import 'package:flutter/material.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment_status.dart';
import 'package:marcos_barber/src/features/agenda/presentation/widgets/status_chip.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/widgets/app_card.dart';

/// Um horário marcado, na lista do dia.
///
/// **Duas linhas**: hora, nome e preço em cima; serviço, duração e situação
/// embaixo. É o desenho do Booksy e do Fresha, que também resolvem o card em
/// duas — e card mais baixo é mais dia na tela, que é para isso que a tela
/// serve.
///
/// O nome continua do tamanho que era: dividir a linha com a hora não obriga a
/// encolher o que se procura ao passar o olho.
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
            // Quando, quem e quanto. Alinhados pela base, e nao pelo centro:
            // com dois tamanhos na mesma linha, o centro faz a hora flutuar.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatHour(appointment.startsAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
                // O nome e o heroi do card.
                Expanded(
                  child: Text(
                    appointment.who,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatMoney(appointment.priceCents),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // O que vai ser feito, quanto tempo leva, e o que ha de errado.
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${appointment.service.name} · '
                    '${formatDuration(appointment.duration)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
