import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/data/shop_settings_repository.dart';
import 'package:marcos_barber/src/features/settings/domain/drifted_rule.dart';
import 'package:marcos_barber/src/shared/widgets/app_snack.dart';
import 'package:marcos_barber/src/shared/widgets/page_bar.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';

/// Quando o app avisa que um cliente parou de vir.
///
/// Dois controles: ligar, e de quantos dias. O prazo tinha que sair do código
/// porque ele não é o mesmo em toda barbearia — e o interruptor existe porque
/// aviso que não serve vira mancha vermelha que ninguém olha mais.
class DriftedSettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rule =
        ref.watch(driftedRuleProvider).value ?? const DriftedRule.unknown();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const PageBar(title: 'Sumiram'),
          const SliverToBoxAdapter(
            child: PageSubtitle('quando um cliente conta como sumido'),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
            sliver: SliverList.list(
              children: [
                const _HowItWorks(),
                _Switch(rule),
                if (rule.isOn) _Days(rule),
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
        'Quem passa do prazo sem aparecer entra numa lista à parte, com o '
        'botão do WhatsApp, e um aviso aparece no topo da lista de '
        'clientes. A mensagem sai do seu telefone e não custa nada.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Switch extends ConsumerWidget {
  const new(this.rule);

  final DriftedRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Dimens.screenGutter,
        vertical: 4,
      ),
      value: rule.isOn,
      onChanged: (isOn) =>
          _save(context, ref, DriftedRule(isOn: isOn, days: rule.days)),
      title: Text(
        'Avisar quem sumiu',
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Desligado, a lista de clientes para de marcar quem some',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// De quantos dias sem aparecer.
class _Days extends ConsumerWidget {
  const new(this.rule);

  final DriftedRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Depois de quantos dias'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.screenGutter,
            0,
            Dimens.screenGutter,
            Dimens.gapMedium,
          ),
          child: Text(
            'Depende do ritmo da sua barbearia: quem corta a cada quinze dias '
            'sumiu muito antes de quem corta a cada dois meses.',
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
              for (final days in DriftedRule.dayChoices)
                ChoiceChip(
                  label: Text('$days dias'),
                  selected: days == rule.days,
                  onSelected: (_) => _save(
                    context,
                    ref,
                    DriftedRule(isOn: rule.isOn, days: days),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Grava e **mostra** quando não consegue: ajuste que não muda de estado em
/// silêncio faz o Marcos tocar no mesmo botão sem entender.
Future<void> _save(
  BuildContext context,
  WidgetRef ref,
  DriftedRule rule,
) async {
  try {
    await ref.read(shopSettingsRepositoryProvider).saveDrifted(rule);
  } on Object {
    if (!context.mounted) return;
    showSnack(context, 'Não consegui salvar o aviso.');
  }
}
