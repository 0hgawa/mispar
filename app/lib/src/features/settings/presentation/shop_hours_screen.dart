import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/data/shop_hours_repository.dart';
import 'package:marcos_barber/src/features/agenda/data/shop_settings_repository.dart';
import 'package:marcos_barber/src/features/agenda/data/time_block_repository.dart';
import 'package:marcos_barber/src/features/agenda/domain/shop_hours.dart';
import 'package:marcos_barber/src/features/agenda/domain/time_block.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';

/// A semana padrao da barbearia.
///
/// Um dia por linha, editado ali mesmo — sem abrir outra tela para mudar uma
/// hora. E o desenho do Cal.com: a regra que se repete fica em cima, e as
/// excecoes de um dia especifico sao outro assunto.
class ShopHoursScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded, weight: 500),
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AsyncView(
        value: ref.watch(weekHoursProvider),
        onRetry: () => ref.invalidate(weekHoursProvider),
        builder: (week) => ListView(
          padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
          children: [
            const ScreenTitle(
              title: 'Horários',
              subtitle: 'quando a barbearia abre',
            ),
            for (final day in week.inOrder) _DayRow(hours: day),
            const SizedBox(height: Dimens.gapLarge),
            const _SlotStep(),
            const SizedBox(height: Dimens.gapLarge),
            const _ClosedDays(),
          ],
        ),
      ),
    );
  }
}

/// De quanto em quanto tempo os horarios sao oferecidos.
///
/// Depende da barbearia, nao do app: passo curto encaixa pezinho em qualquer
/// brecha e enche a tela de opcoes; passo longo deixa a lista limpa e perde
/// encaixe. Quem decide e quem atende.
class _SlotStep extends ConsumerWidget {
  const new();

  static const _options = [
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final step = ref.watch(slotStepProvider).value ?? SlotRules.step;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('De quanto em quanto tempo'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.screenGutter,
            0,
            Dimens.screenGutter,
            Dimens.gapMedium,
          ),
          child: Text(
            'O intervalo entre os horários oferecidos ao marcar. O robô do '
            'WhatsApp usa o mesmo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
          child: Wrap(
            spacing: Dimens.gapSmall,
            children: [
              for (final option in _options)
                ChoiceChip(
                  label: Text('${option.inMinutes} min'),
                  selected: option == step,
                  onSelected: (_) => _save(context, ref, option),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Grava e **mostra** quando nao consegue. Engolir o erro num ajuste que
  /// nao muda de estado deixa o Marcos tocando a mesma pilula sem entender.
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    Duration option,
  ) async {
    try {
      await ref.read(shopSettingsRepositoryProvider).saveSlotStep(option);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Não consegui salvar o intervalo.')),
        );
    }
  }
}

/// Os dias fechados fora da semana padrao.
///
/// Sao a excecao: a semana continua a mesma, so estes dias saem dela. E o
/// desenho do Cal.com — regra que se repete em cima, excecao embaixo.
class _ClosedDays extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final blocks =
        ref.watch(upcomingTimeBlocksProvider).value ?? const <TimeBlock>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Dias fechados'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.screenGutter,
            0,
            Dimens.screenGutter,
            Dimens.gapMedium,
          ),
          child: Text(
            'Feriado, médico, viagem. A agenda para de oferecer horário nesses '
            'dias, e quem já estava marcado continua na lista.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final block in blocks) _ClosedRow(block: block),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.screenGutter,
            Dimens.gapMedium,
            Dimens.screenGutter,
            0,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _close(context, ref),
              icon: const Icon(Symbols.event_busy_rounded, size: 20),
              label: const Text('Fechar um dia'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: 'Fechar quais dias',
      saveText: 'Fechar',
    );
    if (range == null || !context.mounted) return;

    final reason = await _askReason(context);
    if (reason == null) return;

    await ref
        .read(timeBlockRepositoryProvider)
        .save(
          TimeBlock.days(
            id: const Uuid().v4(),
            from: range.start,
            to: range.end,
            reason: reason.isEmpty ? null : reason,
          ),
        );
  }

  /// O motivo e opcional: e para o Marcos lembrar daqui a um mes, nao para o
  /// app cobrar explicacao.
  Future<String?> _askReason(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(),
    );
  }
}

/// Pergunta o motivo do fechamento.
///
/// Widget proprio por causa do controlador: descartado no `whenComplete` do
/// dialogo, ele morre enquanto o campo ainda esta montado na animacao de
/// saida, e o app cai. Quem cria, descarta — e no `dispose`.
class _ReasonDialog extends StatefulWidget {
  const new();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Por quê?'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Médico, viagem, feriado… (opcional)',
        ),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Voltar'),
        ),
        TextButton(onPressed: _done, child: const Text('Fechar')),
      ],
    );
  }
}

/// Um fechamento marcado. Tocar o X reabre os dias.
class _ClosedRow extends ConsumerWidget {
  const new({required this.block});

  final TimeBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final first = block.startsAt;
    final last = block.lastDay;
    final when = first.day == last.day && first.month == last.month
        ? formatLongDay(first)
        : '${formatShortDate(first)} – ${formatShortDate(last)}';

    return Column(
      children: [
        const Divider(
          height: 1,
          indent: Dimens.screenGutter,
          endIndent: Dimens.screenGutter,
        ),
        ListTile(
          contentPadding: const EdgeInsets.only(
            left: Dimens.screenGutter,
            right: Dimens.gapSmall,
          ),
          title: Text(
            when,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: block.reason == null
              ? null
              : Text(
                  block.reason!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
          trailing: IconButton(
            icon: const Icon(Symbols.close_rounded, size: 20),
            color: colors.onSurfaceVariant,
            tooltip: 'Reabrir',
            onPressed: () =>
                ref.read(timeBlockRepositoryProvider).delete(block.id).ignore(),
          ),
        ),
      ],
    );
  }
}

/// Um dia da semana: liga/desliga e as horas, tocaveis ali mesmo.
class _DayRow extends ConsumerWidget {
  const new({required this.hours});

  final DayHours hours;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(
          height: 1,
          indent: Dimens.screenGutter,
          endIndent: Dimens.screenGutter,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            Dimens.screenGutter,
            10,
            Dimens.screenGutter,
            hours.isOpen ? 14 : 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _weekdayName(hours.weekday),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hours.isOpen
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!hours.isOpen)
                    Padding(
                      padding: const EdgeInsets.only(right: Dimens.gapSmall),
                      child: Text(
                        'fechado',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Switch(
                    value: hours.isOpen,
                    onChanged: (value) =>
                        _save(ref, hours.copyWith(isOpen: value)),
                  ),
                ],
              ),
              if (hours.isOpen) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    _TimeButton(
                      value: hours.opensAt,
                      label: 'Abre',
                      onPick: (picked) =>
                          _save(ref, hours.copyWith(opensAt: picked)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('—', style: theme.textTheme.bodyMedium),
                    ),
                    _TimeButton(
                      value: hours.closesAt,
                      label: 'Fecha',
                      onPick: (picked) =>
                          _save(ref, hours.copyWith(closesAt: picked)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Symbols.content_copy_rounded, size: 20),
                      color: colors.onSurfaceVariant,
                      tooltip: 'Copiar para os outros dias abertos',
                      onPressed: () => _copyToOthers(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Almoço',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: Dimens.gapSmall),
                    if (hours.hasLunch) ...[
                      _TimeButton(
                        value: hours.lunchStart!,
                        label: 'Começa',
                        isQuiet: true,
                        onPick: (picked) =>
                            _save(ref, hours.copyWith(lunchStart: picked)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '—',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      _TimeButton(
                        value: hours.lunchEnd!,
                        label: 'Termina',
                        isQuiet: true,
                        onPick: (picked) =>
                            _save(ref, hours.copyWith(lunchEnd: picked)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            _save(ref, hours.copyWith(clearLunch: true)),
                        child: const Text('Sem almoço'),
                      ),
                    ] else
                      TextButton(
                        onPressed: () => _save(
                          ref,
                          hours.copyWith(
                            lunchStart: const Duration(hours: 12),
                            lunchEnd: const Duration(hours: 13),
                          ),
                        ),
                        child: const Text('Adicionar'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _save(WidgetRef ref, DayHours updated) {
    // Fechar depois de abrir nao existe. Sem isto o dia sumiria da agenda sem
    // dizer por que.
    if (updated.isOpen && !updated.closesAt.isLongerThan(updated.opensAt)) {
      return;
    }
    ref.read(shopHoursRepositoryProvider).save(updated).ignore();
  }

  /// Copia estas horas para todos os outros dias que estao abertos.
  ///
  /// Barbearia costuma ter o mesmo horario a semana toda; ajustar sete vezes
  /// seria trabalho a toa.
  Future<void> _copyToOthers(BuildContext context, WidgetRef ref) async {
    final week = ref.read(weekHoursProvider).value;
    if (week == null) return;

    final repository = ref.read(shopHoursRepositoryProvider);
    for (final other in week.inOrder) {
      if (other.weekday == hours.weekday || !other.isOpen) continue;
      await repository.save(
        other.copyWith(
          opensAt: hours.opensAt,
          closesAt: hours.closesAt,
          lunchStart: hours.lunchStart,
          lunchEnd: hours.lunchEnd,
          clearLunch: !hours.hasLunch,
        ),
      );
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('Copiado para os outros dias abertos.')),
      );
  }

  String _weekdayName(int weekday) => switch (weekday) {
    DateTime.monday => 'Segunda',
    DateTime.tuesday => 'Terça',
    DateTime.wednesday => 'Quarta',
    DateTime.thursday => 'Quinta',
    DateTime.friday => 'Sexta',
    DateTime.saturday => 'Sábado',
    _ => 'Domingo',
  };
}

extension on Duration {
  bool isLongerThan(Duration other) => inMinutes > other.inMinutes;
}

/// Uma hora tocavel. Abre o relogio do sistema.
class _TimeButton extends StatelessWidget {
  const new({
    required this.value,
    required this.label,
    required this.onPick,
    this.isQuiet = false,
  });

  final Duration value;
  final String label;
  final ValueChanged<Duration> onPick;
  final bool isQuiet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.secondaryContainer,
      borderRadius: BorderRadius.circular(Dimens.pillRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _pick(context),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isQuiet ? 10 : 14,
            vertical: isQuiet ? 5 : 8,
          ),
          child: Text(
            _asText(value),
            style:
                (isQuiet
                        ? theme.textTheme.bodySmall
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value.inHours, minute: value.inMinutes % 60),
      helpText: label,
      cancelText: 'Voltar',
      confirmText: 'Usar',
    );
    if (picked == null) return;
    onPick(Duration(hours: picked.hour, minutes: picked.minute));
  }

  String _asText(Duration value) {
    final hour = value.inHours.toString().padLeft(2, '0');
    final minute = (value.inMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
