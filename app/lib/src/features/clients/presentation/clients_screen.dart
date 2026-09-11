import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marcos_barber/src/core/router/app_router.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/clients/domain/client_summary.dart';
import 'package:marcos_barber/src/features/clients/presentation/clients_view_model.dart';
import 'package:marcos_barber/src/features/clients/presentation/import_contacts_screen.dart';
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
        child: AsyncView(
          value: ref.watch(allClientsProvider),
          onRetry: () => ref.invalidate(allClientsProvider),
          builder: (clients) => Column(
            children: [
              _Header(count: clients.length),
              // A barra fica parada no topo, e o toque abre a busca por cima
              // da lista. Rolar junto era pior dos dois lados: comia o
              // cabeçalho enquanto ninguém buscava, e sumia justo na hora em
              // que alguém precisava dela.
              _SearchBar(all: clients),
              Expanded(
                child: clients.isEmpty
                    ? const _NoClients()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          Dimens.screenGutter,
                          0,
                          Dimens.screenGutter,
                          // Espaco para o botao redondo nao tapar o ultimo.
                          88,
                        ),
                        itemCount: clients.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Dimens.cardGap),
                        itemBuilder: (context, index) => ClientCard(
                          summary: clients[index],
                          onTap: () => context.push(
                            Routes.clientDetail(clients[index].client.id),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const new({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ScreenTitle(
            title: 'Clientes',
            subtitle: count == 1 ? '1 pessoa' : '$count pessoas',
          ),
        ),
        // Com a lista cheia o estado vazio some, e com ele o caminho para a
        // agenda do celular. Ele continua aqui: contato novo no telefone é
        // cliente que ainda não entrou.
        Padding(
          padding: const EdgeInsets.only(right: Dimens.gapSmall),
          child: IconButton(
            icon: const Icon(Symbols.download_rounded, weight: 500),
            tooltip: 'Trazer da agenda do celular',
            onPressed: () => ImportContactsScreen.show(context),
          ),
        ),
      ],
    );
  }
}

/// A barra parada, e a busca que ela abre.
///
/// `SearchAnchor` é o componente do Material para isto: a barra é só a porta,
/// e o toque leva a uma tela de busca inteira — campo no topo, voltar ao lado,
/// resultados ocupando o corpo. É o que o telefone, o WhatsApp e o Gmail
/// fazem, e o motivo é o mesmo: enquanto se busca, a lista de trás não tem
/// nada a dizer.
class _SearchBar extends StatelessWidget {
  const new({required this.all});

  final List<ClientSummary> all;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        0,
        Dimens.screenGutter,
        Dimens.gapMedium,
      ),
      child: SearchAnchor(
        isFullScreen: true,
        viewHintText: 'Buscar por nome ou telefone',
        viewBackgroundColor: colors.surface,
        // A porta continua sendo a pílula do app, e não a barra do Material:
        // por fora nada muda; o que muda é o que acontece ao tocar.
        builder: (context, controller) => _Pill(onTap: controller.openView),
        suggestionsBuilder: (context, controller) {
          final found = matchingClients(all, controller.text);

          if (found.isEmpty) {
            return const [
              Padding(
                padding: EdgeInsets.only(top: Dimens.gapLarge * 2),
                child: EmptyState(
                  icon: Symbols.search_off_rounded,
                  title: 'Ninguém com esse nome',
                  message: 'Confira a escrita ou tente pelo telefone.',
                ),
              ),
            ];
          }

          return [
            for (final summary in found)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Dimens.screenGutter,
                  0,
                  Dimens.screenGutter,
                  Dimens.cardGap,
                ),
                child: ClientCard(
                  summary: summary,
                  onTap: () {
                    controller.closeView(null);
                    unawaited(
                      context.push(Routes.clientDetail(summary.client.id)),
                    );
                  },
                ),
              ),
          ];
        },
      ),
    );
  }
}

/// A porta da busca: parece campo, mas não recebe texto — quem digita é a tela
/// que ela abre.
class _Pill extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.secondaryContainer,
      borderRadius: BorderRadius.circular(Dimens.pillRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(
                Symbols.search_rounded,
                weight: 500,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                'Buscar por nome ou telefone',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoClients extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Symbols.group_rounded,
      title: 'Nenhum cliente ainda',
      message:
          'Traga quem já está na agenda do celular. Digitar um por um não '
          'acontece — e o robô do WhatsApp precisa do telefone de cada um.',
      action: FilledButton.icon(
        onPressed: () => ImportContactsScreen.show(context),
        icon: const Icon(Symbols.download_rounded, size: 20, weight: 600),
        label: const Text('Trazer da agenda'),
      ),
    );
  }
}
