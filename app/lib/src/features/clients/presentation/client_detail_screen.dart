import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/core/theme/status_colors.dart';
import 'package:mispar/src/features/agenda/data/shop_settings_repository.dart';
import 'package:mispar/src/features/agenda/domain/appointment_status.dart';
import 'package:mispar/src/features/clients/data/client_repository.dart';
import 'package:mispar/src/features/clients/domain/client.dart';
import 'package:mispar/src/features/clients/domain/client_summary.dart';
import 'package:mispar/src/features/clients/presentation/clients_view_model.dart';
import 'package:mispar/src/features/clients/presentation/widgets/note_editor.dart';
import 'package:mispar/src/features/settings/domain/drifted_rule.dart';
import 'package:mispar/src/shared/formatters/day_time.dart';
import 'package:mispar/src/shared/formatters/money.dart';
import 'package:mispar/src/shared/formatters/phone.dart';
import 'package:mispar/src/shared/whatsapp.dart';
import 'package:mispar/src/shared/widgets/app_card.dart';
import 'package:mispar/src/shared/widgets/app_snack.dart';
import 'package:mispar/src/shared/widgets/async_view.dart';
import 'package:mispar/src/shared/widgets/confirm.dart';
import 'package:mispar/src/shared/widgets/page_bar.dart';
import 'package:mispar/src/shared/widgets/screen_title.dart';

class ClientDetailScreen extends ConsumerWidget {
  const new({required this.clientId, super.key});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: AsyncView(
        value: ref.watch(clientSummaryProvider(clientId)),
        onRetry: () => ref.invalidate(clientSummaryProvider(clientId)),
        builder: (summary) {
          if (summary == null) {
            return const Center(child: Text('Cliente não encontrado.'));
          }
          return _Body(summary: summary);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const new({required this.summary});

  final ClientSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = summary.client;

    return CustomScrollView(
      slivers: [
        PageBar(title: client.name),
        SliverToBoxAdapter(child: PageSubtitle(formatPhone(client.phone))),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: Dimens.gapLarge * 2),
          sliver: SliverList.list(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimens.screenGutter,
                ),
                child: _Numbers(summary: summary),
              ),
              const SizedBox(height: Dimens.gapMedium),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimens.screenGutter,
                ),
                child: _WhatsAppButton(phone: client.phone),
              ),
              const SectionLabel('Do jeito que ele gosta'),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimens.screenGutter,
                ),
                child: NoteEditor(
                  note: client.note,
                  onSave: (value) => ref
                      .read(clientRepositoryProvider)
                      .saveNote(client.id, value),
                ),
              ),
              const SectionLabel('Histórico'),
              _History(clientId: client.id),
              _DangerZone(client: client),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tirar da lista, ou apagar de vez.
///
/// A conta de quantos atendimentos ele teve sai do **mesmo fluxo que o
/// historico logo acima ja escuta** — o Riverpod entrega a mesma assinatura,
/// entao nao ha consulta nem soma a mais por causa deste bloco.
class _DangerZone extends ConsumerWidget {
  const new({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visits = ref.watch(clientVisitsProvider(client.id)).value;
    if (visits == null) return const SizedBox.shrink();

    // Nunca sentou na cadeira: e cadastro repetido ou nome digitado errado.
    // Apagar nao perde nada.
    if (visits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          Dimens.screenGutter,
          Dimens.gapLarge,
          Dimens.screenGutter,
          0,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _confirmDelete(context, ref),
            style: TextButton.styleFrom(foregroundColor: theme.status.alert),
            child: const Text('Apagar cliente'),
          ),
        ),
      );
    }

    return SwitchListTile(
      contentPadding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        Dimens.gapLarge,
        Dimens.screenGutter,
        0,
      ),
      value: client.isActive,
      onChanged: (value) => ref
          .read(clientRepositoryProvider)
          .setActive(client.id, isActive: value)
          .ignore(),
      title: const Text('Na lista'),
      subtitle: Text(
        // "horario" cobre o que ja passou e o que ainda vai acontecer.
        visits.length == 1
            ? 'Desligado, some da busca ao marcar — mas o horário dele '
                  'continua na agenda e no histórico.'
            : 'Desligado, some da busca ao marcar — mas os ${visits.length} '
                  'horários dele continuam na agenda e no histórico.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await askToConfirm(
      context,
      title: 'Apagar cliente?',
      message:
          '${client.name} some de vez. Como nunca teve atendimento, nada do '
          'histórico se perde.',
      confirmLabel: 'Apagar',
    );

    if (!confirmed) return;
    await ref.read(clientRepositoryProvider).delete(client.id);

    if (!context.mounted) return;
    Navigator.of(context).pop();
    showSnack(context, '${client.name} apagado.');
  }
}

/// Os tres numeros que o Marcos usa para decidir: quanto rende, com que
/// frequencia volta, e quando foi a ultima vez.
class _Numbers extends ConsumerWidget {
  const new({required this.summary});

  final ClientSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastVisit = summary.lastVisit;
    final rule =
        ref.watch(driftedRuleProvider).value ?? const DriftedRule.unknown();

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: _Number(
              value: formatMoney(summary.spentCents),
              label: 'já gastou',
            ),
          ),
          Expanded(
            child: _Number(
              value: '${summary.visitCount}',
              label: summary.visitCount == 1 ? 'visita' : 'visitas',
            ),
          ),
          Expanded(
            child: _Number(
              value: lastVisit == null ? '—' : formatTimeAgo(lastVisit),
              label: 'última vez',
              isAlert: rule.isOn && summary.hasDriftedAfter(rule.days),
            ),
          ),
        ],
      ),
    );
  }
}

class _Number extends StatelessWidget {
  const new({required this.value, required this.label, this.isAlert = false});

  final String value;
  final String label;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: isAlert ? theme.status.alert : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _WhatsAppButton extends StatelessWidget {
  const new({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _open(context),
      icon: const Icon(Symbols.chat_rounded, weight: 500, size: 20),
      label: const Text('Falar no WhatsApp'),
    );
  }

  Future<void> _open(BuildContext context) async {
    final opened = await openWhatsApp(phone);

    if (opened || !context.mounted) return;
    showSnack(context, 'Não consegui abrir o WhatsApp.');
  }
}

class _History extends ConsumerWidget {
  const new({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return AsyncView(
      value: ref.watch(clientVisitsProvider(clientId)),
      onRetry: () => ref.invalidate(clientVisitsProvider(clientId)),
      builder: (visits) {
        if (visits.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
            ),
            child: Text(
              'Nenhum atendimento registrado ainda.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
          child: AppCard(
            child: Column(
              children: [
                for (final visit in visits) ...[
                  if (visit != visits.first)
                    const Divider(height: Dimens.gapMedium),
                  _VisitRow(visit: visit),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VisitRow extends StatelessWidget {
  const new({required this.visit});

  final ClientVisit visit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final missed = visit.status == AppointmentStatus.noShow;

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            formatShortDate(visit.startsAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Expanded(
          child: Text(
            missed ? '${visit.serviceName} · faltou' : visit.serviceName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: missed ? theme.status.alert : colors.onSurface,
            ),
          ),
        ),
        Text(
          formatMoney(visit.priceCents),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: missed ? colors.onSurfaceVariant : colors.onSurface,
            decoration: missed ? TextDecoration.lineThrough : null,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
