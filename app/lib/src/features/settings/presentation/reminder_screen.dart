import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/core/config/env.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/features/agenda/data/agenda_repository.dart';
import 'package:mispar/src/features/agenda/data/shop_settings_repository.dart';
import 'package:mispar/src/features/settings/domain/reminder_settings.dart';
import 'package:mispar/src/shared/formatters/money.dart';
import 'package:mispar/src/shared/widgets/app_card.dart';
import 'package:mispar/src/shared/widgets/app_snack.dart';
import 'package:mispar/src/shared/widgets/page_bar.dart';
import 'package:mispar/src/shared/widgets/screen_title.dart';

/// Quantos lembretes a próxima semana geraria, pela agenda do aparelho.
///
/// Estimativa olhando para a frente, e não conta do que já saiu: enquanto o
/// robô não estiver ligado o que já saiu é sempre zero, e zero não ajuda
/// ninguém a decidir se vale.
///
/// `autoDispose` porque a janela é contada a partir de agora: guardado, ele
/// continuaria somando a semana do dia em que a tela foi aberta pela primeira
/// vez, e deixaria uma consulta de sete dias escutando o banco para sempre.
final StreamProvider<int> remindersNextWeekProvider =
    StreamProvider.autoDispose<int>((ref) {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);

      return ref
          .watch(agendaRepositoryProvider)
          .watchRange(from, from.add(const Duration(days: 7)))
          .map(remindersFor);
    });

/// O lembrete que o robô manda sozinho antes do horário.
///
/// A tela tem três coisas e nada mais: ligar, escolher a antecedência, e ver
/// quanto custa. A terceira existe porque esta é a única parte do robô que
/// cobra — decidir sem o número seria decidir no escuro.
class ReminderScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminder =
        ref.watch(reminderSettingsProvider).value ??
        const ReminderSettings.off();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const PageBar(title: 'Lembrete'),
          const SliverToBoxAdapter(
            child: PageSubtitle('o aviso que sai sozinho antes do horário'),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
            sliver: SliverList.list(
              children: [
                const _HowItWorks(),
                if (!Env.hasBackend) const _Disconnected(),
                _Switch(reminder),
                _HoursBefore(reminder),
                const _Cost(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        0,
        Dimens.screenGutter,
        Dimens.gapMedium,
      ),
      child: Text(
        'Antes do horário, o robô manda uma mensagem pelo WhatsApp com dois '
        'botões: Confirmar e Desmarcar. Quem desmarca ali devolve a cadeira a '
        'tempo, em vez de simplesmente não aparecer.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// O robô mora no servidor, não no aparelho.
///
/// Sem ele configurado o interruptor não tem o que ligar, e deixar o Marcos
/// ligar assim seria prometer mensagem que nunca sai.
class _Disconnected extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        0,
        Dimens.screenGutter,
        Dimens.gapMedium,
      ),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Symbols.info_rounded,
              weight: 500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Dimens.gapSmall),
            Expanded(
              child: Text(
                'O robô do WhatsApp ainda não está ligado nesta instalação. '
                'O ajuste fica guardado e passa a valer quando ele entrar.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Switch extends ConsumerWidget {
  const new(this.reminder);

  final ReminderSettings reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Dimens.screenGutter,
        vertical: 4,
      ),
      value: reminder.isOn,
      onChanged: (isOn) => _save(
        context,
        ref,
        ReminderSettings(isOn: isOn, hoursBefore: reminder.hoursBefore),
      ),
      title: Text(
        'Mandar lembrete',
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Cerca de ${formatMoney(reminderCostCents)} por mensagem',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Com quantas horas de antecedência o lembrete sai.
class _HoursBefore extends ConsumerWidget {
  const new(this.reminder);

  final ReminderSettings reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Quantas horas antes'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.screenGutter,
            0,
            Dimens.screenGutter,
            Dimens.gapMedium,
          ),
          child: Text(
            'Cedo demais o cliente esquece de novo; tarde demais não sobra '
            'tempo de preencher o horário que ele desmarcar.',
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
              for (final hours in ReminderSettings.hourChoices)
                ChoiceChip(
                  label: Text('${hours}h'),
                  selected: hours == reminder.hoursBefore,
                  onSelected: (_) => _save(
                    context,
                    ref,
                    ReminderSettings(isOn: reminder.isOn, hoursBefore: hours),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Quanto isso custaria numa semana como a que vem.
class _Cost extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final count = ref.watch(remindersNextWeekProvider).value ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Quanto custa'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
          child: AppCard(
            child: count == 0
                ? Text(
                    'Nenhum horário marcado nos próximos sete dias — nada '
                    'sairia, e nada seria cobrado.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatMoney(count * reminderCostCents),
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'na semana que vem: $count '
                        '${count == 1 ? 'horário marcado' : 'horários marcados'} '
                        'com cliente cadastrado.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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

/// Grava e **mostra** quando não consegue: um ajuste que não muda de estado
/// em silêncio faz o Marcos tocar no mesmo botão sem entender.
Future<void> _save(
  BuildContext context,
  WidgetRef ref,
  ReminderSettings reminder,
) async {
  try {
    await ref.read(shopSettingsRepositoryProvider).saveReminder(reminder);
  } on Object {
    if (!context.mounted) return;
    showSnack(context, 'Não consegui salvar o lembrete.');
  }
}
