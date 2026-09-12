import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/core/router/app_router.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/features/agenda/presentation/day_view_model.dart';
import 'package:mispar/src/features/agenda/presentation/widgets/day_strip.dart';
import 'package:mispar/src/features/agenda/presentation/widgets/day_view.dart';
import 'package:mispar/src/features/agenda/presentation/widgets/share_slots_screen.dart';
import 'package:mispar/src/features/agenda/presentation/widgets/week_view.dart';
import 'package:mispar/src/features/booking/presentation/new_appointment_view_model.dart';
import 'package:mispar/src/features/reports/presentation/income_form.dart';
import 'package:mispar/src/shared/formatters/day_time.dart';

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
    final isPast = hasPassed(ref.watch(selectedDayProvider));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        // Marca no dia que esta na tela, e nao em hoje: o Marcos abriu sexta
        // para marcar em sexta.
        //
        // Em dia que ja passou o botao muda de tarefa em vez de falhar. Hora
        // vencida nao se reserva — mas o corte que aconteceu ali ainda tem que
        // entrar no Caixa, e era exatamente isso que o formulario de marcar
        // deixava preencher para depois nao salvar.
        onPressed: () {
          final day = ref.read(selectedDayProvider);
          if (hasPassed(day)) {
            unawaited(IncomeForm.show(context, at: day));
            return;
          }
          ref.read(bookingProvider.notifier).startOnDay(day);
          unawaited(context.push(Routes.newAppointment));
        },
        tooltip: isPast ? 'Lançar atendimento' : 'Marcar horário',
        child: const Icon(Symbols.add_rounded, weight: 600, size: 28),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            const _Days(),
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

/// A regua de dias, acima das duas visoes.
///
/// Fica na aba, e nao dentro do Dia, porque a Semana precisa dela do mesmo
/// jeito: a semana que a lista mostra e a do dia escolhido, e sem a regua nao
/// havia como trocar de semana sem voltar para o Dia. O mes abre por cima nas
/// duas.
///
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
        // Menos à direita porque o botão de ícone traz o recuo dele: é o
        // mesmo acerto do cabeçalho do Caixa, para os dois alinharem.
        Dimens.gapSmall,
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
              const _Advertise(),
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

/// Divulgar os horários que sobraram no dia.
///
/// Só aparece quando há o que oferecer: dia cheio não se divulga, e botão que
/// não faz nada é pior que botão nenhum.
class _Advertise extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours = ref.watch(slotsToAdvertiseProvider).value ?? const [];
    if (hours.isEmpty) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Symbols.ios_share_rounded, weight: 500),
      tooltip: 'Divulgar horário',
      onPressed: () => unawaited(
        ShareSlotsScreen.show(
          context,
          day: ref.read(selectedDayProvider),
          hours: hours,
        ),
      ),
    );
  }
}

/// Trocar entre Dia e Semana: os ícones de densidade — três traços para a
/// semana, dois para o dia.
///
/// Eles dizem a mesma coisa que os rótulos "Dia" e "Semana" diziam, mas pelo
/// desenho — mais linhas é mais dia na tela. E não pintam de preto mais um
/// pedaço de uma tela que já tem o dia escolhido e o botão de marcar.
///
/// O desenho mostra **para onde se vai**, e não onde se está; a dica de toque
/// repete em palavras.
class _ViewToggle extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDay = ref.watch(agendaViewProvider) == AgendaView.day;

    return IconButton(
      icon: Icon(
        isDay ? Symbols.density_medium_rounded : Symbols.density_large_rounded,
        weight: 500,
      ),
      tooltip: isDay ? 'Ver a semana' : 'Ver o dia',
      onPressed: () {
        ref
            .read(agendaViewProvider.notifier)
            .select(isDay ? AgendaView.week : AgendaView.day);
        ref.read(monthOpenProvider.notifier).close();
      },
    );
  }
}
