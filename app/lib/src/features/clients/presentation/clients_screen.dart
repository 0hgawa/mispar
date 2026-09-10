import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marcos_barber/src/core/router/app_router.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/clients/presentation/clients_view_model.dart';
import 'package:marcos_barber/src/features/clients/presentation/widgets/client_card.dart';

import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:marcos_barber/src/shared/widgets/empty_state.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:material_symbols_icons/symbols.dart';

class ClientsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Routes.newClient),
        tooltip: 'Cadastrar cliente',
        child: const Icon(Symbols.person_add_rounded, weight: 600, size: 26),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            const _SearchField(),
            Expanded(
              child: AsyncView(
                value: ref.watch(clientListProvider),
                onRetry: () => ref.invalidate(clientListProvider),
                builder: (clients) {
                  if (clients.isEmpty) {
                    return _EmptyResult(
                      isSearching: ref.watch(clientSearchProvider).isNotEmpty,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      Dimens.screenGutter,
                      0,
                      Dimens.screenGutter,
                      // Espaco para o botao redondo nao tapar o ultimo card.
                      88,
                    ),
                    itemCount: clients.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Dimens.cardGap),
                    itemBuilder: (context, index) {
                      final summary = clients[index];
                      return ClientCard(
                        summary: summary,
                        onTap: () => context.push(
                          Routes.clientDetail(summary.client.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Consumer proprio: digitar na busca nao reconstroi a lista de fora.
class _Header extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(clientListProvider)
        .maybeWhen(data: (list) => list.length, orElse: () => 0);

    return ScreenTitle(
      title: 'Clientes',
      subtitle: count == 1 ? '1 pessoa' : '$count pessoas',
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasText = _controller.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        0,
        Dimens.screenGutter,
        Dimens.gapMedium,
      ),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          ref.read(clientSearchProvider.notifier).update(value);
          setState(() {});
        },
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Buscar por nome ou telefone',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Symbols.search_rounded,
            weight: 500,
            color: colors.onSurfaceVariant,
          ),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(Symbols.close_rounded, weight: 500),
                  color: colors.onSurfaceVariant,
                  tooltip: 'Limpar busca',
                  onPressed: () {
                    _controller.clear();
                    ref.read(clientSearchProvider.notifier).update('');
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: colors.secondaryContainer,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Dimens.pillRadius),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const new({required this.isSearching});

  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return const EmptyState(
        icon: Symbols.search_off_rounded,
        title: 'Ninguém com esse nome',
        message: 'Confira a escrita ou tente pelo telefone.',
      );
    }

    return const EmptyState(
      icon: Symbols.group_rounded,
      title: 'Nenhum cliente ainda',
      message:
          'Quem marcar pelo WhatsApp entra aqui sozinho. Para cadastrar na '
          'mão, use o botão de baixo.',
    );
  }
}
