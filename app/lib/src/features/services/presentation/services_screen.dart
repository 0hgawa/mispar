import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/services/data/service_repository.dart';
import 'package:marcos_barber/src/features/services/domain/service.dart';
import 'package:marcos_barber/src/features/services/presentation/service_form.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:marcos_barber/src/shared/widgets/empty_state.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:material_symbols_icons/symbols.dart';

final _catalogueProvider = StreamProvider<List<Service>>(
  (ref) => ref.watch(serviceRepositoryProvider).watchAll(includeRetired: true),
);

/// O catalogo da barbearia: o que ela faz e quanto custa.
///
/// E o mesmo dado que o robo oferece na conversa — mudou aqui, muda la.
class ServicesScreen extends ConsumerWidget {
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => ServiceForm.show(context),
        tooltip: 'Novo serviço',
        child: const Icon(Symbols.add_rounded, weight: 600, size: 28),
      ),
      body: AsyncView(
        value: ref.watch(_catalogueProvider),
        onRetry: () => ref.invalidate(_catalogueProvider),
        builder: (services) {
          final live = services.where((s) => s.isActive).toList();
          final retired = services.where((s) => !s.isActive).toList();

          if (services.isEmpty) {
            return const EmptyState(
              icon: Symbols.content_cut_rounded,
              title: 'Nenhum serviço',
              message: 'Cadastre o que a barbearia faz e por quanto.',
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 92),
            children: [
              const ScreenTitle(
                title: 'Serviços',
                subtitle: 'o que o cliente pode escolher',
              ),
              for (final service in live) _ServiceRow(service: service),
              if (retired.isNotEmpty) ...[
                const SectionLabel('Fora do cardápio'),
                for (final service in retired) _ServiceRow(service: service),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const new({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        const Divider(
          height: 1,
          indent: Dimens.screenGutter,
          endIndent: Dimens.screenGutter,
        ),
        Opacity(
          opacity: service.isActive ? 1 : 0.45,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Dimens.screenGutter,
              vertical: 8,
            ),
            onTap: () => ServiceForm.show(context, service: service),
            title: Text(
              service.name,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              service.requiresDeposit
                  ? '${formatDuration(service.duration)} · pede sinal'
                  : formatDuration(service.duration),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            trailing: Text(
              formatMoney(service.priceCents),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
