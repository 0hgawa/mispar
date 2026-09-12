import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mispar/src/core/router/app_router.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/core/theme/status_colors.dart';
import 'package:mispar/src/features/reports/domain/cash_csv.dart';
import 'package:mispar/src/features/reports/presentation/cash_view_model.dart';
import 'package:mispar/src/features/reports/presentation/expense_form.dart';
import 'package:mispar/src/features/reports/presentation/income_form.dart';
import 'package:mispar/src/features/reports/presentation/widgets/cash_period_picker.dart';
import 'package:mispar/src/features/reports/presentation/widgets/profit_chart.dart';
import 'package:mispar/src/shared/formatters/money.dart';
import 'package:mispar/src/shared/widgets/app_card.dart';
import 'package:mispar/src/shared/widgets/app_snack.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// O painel do dinheiro: só número e porta.
///
/// A pergunta que o Marcos faz não é "quanto faturei", é **"quanto sobrou"** —
/// por isso ela é o número grande, e não mais uma linha no meio da tela.
///
/// Extrato não mora aqui. Entrou e Saiu são cartões que **abrem** a tela
/// daquele lado, onde ficam o detalhamento e a lista. Painel e extrato na
/// mesma tela era o que fazia a aba parecer relatório.
class CashScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: const _RecordButton(),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(
            // Espaco para o botao redondo nao tapar o fim do grafico.
            bottom: 88,
          ),
          children: const [
            _Header(),
            SizedBox(height: Dimens.gapLarge),
            _Left(),
            SizedBox(height: Dimens.gapLarge),
            _Doors(),
            ProfitChart(),
          ],
        ),
      ),
    );
  }
}

/// Titulo e a saida para o contador.
class _Header extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        12,
        Dimens.gapSmall,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Caixa', style: theme.textTheme.headlineMedium),
              ),
              IconButton(
                icon: const Icon(Symbols.ios_share_rounded, weight: 500),
                tooltip: 'Exportar o período',
                onPressed: () => _export(context, ref),
              ),
            ],
          ),
          const CashPeriodPicker(),
        ],
      ),
    );
  }

  /// Uma planilha do periodo, entradas e saidas na mesma tabela.
  ///
  /// E o que o contador pede, e o que evita o Marcos ter que copiar numero a
  /// numero no fim do ano.
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final report = ref.read(cashReportProvider).value;
    final spent = ref.read(spentReportProvider).value;

    if (report == null || spent == null) return;
    if (report.entries.isEmpty && spent.expenses.isEmpty) {
      showSnack(context, 'Nada para exportar neste período.');
      return;
    }

    final window = ref.read(cashFilterChoiceProvider).resolve();
    final name =
        'caixa-${window.from.year}-'
        '${window.from.month.toString().padLeft(2, '0')}-'
        '${window.from.day.toString().padLeft(2, '0')}.csv';

    try {
      final folder = await getTemporaryDirectory();
      final file = File('${folder.path}/$name');
      await file.writeAsString(
        cashCsv(earned: report.entries, spent: spent.expenses),
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Caixa da barbearia',
        ),
      );
    } on Object {
      // Depois do await a tela pode ter saido: sem a guarda, o aviso
      // procuraria um Scaffold que nao existe mais.
      if (!context.mounted) return;
      showSnack(context, 'Não consegui gerar a planilha.');
    }
  }
}

/// O numero que resume o periodo, sozinho e grande.
///
/// Sem cartao em volta de proposito: o que se le fica no fundo, o que se toca
/// fica em cartao. E a diferenca que diz qual dos dois e qual.
class _Left extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final earned = ref.watch(cashReportProvider).value?.earnedCents ?? 0;
    final spent = ref.watch(spentReportProvider).value?.totalCents ?? 0;
    final left = earned - spent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // Negativo nao e "sobrou": o periodo fechou no vermelho.
            left >= 0 ? 'Sobrou' : 'Faltou',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            formatMoney(left.abs()),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.displayLarge?.copyWith(
              color: left >= 0
                  ? theme.colorScheme.onSurface
                  : theme.status.alert,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const _AgainstLastPeriod(),
        ],
      ),
    );
  }
}

/// Como este periodo esta contra o de tras.
///
/// Um numero sozinho nao diz se o mes esta bom: R$ 4.000 e otimo depois de
/// R$ 3.000 e ruim depois de R$ 6.000. A janela de tras vem recortada no mesmo
/// ponto — dez dias de setembro contra dez dias de agosto, nunca contra o mes
/// inteiro.
class _AgainstLastPeriod extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final label = ref.watch(cashFilterChoiceProvider).previousLabel;
    if (label == null) return const SizedBox.shrink();

    final before = ref.watch(previousPeriodProvider).value;
    if (before == null) return const SizedBox.shrink();

    final earned = ref.watch(cashReportProvider).value?.earnedCents ?? 0;
    final spent = ref.watch(spentReportProvider).value?.totalCents ?? 0;

    final change = percentChange(
      before: before.earnedCents - before.spentCents,
      now: earned - spent,
    );
    if (change == null || change == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            change > 0
                ? Symbols.trending_up_rounded
                : Symbols.trending_down_rounded,
            size: 18,
            weight: 600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${change.abs()}% ${change > 0 ? 'a mais' : 'a menos'} $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lançar dinheiro sem precisar entrar na porta antes.
///
/// O botão redondo é o mesmo de todas as abas, no mesmo canto. Nesta ele tem
/// duas saídas, porque o Caixa tem dois lados — e as duas abrem **em cima
/// dele**, que é onde o dedo já está. Folha de baixo aqui seria modal: cobre a
/// tela inteira para oferecer duas linhas.
///
/// Antes, lançar exigia entrar em Entrou ou em Saiu primeiro, e do painel não
/// dava para saber que aquele era o caminho.
class _RecordButton extends StatefulWidget {
  const new();

  /// Largura da faixa onde as pílulas se alinham, dita e não deduzida.
  ///
  /// É ela que encosta a borda direita das pílulas na borda direita do botão:
  /// o recuo do menu é `largura do botão − esta`. Sem um número aqui, o
  /// Material mede o item mais largo e empurra tudo até a borda da tela.
  static const _menuWidth = 220.0;

  /// O tamanho do botão redondo padrão do Material.
  static const _buttonWidth = 56.0;

  @override
  State<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<_RecordButton> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menu,
      // Sem recorte. O painel do Material corta no próprio retângulo, e como
      // as pílulas ocupam ele inteiro, o que sobrava para fora — a sombra e o
      // arredondado de baixo — saía chanfrado, como se a pílula estivesse
      // cortada.
      clipBehavior: Clip.none,
      // As opções saem **do** botão: mesma borda direita, empilhadas por cima
      // dele. Encostado na barra de baixo o menu não cabe abaixo do botão, e o
      // Material o vira para cima sozinho.
      alignmentOffset: const Offset(
        _RecordButton._buttonWidth - _RecordButton._menuWidth,
        Dimens.gapSmall,
      ),
      // Sem folha em volta: no FAB Menu do M3 cada opção é uma pílula solta, e
      // não linha de um cartão. O painel do Material continua fazendo o que
      // interessa — abrir, posicionar e fechar ao tocar fora —, só que
      // invisível.
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        _RecordPill(
          icon: Symbols.add_rounded,
          label: 'Entrou dinheiro',
          onTap: () => _open(IncomeForm.show),
        ),
        const SizedBox(height: Dimens.gapSmall),
        _RecordPill(
          icon: Symbols.remove_rounded,
          label: 'Saiu dinheiro',
          onTap: () => _open(ExpenseForm.show),
        ),
      ],
      builder: (context, controller, child) => FloatingActionButton(
        onPressed: controller.isOpen ? controller.close : controller.open,
        tooltip: 'Lançar dinheiro',
        child: AnimatedRotation(
          // O mesmo `+` virando `×`: é o botão que abriu, e é ele que fecha.
          turns: controller.isOpen ? 0.125 : 0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: const Icon(Symbols.add_rounded, weight: 600, size: 28),
        ),
      ),
    );
  }

  /// Fecha o menu antes de abrir o formulário: pílula não é item de menu, e
  /// ninguém fecha por ela.
  void _open(Future<void> Function(BuildContext context) form) {
    _menu.close();
    unawaited(form(context));
  }
}

/// Uma opção do botão redondo, do tamanho do que ela diz.
class _RecordPill extends StatelessWidget {
  const new({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: _RecordButton._menuWidth,
      // Cada pílula tem a largura do próprio texto, e as duas encostam a
      // borda direita na do botão. É assim no FAB Menu do M3: pílula é do
      // tamanho do que ela diz, e não de uma faixa.
      //
      // A faixa de 220 continua existindo por baixo, invisível, só para
      // alinhar as bordas — é a caixa do menu, e tocar na caixa de um menu
      // sem acertar um item não faz nada mesmo.
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: theme.colorScheme.surfaceContainer,
          shape: const StadiumBorder(),
          // A mesma altura do botão que as abriu, e nem um grau a mais: a
          // pílula sai dele, não flutua acima dele. Em 3 a sombra ficava maior
          // que a do próprio botão, num app onde cartão nenhum tem sombra.
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, weight: 600, size: 22),
                  const SizedBox(width: 10),
                  Text(label, style: theme.textTheme.labelLarge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Os dois lados da conta, cada um a uma porta de distancia.
class _Doors extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(cashReportProvider).value;
    final spent = ref.watch(spentReportProvider).value;

    final served = report?.servedCount ?? 0;
    final expected = report?.expectedCents ?? 0;
    final lanced = spent?.expenses.length ?? 0;
    final fixed = spent?.fixedCents ?? 0;
    final owed = report?.owedCents ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Door(
                    label: 'Entrou',
                    cents: report?.earnedCents ?? 0,
                    // O que esta marcado e a noticia mais util deste lado: e o que
                    // ainda pode entrar antes do periodo fechar.
                    //
                    // Uma linha so, e so dinheiro: com "em 14 horarios" junto, a
                    // nota quebrava em duas e o par de cartoes ficava torto — um
                    // alto, outro baixo. A contagem esta a um toque, dentro.
                    // Fiado antes de "a receber": o corte ja foi feito e o
                    // dinheiro esta na mao do cliente, o que e mais urgente que um
                    // horario que ainda nem aconteceu.
                    note: owed > 0
                        ? '${formatMoney(owed)} fiado'
                        : expected > 0
                        ? '+ ${formatMoney(expected)} a receber'
                        : served == 1
                        ? '1 atendimento'
                        : '$served atendimentos',
                    onTap: () => context.push(Routes.earned),
                  ),
                ),
                const SizedBox(width: Dimens.cardGap),
                Expanded(
                  child: _Door(
                    label: 'Saiu',
                    cents: spent?.totalCents ?? 0,
                    // Quanto disto volta no mês que vem é a notícia deste lado —
                    // o espelho do "a receber" do outro. A contagem de
                    // lançamentos só aparece quando não há nada fixo: ela não diz
                    // nada que abrir a tela não diga melhor.
                    note: fixed > 0
                        ? '${formatMoney(fixed)} todo mês'
                        : lanced == 1
                        ? '1 lançamento'
                        : '$lanced lançamentos',
                    onTap: () => context.push(Routes.spent),
                  ),
                ),
              ],
            ),
          ),
          if (owed > 0) _Owed(cents: owed),
        ],
      ),
    );
  }
}

/// O que foi atendido e nao foi pago.
///
/// Fora dos dois cartoes de proposito: nao e entrada — o dinheiro esta com o
/// cliente — e nao e saida. Mas tambem nao pode ficar invisivel, senao o
/// barbeiro so descobre o fiado quando reencontra a pessoa.
class _Owed extends StatelessWidget {
  const new({required this.cents});

  final int cents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alert = theme.status.alert;

    return Padding(
      padding: const EdgeInsets.only(top: Dimens.cardGap),
      child: Material(
        color: alert.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Dimens.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.earned),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.cardPadding,
              vertical: 13,
            ),
            child: Row(
              children: [
                Icon(
                  Symbols.pending_actions_rounded,
                  weight: 500,
                  color: alert,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${formatMoney(cents)} fiado',
                    style: theme.textTheme.bodyLarge?.copyWith(color: alert),
                  ),
                ),
                Icon(
                  Symbols.chevron_right_rounded,
                  weight: 500,
                  size: 20,
                  color: alert,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Door extends StatelessWidget {
  const new({
    required this.label,
    required this.cents,
    required this.note,
    required this.onTap,
  });

  final String label;
  final int cents;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                Symbols.chevron_right_rounded,
                size: 18,
                weight: 600,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            formatMoney(cents),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.displaySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            // Uma linha, cortada com reticência: nota comprida crescendo para
            // baixo desalinha o par, e os dois cartões deixam de ser um par.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
