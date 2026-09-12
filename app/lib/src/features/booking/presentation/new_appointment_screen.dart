import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/features/booking/presentation/new_appointment_view_model.dart';
import 'package:mispar/src/features/booking/presentation/widgets/client_picker.dart';
import 'package:mispar/src/shared/formatters/day_time.dart';
import 'package:mispar/src/shared/formatters/money.dart';
import 'package:mispar/src/shared/widgets/app_snack.dart';
import 'package:mispar/src/shared/widgets/async_view.dart';
import 'package:mispar/src/shared/widgets/bottom_action.dart';
import 'package:mispar/src/shared/widgets/day_button.dart';
import 'package:mispar/src/shared/widgets/screen_title.dart';
import 'package:mispar/src/shared/widgets/task_bar.dart';

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
      appBar: TaskBar(title: draft.isEditing ? 'Remarcar' : 'Marcar'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          // O dia vem antes de tudo, como na despesa e na receita: o teclado
          // abre no campo do nome e come a metade de baixo da tela, e data que
          // nao se ve na hora de confirmar e data que nao se confere.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimens.screenGutter,
              0,
              Dimens.screenGutter,
              Dimens.gapSmall,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: DayButton(
                day: draft.day,
                onTap: () => _pickDay(context, ref, draft.day),
              ),
            ),
          ),
          const SectionLabel('Quem'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
            child: ClientPicker(),
          ),
          const SectionLabel('O que'),
          const _ServiceChoice(),
          // A hora so faz sentido depois do servico: e a duracao dele que
          // decide quais comecos cabem no dia.
          if (draft.service != null) ...[
            const SectionLabel('Que horas'),
            const _TimeChoice(),
          ],
        ],
      ),
      bottomNavigationBar: const _Submit(),
    );
  }
}

/// O calendario do sistema, que pula de mes e aceita a data digitada.
Future<void> _pickDay(
  BuildContext context,
  WidgetRef ref,
  DateTime current,
) async {
  final now = DateTime.now();
  final chosen = await showDatePicker(
    context: context,
    initialDate: current,
    // Ao contrario da despesa, aqui o passado e que nao existe: horario que ja
    // passou nao se reserva.
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: DateTime(now.year + 2),
    helpText: 'Dia do horário',
    cancelText: 'Voltar',
    confirmText: 'Usar',
  );

  if (chosen == null) return;
  ref.read(bookingProvider.notifier).chooseDay(chosen);
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
      //
      // Dia e hora primeiro, e sem o preco: preco nao se decide aqui, vem do
      // servico, e o chip escolhido logo acima ja o mostra. O dia e que subiu
      // para o topo da tela e sai de vista quando o teclado abre — e o unico
      // aqui que, errado, poe o cliente no dia errado.
      caption: draft.isComplete
          ? Text(
              '${formatDayHeading(draft.day)} às '
              '${formatHour(draft.startsAt!)} · ${draft.service!.name}',
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
