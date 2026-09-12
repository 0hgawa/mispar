import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/shared/formatters/day_time.dart';
import 'package:mispar/src/shared/week.dart';

/// A semana do topo: sete colunas fixas, de domingo a sábado.
///
/// A régua antiga rolava sem fim, e rolagem sem fim não tem forma: o Marcos
/// não sabia onde estava nem quanto faltava para o fim da semana. Com a semana
/// inteira sempre na tela, a posição do dia **é** a informação — sábado é
/// sempre a última coluna.
///
/// Com [expanded], o mês aparece **por cima**, ancorado na linha da semana e
/// cobrindo ela. Não empurra nada: a agenda embaixo fica parada, e nada dela é
/// medido de novo enquanto o calendário entra. É o que o Booksy faz, e o
/// motivo é o mesmo — grade de agenda é a parte cara da tela, e abrir o mês
/// não tem por que custar um relayout dela por quadro.
///
/// Arrastar para o lado troca de semana — ou de mês, quando aberto. Trocar não
/// muda o dia escolhido: quem escolhe é o toque, e assim dá para espiar a
/// semana que vem sem perder o dia que está aberto.
class DayStrip extends StatefulWidget {
  const new({
    required this.selected,
    required this.onSelect,
    this.expanded = false,
    this.onMonthChanged,
    super.key,
  });

  /// Recebe o dia por parametro em vez de ler o provider: a tela de marcar
  /// escolhe um dia sem mexer no que a agenda esta mostrando por tras.
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  /// Mes inteiro por cima da semana.
  final bool expanded;

  /// Qual mes a grade esta mostrando. Nulo quando fechada — fechada, quem
  /// manda no titulo e o dia escolhido.
  final ValueChanged<DateTime?>? onMonthChanged;

  @override
  State<DayStrip> createState() => _DayStripState();
}

/// Altura de uma linha de dias: o circulo mais o respiro de baixo.
const _row = 44.0;

/// Recuo lateral da grade. Menor que a margem da tela porque o circulo do dia
/// ja tem folga em volta: alinhar pela caixa deixaria o domingo afundado.
const double _sidePad = Dimens.screenGutter - 4;

/// Pagina do meio. O calendario nao tem fim para os dois lados, entao os dois
/// carrosseis comecam no meio de um numero grande de paginas.
const _middle = 10000;

/// Quantas linhas o mes ocupa — quatro, cinco ou seis, as que ele usa.
///
/// Dia 0 do mes seguinte e o ultimo deste, e a sobra do comeco sao os dias que
/// a primeira linha empresta do mes de tras.
int _rowsIn(DateTime month) {
  final lead = month.difference(startOfWeek(month)).inDays;
  final days = DateTime(month.year, month.month + 1, 0).day;
  return ((lead + days) / 7).ceil();
}

class _DayStripState extends State<DayStrip>
    with SingleTickerProviderStateMixin {
  late final DateTime _weekBase = startOfWeek(widget.selected);
  late DateTime _monthBase = DateTime(
    widget.selected.year,
    widget.selected.month,
  );

  final _weeks = PageController(initialPage: _middle);
  PageController _months = PageController(initialPage: _middle);

  final _link = LayerLink();
  final _panel = OverlayPortalController();
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  /// O domingo da semana que esta na tela. E dele que sai o mes na hora de
  /// abrir: quem estava olhando novembro abre novembro.
  late DateTime _shownWeek = _weekBase;

  @override
  void didUpdateWidget(DayStrip old) {
    super.didUpdateWidget(old);

    if (old.expanded != widget.expanded) {
      _onToggle();
      return;
    }

    if (old.selected != widget.selected && !widget.expanded) {
      _afterFrame(() => _revealWeekOf(widget.selected));
    }
  }

  /// Leva a semana do dia escolhido para a tela. O dia pode ter mudado por
  /// fora — pelo mes, por um atalho — e cair em outra semana.
  void _revealWeekOf(DateTime day) {
    final sunday = startOfWeek(day);
    _shownWeek = sunday;

    final page = _middle + sunday.difference(_weekBase).inDays ~/ 7;
    if (!_weeks.hasClients || _weeks.page?.round() == page) return;
    _weeks.jumpToPage(page);
  }

  void _onToggle() {
    if (widget.expanded) {
      // A quarta-feira decide o mes: a semana de 30/08 a 05/09 e setembro
      // para quem olha, mesmo comecando em agosto.
      final middleOfWeek = _shownWeek.add(const Duration(days: 3));
      _monthBase = DateTime(middleOfWeek.year, middleOfWeek.month);
      // Controlador novo a cada abertura: a pagina do meio passa a ser este
      // mes, e nao o de quando a tela nasceu.
      _months.dispose();
      _months = PageController(initialPage: _middle);

      _afterFrame(() {
        _panel.show();
        _fade.forward();
        widget.onMonthChanged?.call(_monthBase);
      });
      return;
    }

    _afterFrame(() {
      // Fechou: a semana vai para a do dia escolhido antes de reaparecer.
      _revealWeekOf(widget.selected);
      widget.onMonthChanged?.call(null);
      unawaited(
        _fade.reverse().whenComplete(() {
          if (mounted) _panel.hide();
        }),
      );
    });
  }

  /// Faz depois do quadro o que nao pode ser feito durante ele.
  ///
  /// Abrir e fechar chega por `didUpdateWidget`, que roda no meio da
  /// construcao da arvore. Escrever em provider, mostrar o portal e mexer na
  /// rolagem sao os tres proibidos ali — e os tres deram tela vermelha.
  void _afterFrame(VoidCallback work) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) work();
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    _weeks.dispose();
    _months.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.gapMedium),
      child: Column(
        children: [
          const _Weekdays(),
          const SizedBox(height: 6),
          // O alvo e a linha da semana: o mes nasce exatamente em cima dela,
          // entao a primeira linha do mes cai onde a semana estava.
          CompositedTransformTarget(
            link: _link,
            child: OverlayPortal(
              controller: _panel,
              overlayChildBuilder: _month,
              child: SizedBox(height: _row, child: _week(today)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _week(DateTime today) {
    return PageView.builder(
      controller: _weeks,
      onPageChanged: (page) =>
          _shownWeek = _weekBase.add(Duration(days: 7 * (page - _middle))),
      itemBuilder: (context, page) => _Week(
        sunday: _weekBase.add(Duration(days: 7 * (page - _middle))),
        selected: widget.selected,
        today: today,
        onTap: widget.onSelect,
      ),
    );
  }

  /// A grade do mes, na camada de cima.
  Widget _month(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final colors = Theme.of(context).colorScheme;

    return CompositedTransformFollower(
      link: _link,
      showWhenUnlinked: false,
      // O Align solta as restricoes: o filho de um portal chega com a tela
      // inteira apertada, e sem afrouxar o painel pintava o fundo de cima a
      // baixo — a agenda parecia ter sumido em vez de estar atras.
      child: Align(
        alignment: Alignment.topLeft,
        // Fevereiro cabe em quatro linhas e marco pode pedir seis. A altura
        // acompanha o dedo no meio do arrasto, e nao depois dele: ajustar so
        // no fim deixava o mes de seis linhas transbordando a caixa de cinco,
        // que e a listra amarela e preta do Flutter.
        child: AnimatedBuilder(
          animation: _months,
          builder: (context, child) => SizedBox(
            width: MediaQuery.sizeOf(context).width,
            height: _row * _visibleRows() + Dimens.gapSmall,
            child: child,
          ),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, -0.03),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: _fade, curve: Curves.easeOut)),
              child: DecoratedBox(
                // Opaco, porque cobre a agenda: a sombra curta embaixo e o que
                // explica que ele esta por cima e nao no lugar dela.
                decoration: BoxDecoration(
                  color: colors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: colors.onSurface.withValues(alpha: 0.07),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: PageView.builder(
                  controller: _months,
                  onPageChanged: (page) =>
                      widget.onMonthChanged?.call(_monthAt(page)),
                  itemBuilder: (context, page) {
                    final month = _monthAt(page);
                    // A grade sempre comeca no domingo da semana do dia 1.
                    final first = startOfWeek(month);

                    // Solta a altura e alinha no topo. No meio do arrasto a
                    // caixa ainda esta no tamanho do mes de cinco linhas, e o
                    // de seis precisa das seis agora: sem isto o Column fica
                    // espremido e pinta a listra de transbordo. O que passa do
                    // fim o proprio PageView corta, e a ultima fileira vai
                    // sendo revelada conforme a altura cresce.
                    return OverflowBox(
                      alignment: Alignment.topCenter,
                      maxHeight: double.infinity,
                      child: Column(
                        children: [
                          for (var week = 0; week < _rowsIn(month); week++)
                            _Week(
                              sunday: first.add(Duration(days: 7 * week)),
                              selected: widget.selected,
                              today: today,
                              onTap: widget.onSelect,
                              ofMonth: month.month,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DateTime _monthAt(int page) =>
      DateTime(_monthBase.year, _monthBase.month + page - _middle);

  /// Quantas linhas cabem na tela agora — fracionario no meio do arrasto, onde
  /// dois meses aparecem ao mesmo tempo.
  double _visibleRows() {
    if (!_months.hasClients || !_months.position.haveDimensions) {
      return _rowsIn(_monthBase).toDouble();
    }

    final page = _months.page!;
    final from = _rowsIn(_monthAt(page.floor()));
    final to = _rowsIn(_monthAt(page.ceil()));
    return from + (to - from) * (page - page.floor());
  }
}

/// DOM a SÁB, uma vez só. Ficam de fora da grade porque não mudam quando o mês
/// abre — e é isso que faz o mês parecer a mesma régua, mais alta.
class _Weekdays extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Qualquer domingo serve: o rotulo nao depende da data.
    final sunday = startOfWeek(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sidePad),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Text(
                formatShortWeekday(sunday.add(Duration(days: i))).toUpperCase(),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Uma linha de sete dias.
class _Week extends StatelessWidget {
  const new({
    required this.sunday,
    required this.selected,
    required this.today,
    required this.onTap,
    this.ofMonth,
  });

  final DateTime sunday;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onTap;

  /// Mes da grade. Dia de fora dele fica apagado — sumir seria pior, porque o
  /// buraco na fileira parece dia fechado.
  final int? ofMonth;

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < 7; i++) sunday.add(Duration(days: i))];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sidePad),
      child: Row(
        children: [
          for (final day in days)
            Expanded(
              child: _Day(
                day: day,
                isSelected: day == selected,
                isToday: day == today,
                isFaded: ofMonth != null && day.month != ofMonth,
                onTap: () => onTap(day),
              ),
            ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const new({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.isFaded,
    required this.onTap,
  });

  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final bool isFaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      height: _row,
      child: Center(
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Mesma forma, dois pesos: cheio e o dia aberto, vazado e hoje.
              color: isSelected ? colors.onSurface : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday && !isSelected
                  ? Border.all(color: colors.onSurface, width: 1.5)
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: isSelected
                    ? colors.surface
                    : isFaded
                    ? colors.outline
                    : colors.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
