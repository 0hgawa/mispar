import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/core/router/app_router.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/features/agenda/domain/day_slot.dart';
import 'package:mispar/src/features/agenda/presentation/day_view_model.dart';
import 'package:mispar/src/features/agenda/presentation/widgets/appointment_card.dart';
import 'package:mispar/src/features/agenda/presentation/widgets/appointment_sheet.dart';
import 'package:mispar/src/features/agenda/presentation/widgets/closed_slot_tile.dart';
import 'package:mispar/src/features/agenda/presentation/widgets/free_slot_tile.dart';
import 'package:mispar/src/features/booking/presentation/new_appointment_view_model.dart';
import 'package:mispar/src/features/reports/presentation/income_form.dart';
import 'package:mispar/src/shared/formatters/money.dart';
import 'package:mispar/src/shared/widgets/app_card.dart';
import 'package:mispar/src/shared/widgets/async_view.dart';
import 'package:mispar/src/shared/widgets/empty_state.dart';

/// O dia: a regua de dias, o numero do dia e a grade de horarios e vagas.
class DayView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: AsyncView(
            value: ref.watch(dayAgendaProvider),
            onRetry: () => ref.invalidate(dayAgendaProvider),
            builder: (agenda) => CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Takings(agenda: agenda)),
                if (agenda.slots.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Symbols.event_available_rounded,
                      title: 'Nada neste dia',
                      message:
                          'O que chegar pelo WhatsApp aparece aqui na hora.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      Dimens.screenGutter,
                      0,
                      Dimens.screenGutter,
                      // Espaco para o botao redondo nao tapar o ultimo card.
                      92,
                    ),
                    sliver: SliverList.separated(
                      itemCount: agenda.slots.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Dimens.cardGap),
                      itemBuilder: (context, index) {
                        final slot = agenda.slots[index];
                        return switch (slot) {
                          BookedSlot(:final appointment) => AppointmentCard(
                            appointment: appointment,
                            onTap: () =>
                                AppointmentSheet.show(context, appointment),
                          ),
                          BlockedSlot() => ClosedSlotTile(slot),
                          FreeSlot() => FreeSlotTile(
                            slot,
                            onTap: () {
                              // A vaga que ja passou abre o lancamento, e nao
                              // a marcacao: ninguem vai sentar na cadeira as
                              // dez da manha de ontem.
                              if (slot.end.isBefore(DateTime.now())) {
                                unawaited(
                                  IncomeForm.show(context, at: slot.start),
                                );
                                return;
                              }
                              ref
                                  .read(bookingProvider.notifier)
                                  .startAtSlot(slot.start);
                              unawaited(context.push(Routes.newAppointment));
                            },
                          ),
                        };
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// O numero do dia — a primeira coisa que o Marcos quer saber.
class _Takings extends StatelessWidget {
  const new({required this.agenda});

  final DayAgenda agenda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        0,
        Dimens.screenGutter,
        Dimens.gapLarge,
      ),
      child: AppCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatMoney(agenda.forecastCents),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text('previstos', style: theme.textTheme.titleMedium),
              ],
            ),
            Text(
              agenda.bookedCount == 1
                  ? '1 horário'
                  : '${agenda.bookedCount} horários',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
