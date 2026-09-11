import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marcos_barber/src/core/router/app_router.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/core/theme/status_colors.dart';
import 'package:marcos_barber/src/features/agenda/data/agenda_repository.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment_status.dart';
import 'package:marcos_barber/src/features/agenda/domain/payment_method.dart';
import 'package:marcos_barber/src/features/agenda/domain/reminder.dart';
import 'package:marcos_barber/src/features/booking/presentation/new_appointment_view_model.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/whatsapp.dart';
import 'package:marcos_barber/src/shared/widgets/app_snack.dart';
import 'package:marcos_barber/src/shared/widgets/confirm.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Folha do horario: o gosto do cliente em destaque e as acoes que o Marcos
/// toma de verdade na cadeira.
class AppointmentSheet extends ConsumerStatefulWidget {
  const new(this.appointment, {super.key});

  final Appointment appointment;

  static Future<void> show(BuildContext context, Appointment appointment) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // Cobre a barra de abas: o que esta aberto e modal, e por baixo dele
      // nao ha para onde ir.
      useRootNavigator: true,
      // Anotacao comprida faz a folha crescer; sem isto ela estoura.
      isScrollControlled: true,
      builder: (_) => AppointmentSheet(appointment),
    );
  }

  @override
  ConsumerState<AppointmentSheet> createState() => _AppointmentSheetState();
}

class _AppointmentSheetState extends ConsumerState<AppointmentSheet> {
  /// Depois de tocar em concluir, a folha pergunta como recebeu — no lugar,
  /// sem abrir outra por cima.
  bool _asking = false;

  Appointment get appointment => widget.appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final note = appointment.client.note;
    final isClosed =
        appointment.status == AppointmentStatus.done ||
        appointment.status == AppointmentStatus.noShow;

    Future<void> mark(
      AppointmentStatus status,
      String toast, {
      PaymentMethod? paidWith,
    }) async {
      await ref
          .read(agendaRepositoryProvider)
          .updateStatus(appointment.id, status, paidWith: paidWith);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      showSnack(context, toast);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Dimens.screenGutter,
          0,
          Dimens.screenGutter,
          Dimens.screenGutter,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${formatHour(appointment.startsAt)} — '
                '${formatHour(appointment.endsAt)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                appointment.client.name,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 3),
              Text(
                '${appointment.service.name} · '
                '${formatMoney(appointment.priceCents)} · '
                '${appointment.client.phone}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: Dimens.gapMedium),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Dimens.cardPadding),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(Dimens.cardRadius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DO JEITO QUE ELE GOSTA',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(note, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Dimens.gapLarge),

              if (isClosed) ...[
                if (appointment.paidWith != null) ...[
                  Text(
                    'Recebido em ${appointment.paidWith!.label.toLowerCase()}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Dimens.gapMedium),
                ],
                // Ja fechado: a unica saida e desfazer, sem oferecer o resto.
                OutlinedButton(
                  onPressed: () =>
                      mark(AppointmentStatus.confirmed, 'Horário reaberto.'),
                  child: const Text('Reabrir horário'),
                ),
              ] else if (_asking) ...[
                Text('Recebeu como?', style: theme.textTheme.titleMedium),
                const SizedBox(height: Dimens.gapSmall),
                Row(
                  children: [
                    for (final method in PaymentMethod.values) ...[
                      if (method != PaymentMethod.values.first)
                        const SizedBox(width: Dimens.gapSmall),
                      Expanded(
                        child: FilledButton(
                          // Tres botoes numa linha: com o recuo padrao,
                          // "Dinheiro" quebra em duas linhas.
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () => mark(
                            AppointmentStatus.done,
                            'Atendimento concluído, '
                            '${formatMoney(appointment.priceCents)} '
                            'em ${method.label.toLowerCase()}.',
                            paidWith: method,
                          ),
                          child: Text(
                            method.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Anotar depois nao pode travar a cadeira: o atendimento fecha
                // do mesmo jeito, so sem a forma de pagamento.
                TextButton(
                  onPressed: () =>
                      mark(AppointmentStatus.done, 'Atendimento concluído.'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(Dimens.buttonHeight),
                  ),
                  child: const Text('Anotar depois'),
                ),
              ] else ...[
                FilledButton(
                  onPressed: () => setState(() => _asking = true),
                  child: const Text('Concluir atendimento'),
                ),
                const SizedBox(height: Dimens.gapSmall),
                // Falta e o que mais custa caro na cadeira, e o lembrete e o
                // que mais reduz. Vai com o texto pronto: o Marcos so revisa
                // e manda.
                OutlinedButton.icon(
                  onPressed: () => _remind(context),
                  icon: const Icon(Symbols.chat_rounded, size: 20, weight: 500),
                  label: const Text('Lembrar no WhatsApp'),
                ),
                const SizedBox(height: Dimens.gapSmall),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _reschedule(context),
                        child: const Text('Remarcar'),
                      ),
                    ),
                    const SizedBox(width: Dimens.gapSmall),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => mark(
                          AppointmentStatus.noShow,
                          '${appointment.client.name} marcado como falta.',
                        ),
                        child: const Text('Não apareceu'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => _confirmCancel(context),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(Dimens.buttonHeight),
                    foregroundColor: theme.status.alert,
                  ),
                  child: const Text('Desmarcar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Abre a conversa com o texto do lembrete pronto.
  Future<void> _remind(BuildContext context) async {
    final opened = await openWhatsApp(
      appointment.client.phone,
      message: reminderMessage(appointment, now: DateTime.now()),
    );

    if (opened || !context.mounted) return;
    showSnack(context, 'Não consegui abrir o WhatsApp.');
  }

  void _reschedule(BuildContext context) {
    ref
        .read(bookingProvider.notifier)
        .startEditing(
          appointmentId: appointment.id,
          client: appointment.client,
          service: appointment.service,
          startsAt: appointment.startsAt,
        );
    Navigator.of(context).pop();
    unawaited(context.push(Routes.newAppointment));
  }

  Future<void> _confirmCancel(BuildContext context) async {
    // Desmarcar libera o horario para outra pessoa e nao da para desfazer com
    // um toque. Perguntar aqui custa dois segundos.
    final confirmed = await askToConfirm(
      context,
      title: 'Desmarcar?',
      message:
          'O horário de ${appointment.client.name} às '
          '${formatHour(appointment.startsAt)} volta a ficar livre.',
      confirmLabel: 'Desmarcar',
    );

    if (!confirmed) return;

    await ref
        .read(agendaRepositoryProvider)
        .updateStatus(appointment.id, AppointmentStatus.cancelled);

    if (!context.mounted) return;
    Navigator.of(context).pop();
    showSnack(
      context,
      '${appointment.client.name} desmarcado. O horário está livre.',
    );
  }
}
