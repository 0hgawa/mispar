import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marcos_barber/src/core/router/app_router.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/presentation/day_view_model.dart';
import 'package:marcos_barber/src/features/agenda/presentation/widgets/day_view.dart';
import 'package:marcos_barber/src/features/agenda/presentation/widgets/week_view.dart';
import 'package:marcos_barber/src/features/booking/presentation/new_appointment_view_model.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/widgets/segmented_toggle.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Como o Marcos esta olhando a agenda agora.
enum AgendaView { day, week }

class AgendaViewChoice extends Notifier<AgendaView> {
  @override
  AgendaView build() => AgendaView.day;

  void select(AgendaView view) => state = view;
}

final agendaViewProvider = NotifierProvider<AgendaViewChoice, AgendaView>(
  AgendaViewChoice.new,
);

/// Um calendario so, com modos de ver.
///
/// E o que Fresha, Booksy e Squire fazem: dia e semana sao formas de olhar a
/// mesma agenda, nunca destinos diferentes na barra. "Hoje" nao e um lugar —
/// e o dia que vem selecionado.
class AgendaScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(agendaViewProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        // Marca no dia que esta na tela, e nao em hoje: o Marcos abriu sexta
        // para marcar em sexta.
        onPressed: () {
          ref
              .read(bookingProvider.notifier)
              .startOnDay(ref.read(selectedDayProvider));
          unawaited(context.push(Routes.newAppointment));
        },
        tooltip: 'Marcar horário',
        child: const Icon(Symbols.add_rounded, weight: 600, size: 28),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: view == AgendaView.day
                    ? const DayView(key: ValueKey('dia'))
                    : const WeekView(key: ValueKey('semana')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Titulo do dia escolhido, com o acesso ao calendario para pular de data.
class _Header extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = ref.watch(selectedDayProvider);
    final isOpen = ref.watch(monthOpenProvider);
    // Aberta, a grade manda no titulo: ela pode estar em novembro enquanto o
    // dia escolhido continua em setembro.
    final shown = ref.watch(visibleMonthProvider) ?? day;
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        8,
        Dimens.screenGutter,
        Dimens.gapMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // O dia sai daqui quando e hoje: "Hoje" ja diz tudo, e a
                  // regua logo abaixo mostra o numero.
                  isToday ? 'Hoje' : formatWeekdayAndDay(day),
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              const _ViewToggle(),
            ],
          ),
          // A propria data abre o calendario, e o calendario e a regua de
          // baixo crescendo. Um calendario so, em dois tamanhos.
          InkWell(
            onTap: ref.read(monthOpenProvider.notifier).toggle,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      // Mes e ano: e o que a regua de dias nao consegue dizer,
                      // e o que some quando ele pula para novembro.
                      formatMonthAndYear(shown),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 2),
                  // A seta vira, como em qualquer coisa que abre e fecha.
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Symbols.expand_more_rounded,
                      size: 18,
                      weight: 500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dia ou Semana, do jeito que o resto do app faz segmentado.
class _ViewToggle extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedToggle(
      options: const [
        (value: AgendaView.day, label: 'Dia'),
        (value: AgendaView.week, label: 'Semana'),
      ],
      selected: ref.watch(agendaViewProvider),
      onSelect: ref.read(agendaViewProvider.notifier).select,
    );
  }
}
