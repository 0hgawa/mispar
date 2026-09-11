import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/presentation/widgets/day_strip.dart';
import 'package:marcos_barber/src/features/booking/presentation/new_appointment_view_model.dart';
import 'package:marcos_barber/src/features/booking/presentation/widgets/client_picker.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/widgets/app_snack.dart';
import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:marcos_barber/src/shared/widgets/bottom_action.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Marcar horario na mao — para quem chega sem avisar.
///
/// Tudo numa rolagem so: quem, o que, quando. Passo a passo em telas separadas
/// custaria tres transicoes para uma tarefa de trinta segundos.
class NewAppointmentScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.close_rounded, weight: 500),
          tooltip: 'Fechar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          ScreenTitle(
            title: draft.isEditing ? 'Remarcar' : 'Marcar',
            // Com a hora junto, o dia por extenso nao cabe numa linha so.
            subtitle: draft.cameFromSlot
                ? '${formatWeekdayAndDay(draft.day)} · '
                      '${formatHour(draft.preferredStart!)}'
                : formatLongDay(draft.day),
          ),
          const SectionLabel('Quem'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
            child: ClientPicker(),
          ),
          const SectionLabel('O que'),
          const _ServiceChoice(),
          if (draft.service != null) ...[
            const SectionLabel('Quando'),
            // Veio de uma vaga: o dia ja foi escolhido na agenda, entao a
            // regua so aparece se ele pedir para trocar.
            if (!draft.cameFromSlot)
              DayStrip(
                selected: draft.day,
                onSelect: ref.read(bookingProvider.notifier).chooseDay,
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Dimens.screenGutter,
                  0,
                  Dimens.screenGutter,
                  Dimens.gapSmall,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        ref.read(bookingProvider.notifier).chooseDay(draft.day),
                    icon: const Icon(Symbols.edit_calendar_rounded, size: 18),
                    label: const Text('Trocar de dia'),
                  ),
                ),
              ),
            const _TimeChoice(),
          ],
        ],
      ),
      bottomNavigationBar: const _Submit(),
    );
  }
}

class _ServiceChoice extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(bookingProvider).service;

    return AsyncView(
      value: ref.watch(bookableServicesProvider),
      onRetry: () => ref.invalidate(bookableServicesProvider),
      builder: (services) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
        child: Wrap(
          spacing: Dimens.gapSmall,
          runSpacing: Dimens.gapSmall,
          children: [
            for (final service in services)
              ChoiceChip(
                selected: service.id == chosen?.id,
                onSelected: (_) =>
                    ref.read(bookingProvider.notifier).chooseService(service),
                label: Text(
                  '${service.name} · ${formatMoney(service.priceCents)}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimeChoice extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingProvider);
    final chosen = draft.startsAt;

    // A vaga escolhida na agenda vira o horario marcado assim que o servico
    // couber nela. Sem isto o Marcos escolheria a mesma hora duas vezes.
    ref.listen(bookableTimesProvider, (_, next) {
      final times = next.value?.times;
      final preferred = draft.preferredStart;
      if (times == null || preferred == null || draft.startsAt != null) return;
      if (times.contains(preferred)) {
        ref.read(bookingProvider.notifier).chooseTime(preferred);
      }
    });

    return AsyncView(
      value: ref.watch(bookableTimesProvider),
      onRetry: () => ref.invalidate(bookableTimesProvider),
      builder: (result) {
        final times = result.times;
        if (times.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
            ),
            child: Text(
              switch (result.reason) {
                NoTimeReason.closed =>
                  'A barbearia não abre neste dia. Escolha outro acima.',
                NoTimeReason.blocked =>
                  'Este dia está fechado — feriado, médico ou viagem. '
                      'Escolha outro acima.',
                NoTimeReason.past =>
                  'Os horários de hoje já passaram. Escolha outro dia acima.',
                NoTimeReason.full =>
                  'Este dia já está cheio para esse serviço. Escolha outro '
                      'acima.',
                null => 'Escolha um serviço para ver os horários.',
              },
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
          child: Wrap(
            spacing: Dimens.gapSmall,
            runSpacing: Dimens.gapSmall,
            children: [
              for (final time in times)
                ChoiceChip(
                  selected: time == chosen,
                  onSelected: (_) =>
                      ref.read(bookingProvider.notifier).chooseTime(time),
                  label: Text(formatHour(time)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Submit extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_Submit> createState() => _SubmitState();
}

class _SubmitState extends ConsumerState<_Submit> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingProvider);
    final theme = Theme.of(context);

    return BottomAction(
      // Resumo do que vai ser gravado, para conferir sem rolar de volta.
      caption: draft.isComplete
          ? Text(
              '${draft.service!.name} às ${formatHour(draft.startsAt!)} · '
              '${formatMoney(draft.service!.priceCents)}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      child: FilledButton(
        onPressed: draft.isComplete && !_saving ? _save : null,
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(draft.isEditing ? 'Salvar' : 'Marcar horário'),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final draft = ref.read(bookingProvider);
    final submit = ref.read(bookingSubmitterProvider);

    try {
      final name = await submit(draft);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(
        context,
        draft.isEditing
            ? '$name remarcado para ${formatHour(draft.startsAt!)}.'
            : '$name marcado às ${formatHour(draft.startsAt!)}.',
      );
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Não consegui marcar. Tente de novo.');
    }
  }
}
