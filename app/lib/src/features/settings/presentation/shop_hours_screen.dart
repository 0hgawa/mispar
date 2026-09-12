import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/features/agenda/data/shop_hours_repository.dart';
import 'package:mispar/src/features/agenda/data/shop_settings_repository.dart';
import 'package:mispar/src/features/agenda/data/time_block_repository.dart';
import 'package:mispar/src/features/agenda/domain/shop_hours.dart';
import 'package:mispar/src/features/agenda/domain/time_block.dart';
import 'package:mispar/src/shared/formatters/day_time.dart';
import 'package:mispar/src/shared/widgets/app_sheet.dart';
import 'package:mispar/src/shared/widgets/app_snack.dart';
import 'package:mispar/src/shared/widgets/async_view.dart';
import 'package:mispar/src/shared/widgets/page_bar.dart';
import 'package:mispar/src/shared/widgets/screen_title.dart';
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
      body: AsyncView(
        value: ref.watch(weekHoursProvider),
        onRetry: () => ref.invalidate(weekHoursProvider),
        builder: (week) => CustomScrollView(
          slivers: [
            const PageBar(title: 'Horários'),
            const SliverToBoxAdapter(
              child: PageSubtitle('quando a barbearia abre'),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
              sliver: SliverList.list(
                children: [
                  for (final day in week.inOrder) _DayRow(hours: day),
                  const SizedBox(height: Dimens.gapLarge),
                  const _SlotStep(),
                  const SizedBox(height: Dimens.gapLarge),
                  const _ClosedDays(),
                ],
              ),
            ),
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
      showSnack(context, 'Não consegui salvar o intervalo.');
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
  ///
  /// Folha de baixo, e nao dialogo: dialogo e para decidir, nao para digitar.
  /// No celular o teclado sobe e come o dialogo inteiro, sobrando uma faixa no
  /// meio da tela com um campo apertado.
  Future<String?> _askReason(BuildContext context) {
    return showAppSheet<String>(
      context,
      title: 'Por quê?',
      builder: (sheetContext) => const _ReasonField(),
    );
  }
}

/// O campo do motivo, dentro da folha.
///
/// Widget proprio por causa do controlador: quem cria, descarta — e no
/// `dispose`. Descartado de fora, ele morre enquanto o campo ainda esta
/// montado na animacao de saida, e o app cai.
class _ReasonField extends StatefulWidget {
  const new();

  @override
  State<_ReasonField> createState() => _ReasonFieldState();
}

class _ReasonFieldState extends State<_ReasonField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _done(),
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Médico, viagem, feriado… (opcional)',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              filled: true,
              fillColor: colors.secondaryContainer,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Dimens.pillRadius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: Dimens.gapMedium),
          FilledButton(onPressed: _done, child: const Text('Fechar o dia')),
        ],
      ),
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
    showSnack(context, 'Copiado para os outros dias abertos.');
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
