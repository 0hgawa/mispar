import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marcos_barber/src/core/router/app_router.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/data/shop_settings_repository.dart';
import 'package:marcos_barber/src/features/clients/domain/client_summary.dart';
import 'package:marcos_barber/src/features/clients/domain/win_back.dart';
import 'package:marcos_barber/src/features/clients/presentation/clients_view_model.dart';
import 'package:marcos_barber/src/features/clients/presentation/widgets/client_row.dart';
import 'package:marcos_barber/src/features/settings/domain/drifted_rule.dart';
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
/// Clientes — a mesma regra que acende a faixa no topo daquela aba; aqui ela
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
          final rule =
              ref.watch(driftedRuleProvider).value ??
              const DriftedRule.unknown();
          final drifted = winBackList(all, rule);

          return CustomScrollView(
            slivers: [
              const PageBar(title: 'Sumiram'),
              SliverToBoxAdapter(
                child: PageSubtitle(switch (drifted.length) {
                  0 => 'quem não aparece há mais de ${rule.days} dias',
                  // Verbo antes do dinheiro: "R$ 120 já gastou aqui" deixava
                  // a frase sem sujeito, e o valor virava o dono da ação.
                  1 =>
                    'já gastou ${formatMoney(winBackValueCents(drifted))} aqui',
                  _ =>
                    'já gastaram ${formatMoney(winBackValueCents(drifted))} '
                        'aqui',
                }),
              ),
              if (drifted.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NobodyLeft(days: rule.days),
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
      // Quanto tempo sumiu e quanto ele deixa por visita: é com esses dois
      // que se decide quem chamar primeiro, e é o segundo que manda na ordem
      // da lista. A regra do sumiço só vale para quem já veio alguma vez,
      // então aqui a última visita nunca é nula.
      //
      // "por visita", e não o total de sempre: número solto ao lado de um
      // nome, numa barbearia onde existe fiado, se lê como dívida.
      detail:
          '${formatTimeAgo(summary.lastVisit!)} · '
          '${formatMoney(summary.averageTicketCents)} por visita',
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
  const new({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Symbols.sentiment_satisfied_rounded,
      title: 'Ninguém sumiu',
      message:
          'Todo mundo da lista apareceu nos últimos $days dias. Quando alguém '
          'passar desse tempo, ele aparece aqui para ser chamado.',
    );
  }
}
