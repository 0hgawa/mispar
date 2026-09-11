import 'package:flutter/material.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Altura da barra aberta. O Material usa 152 na barra grande; aqui o título
/// tem 24, não 28, e 112 é o bastante — quanto mais curto o percurso, mais
/// cedo o nome chega ao lado da seta.
const _expanded = 112.0;

/// Onde um título termina e o outro começa, na fração de barra aberta.
///
/// Abaixo disto o nome já está na barra; acima, ainda está grande. Um ponto
/// só para os dois: assim nunca aparecem juntos.
const _handover = 0.45;

/// Cabeçalho de uma página de navegação: voltar, e o título grande.
///
/// Ao rolar, o título **encolhe para o lado do botão** em vez de sumir. Numa
/// lista comprida — o histórico de um cliente, o extrato de um mês — perder o
/// nome do que se está olhando é perder a referência.
///
/// A troca entre os dois títulos acompanha o dedo. O `SliverAppBar.large` do
/// Material faz isso com um `AnimatedOpacity` de 500ms ligado a um booleano, e
/// na volta o título pequeno ainda está desaparecendo quando o grande já está
/// desenhado — os dois aparecem ao mesmo tempo por meio segundo. Aqui a
/// opacidade sai da posição da rolagem, então não há atraso nem sobreposição.
///
/// E o par do TaskBar: `X` cobre o app inteiro e é tarefa; seta de voltar fica
/// dentro da aba e é navegação. A regra está em task_route.dart.
class PageBar extends StatelessWidget {
  const new({required this.title, this.actions, super.key});

  final String title;

  /// Botão do canto direito, quando a página tem um.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: _expanded,
      leading: IconButton(
        icon: const Icon(Symbols.arrow_back_rounded, weight: 500),
        tooltip: 'Voltar',
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: _SmallTitle(title),
      actions: actions,
      flexibleSpace: _BigTitle(title),
    );
  }
}

/// Quanto ainda resta de barra aberta: 1 no topo, 0 com ela fechada.
double _openness(BuildContext context) {
  final settings = context
      .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
  if (settings == null) return 1;

  final span = settings.maxExtent - settings.minExtent;
  if (span <= 0) return 0;

  return ((settings.currentExtent - settings.minExtent) / span).clamp(0.0, 1.0);
}

/// O nome ao lado da seta, que só existe depois que o grande saiu.
class _SmallTitle extends StatelessWidget {
  const new(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final open = _openness(context);
    final opacity = ((_handover - open) / _handover).clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// O nome grande, no pé da barra aberta.
class _BigTitle extends StatelessWidget {
  const new(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = _openness(context);
    final opacity = ((open - _handover) / (1 - _handover)).clamp(0.0, 1.0);
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();

    return Column(
      children: [
        // A altura da barra fechada e do sistema fica de fora: o titulo grande
        // mora no que sobra embaixo dela.
        SizedBox(height: settings?.minExtent ?? 0),
        Expanded(
          child: ClipRect(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Opacity(
                opacity: opacity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Dimens.screenGutter,
                    0,
                    Dimens.screenGutter,
                    12,
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A linha que explica a página, logo abaixo do título.
///
/// Fora da barra de propósito: encolhida ao lado do botão de voltar ela não
/// caberia, e o que importa ali é o nome. Aqui ela some junto com o título
/// grande, que é o certo — é contexto, não identidade.
class PageSubtitle extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

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
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
