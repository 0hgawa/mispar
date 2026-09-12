import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/core/router/app_router.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/core/theme/status_colors.dart';
import 'package:mispar/src/features/agenda/data/agenda_repository.dart';
import 'package:mispar/src/features/agenda/data/shop_settings_repository.dart';
import 'package:mispar/src/features/agenda/domain/appointment.dart';
import 'package:mispar/src/features/agenda/domain/appointment_status.dart';
import 'package:mispar/src/features/agenda/domain/payment_method.dart';
import 'package:mispar/src/features/agenda/domain/reminder.dart';
import 'package:mispar/src/features/booking/presentation/new_appointment_view_model.dart';
import 'package:mispar/src/features/clients/domain/client.dart';
import 'package:mispar/src/features/reports/presentation/income_form.dart';
import 'package:mispar/src/shared/formatters/day_time.dart';
import 'package:mispar/src/shared/formatters/money.dart';
import 'package:mispar/src/shared/formatters/phone.dart';
import 'package:mispar/src/shared/whatsapp.dart';
import 'package:mispar/src/shared/widgets/app_snack.dart';
import 'package:mispar/src/shared/widgets/confirm.dart';

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
    // Lancado direto no Caixa nao tem cliente: nao ha anotacao, nao ha
    // telefone, e nao ha o que lembrar ou remarcar.
    final client = appointment.client;
    final note = client?.note;
    final isClosed =
        appointment.status == AppointmentStatus.done ||
        appointment.status == AppointmentStatus.noShow;
    // A hora chegou. Marcada pelo **inicio**, e nao pelo fim: as 12:31 de um
    // horario das 12:30 ele ja nao apareceu, e nao ha mais o que lembrar.
    final hasArrived = appointment.startsAt.isBefore(DateTime.now());
    // Como a barbearia mais recebe. Sai do histórico, e não de um ajuste — o
    // mesmo que o robô faz com o serviço de sempre do cliente.
    final usual = ref.watch(usualPaymentProvider).value;
    // So o que a barbearia aceita: maquininha que nao existe nao vira botao.
    final accepted =
        ref.watch(acceptedPaymentsProvider).value ?? PaymentMethod.values;

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
              Text(appointment.who, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 3),
              Text(
                // Filtrado, e nao so condicional: cliente cadastrado pela tela
                // de marcar entra sem telefone, e a linha terminava num ponto
                // solto — "Corte · R$ 40 ·".
                [
                  appointment.service.name,
                  formatMoney(appointment.priceCents),
                  if (client != null) formatPhone(client.phone),
                ].where((parte) => parte.isNotEmpty).join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              // A anotacao aparece sempre que ha ficha — com ou sem texto.
              //
              // Vazia ela vira convite, e o toque abre a ficha: e na hora de
              // chamar o proximo que se lembra do que ele nao gosta, e nao
              // depois, procurando na aba de clientes. Antes o bloco so
              // existia para quem ja tinha anotado, e quem nunca anotou nao
              // descobria que dava.
              if (client != null) ...[
                const SizedBox(height: Dimens.gapLarge),
                Material(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(Dimens.cardRadius),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      unawaited(context.push(Routes.clientDetail(client.id)));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(Dimens.cardPadding),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
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
                                Text(
                                  note ??
                                      'Nada anotado ainda. Toque para '
                                          'escrever o corte de sempre.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: note == null
                                        ? colors.onSurfaceVariant
                                        : colors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Dimens.gapSmall),
                          Icon(
                            Symbols.chevron_right_rounded,
                            size: 20,
                            weight: 500,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Dimens.gapLarge),

              if (isClosed) ...[
                if (appointment.paidWith != null) ...[
                  Text(
                    // 'Pix' e nome proprio: minusculo ali ficava errado.
                    'Recebido em ${appointment.paidWith!.label}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Dimens.gapMedium),
                ],
                // Venda de balcao e coisa que o Marcos digitou, e se corrige
                // no mesmo formulario que a criou — o mesmo que a despesa faz.
                // Reabrir nao serve: ela nunca esteve marcada.
                if (appointment.isWalkIn)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(IncomeForm.show(context, entry: appointment));
                    },
                    child: const Text('Editar lançamento'),
                  )
                else
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
                    for (final method in accepted) ...[
                      if (method != accepted.first)
                        const SizedBox(width: Dimens.gapSmall),
                      Expanded(
                        // Preto so na que a barbearia mais usa; as outras
                        // tonais. O Material admite um preenchido por tela, e
                        // tres pretos lado a lado nao fazem hierarquia: fazem
                        // briga, e ainda sugerem que um deles e o certo.
                        //
                        // Sem historico ainda, `usual` e nulo e as tres saem
                        // iguais — nao se inventa padrao antes de ter dado.
                        //
                        // O recuo e menor porque "Dinheiro" quebra em duas
                        // linhas com o recuo padrao.
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            backgroundColor: method == usual
                                ? colors.primary
                                : colors.secondaryContainer,
                            foregroundColor: method == usual
                                ? colors.onPrimary
                                : colors.onSecondaryContainer,
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
                // Sem "anotar depois".
                //
                // Ele nao economizava toque nenhum — sair por ele custava o
                // mesmo um toque que dizer "Pix" — e fechava o atendimento
                // **sem** forma de pagamento. O Caixa contava o dinheiro como
                // recebido do mesmo jeito, entao um fiado virava R$ 40 que a
                // barbearia acha que tem e nao tem.
                //
                // Com ele fora, todo atendimento concluido tem forma de
                // pagamento, e o extrato volta a servir para conferir a
                // maquininha. Fiado e outro problema, e vai ter tela propria.
              ] else if (client != null) ...[
                FilledButton(
                  onPressed: () => setState(() => _asking = true),
                  child: const Text('Concluir atendimento'),
                ),
                const SizedBox(height: Dimens.gapMedium),
                // As duas trocam de lugar conforme a hora, e nunca aparecem
                // juntas: lembrar depois que o horario passou nao serve para
                // nada, e marcar falta antes de a hora chegar e adivinhacao.
                // Uma de cada vez deixa a folha com o que cabe fazer agora.
                if (!hasArrived)
                  // Falta e o que mais custa caro na cadeira, e o lembrete e
                  // o que mais reduz. Vai com o texto pronto: o Marcos so
                  // revisa e manda.
                  OutlinedButton.icon(
                    onPressed: () => _remind(context, client),
                    icon: const Icon(
                      Symbols.chat_rounded,
                      size: 20,
                      weight: 500,
                    ),
                    label: const Text('Lembrar no WhatsApp'),
                  )
                else
                  OutlinedButton(
                    onPressed: () => mark(
                      AppointmentStatus.noShow,
                      '${client.name} marcado como falta.',
                    ),
                    child: const Text('Não apareceu'),
                  ),
                const SizedBox(height: Dimens.gapMedium),
                OutlinedButton(
                  onPressed: () => _reschedule(context, client),
                  child: const Text('Remarcar'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => _confirmCancel(context, client),
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
  Future<void> _remind(BuildContext context, Client client) async {
    final opened = await openWhatsApp(
      client.phone,
      message: reminderMessage(
        name: client.name,
        service: appointment.service.name,
        startsAt: appointment.startsAt,
        now: DateTime.now(),
      ),
    );

    if (opened || !context.mounted) return;
    showSnack(context, 'Não consegui abrir o WhatsApp.');
  }

  void _reschedule(BuildContext context, Client client) {
    ref
        .read(bookingProvider.notifier)
        .startEditing(
          appointmentId: appointment.id,
          client: client,
          service: appointment.service,
          startsAt: appointment.startsAt,
        );
    Navigator.of(context).pop();
    unawaited(context.push(Routes.newAppointment));
  }

  Future<void> _confirmCancel(BuildContext context, Client client) async {
    // Desmarcar libera o horario para outra pessoa e nao da para desfazer com
    // um toque. Perguntar aqui custa dois segundos.
    final confirmed = await askToConfirm(
      context,
      title: 'Desmarcar?',
      message:
          'O horário de ${client.name} às '
          '${formatHour(appointment.startsAt)} volta a ficar livre.',
      confirmLabel: 'Desmarcar',
    );

    if (!confirmed) return;

    await ref
        .read(agendaRepositoryProvider)
        .updateStatus(appointment.id, AppointmentStatus.cancelled);

    if (!context.mounted) return;
    Navigator.of(context).pop();
    showSnack(context, '${client.name} desmarcado. O horário está livre.');
  }
}
