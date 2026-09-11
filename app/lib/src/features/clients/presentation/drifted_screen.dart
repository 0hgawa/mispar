import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marcos_barber/src/core/router/app_router.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/clients/domain/client_summary.dart';
import 'package:marcos_barber/src/features/clients/domain/win_back.dart';
import 'package:marcos_barber/src/features/clients/presentation/clients_view_model.dart';
import 'package:marcos_barber/src/features/clients/presentation/widgets/client_row.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/whatsapp.dart';
import 'package:marcos_barber/src/shared/widgets/app_snack.dart';
import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:marcos_barber/src/shared/widgets/empty_state.dart';
import 'package:marcos_barber/src/shared/widgets/page_bar.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Quem parou de vir, e o botão para chamar de volta.
///
/// Cliente antigo é o mais barato que existe: ele já conhece a barbearia, já
/// sabe o preço e já gostou do corte. A lista sai da mesma consulta da aba de
/// Clientes — a regra dos 45 dias já estava lá, pintando um selo; aqui ela
/// vira um lugar onde dá para agir.
class DriftedScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: AsyncView(
        value: ref.watch(allClientsProvider),
        onRetry: () => ref.invalidate(allClientsProvider),
        builder: (all) {
          final drifted = winBackList(all);

          return CustomScrollView(
            slivers: [
              const PageBar(title: 'Sumiram'),
              SliverToBoxAdapter(
                child: PageSubtitle(switch (drifted.length) {
                  0 => 'quem não aparece há mais de 45 dias',
                  1 =>
                    '${formatMoney(winBackValueCents(drifted))} já gastou '
                        'aqui',
                  _ =>
                    '${formatMoney(winBackValueCents(drifted))} já gastaram '
                        'aqui',
                }),
              ),
              if (drifted.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NobodyLeft(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Dimens.screenGutter,
                    0,
                    Dimens.screenGutter,
                    Dimens.gapLarge,
                  ),
                  sliver: SliverList.separated(
                    itemCount: drifted.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: Dimens.cardGap),
                    itemBuilder: (context, index) =>
                        _DriftedRow(drifted[index]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DriftedRow extends StatelessWidget {
  const new(this.summary);

  final ClientSummary summary;

  @override
  Widget build(BuildContext context) {
    final client = summary.client;

    return ClientRow(
      name: client.name,
      // Quanto tempo sumiu e quanto já deixou aqui: é com esses dois que se
      // decide quem chamar primeiro. `hasDrifted` só é verdade para quem já
      // veio alguma vez, então aqui a última visita nunca é nula.
      detail:
          '${formatTimeAgo(summary.lastVisit!)} · '
          '${formatMoney(summary.spentCents)}',
      detailLines: 1,
      trailing: IconButton.filledTonal(
        icon: const Icon(Symbols.chat_rounded, weight: 500, size: 22),
        tooltip: 'Chamar no WhatsApp',
        onPressed: () => unawaited(_call(context, summary)),
      ),
      onTap: () => context.push(Routes.clientDetail(client.id)),
    );
  }

  /// Abre a conversa com a mensagem digitada. Enviar é dele.
  Future<void> _call(BuildContext context, ClientSummary summary) async {
    final opened = await openWhatsApp(
      summary.client.phone,
      message: winBackMessage(
        name: summary.client.name,
        usualService: summary.usualService,
      ),
    );

    if (opened || !context.mounted) return;
    showSnack(context, 'Não consegui abrir o WhatsApp.');
  }
}

class _NobodyLeft extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Symbols.sentiment_satisfied_rounded,
      title: 'Ninguém sumiu',
      message:
          'Todo mundo da lista apareceu nos últimos 45 dias. Quando alguém '
          'passar desse tempo, ele aparece aqui para ser chamado.',
    );
  }
}
