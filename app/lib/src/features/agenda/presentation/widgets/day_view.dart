import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marcos_barber/src/core/router/app_router.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/domain/day_slot.dart';
import 'package:marcos_barber/src/features/agenda/presentation/day_view_model.dart';
import 'package:marcos_barber/src/features/agenda/presentation/widgets/appointment_card.dart';
import 'package:marcos_barber/src/features/agenda/presentation/widgets/appointment_sheet.dart';
import 'package:marcos_barber/src/features/agenda/presentation/widgets/closed_slot_tile.dart';
import 'package:marcos_barber/src/features/agenda/presentation/widgets/day_strip.dart';
import 'package:marcos_barber/src/features/agenda/presentation/widgets/free_slot_tile.dart';
import 'package:marcos_barber/src/features/booking/presentation/new_appointment_view_model.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/widgets/app_card.dart';
import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:marcos_barber/src/shared/widgets/empty_state.dart';
import 'package:material_symbols_icons/symbols.dart';

/// O dia: a regua de dias, o numero do dia e a grade de horarios e vagas.
class DayView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const _Days(),
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

/// Consumer proprio: trocar de dia nao reconstroi a tela inteira.
class _Days extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DayStrip(
      selected: ref.watch(selectedDayProvider),
      expanded: ref.watch(monthOpenProvider),
      onMonthChanged: ref.read(visibleMonthProvider.notifier).show,
      onSelect: (day) {
        ref.read(selectedDayProvider.notifier).select(day);
        // Escolher fecha: a pergunta que abriu a grade acabou de ser
        // respondida, e o dia escolhido esta logo abaixo.
        ref.read(monthOpenProvider.notifier).close();
      },
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
