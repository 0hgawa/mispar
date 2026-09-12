import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/features/services/data/service_repository.dart';
import 'package:mispar/src/features/services/domain/service.dart';
import 'package:mispar/src/features/services/presentation/service_form.dart';
import 'package:mispar/src/shared/formatters/day_time.dart';
import 'package:mispar/src/shared/formatters/money.dart';
import 'package:mispar/src/shared/widgets/async_view.dart';
import 'package:mispar/src/shared/widgets/empty_state.dart';
import 'package:mispar/src/shared/widgets/page_bar.dart';
import 'package:mispar/src/shared/widgets/screen_title.dart';

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
      floatingActionButton: FloatingActionButton(
        onPressed: () => ServiceForm.show(context),
        tooltip: 'Cadastrar',
        child: const Icon(Symbols.add_rounded, weight: 600, size: 28),
      ),
      body: AsyncView(
        value: ref.watch(_catalogueProvider),
        onRetry: () => ref.invalidate(_catalogueProvider),
        builder: (catalogue) {
          final live = catalogue.where((s) => s.isActive);
          final services = live.where((s) => !s.isProduct).toList();
          final products = live.where((s) => s.isProduct).toList();
          final retired = catalogue.where((s) => !s.isActive).toList();

          if (catalogue.isEmpty) {
            return const EmptyState(
              icon: Symbols.content_cut_rounded,
              title: 'Nada no catálogo',
              message: 'Cadastre o que a barbearia faz e o que ela vende.',
            );
          }

          return CustomScrollView(
            slivers: [
              const PageBar(title: 'Catálogo'),
              const SliverToBoxAdapter(
                child: PageSubtitle('o que a barbearia faz e vende'),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 92),
                sliver: SliverList.list(
                  children: [
                    // Duas listas porque sao duas coisas: uma ocupa a cadeira e a
                    // outra sai da prateleira. So aparece o titulo quando ha as
                    // duas — com uma so, o titulo separaria dela mesma.
                    if (services.isNotEmpty) ...[
                      if (products.isNotEmpty) const SectionLabel('Serviços'),
                      for (final service in services)
                        _ServiceRow(service: service),
                    ],
                    if (products.isNotEmpty) ...[
                      const SectionLabel('Produtos'),
                      for (final product in products)
                        _ServiceRow(service: product),
                    ],
                    if (retired.isNotEmpty) ...[
                      const SectionLabel('Fora do catálogo'),
                      for (final service in retired)
                        _ServiceRow(service: service),
                    ],
                  ],
                ),
              ),
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
            subtitle: service.isProduct
                ? null
                : Text(
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
