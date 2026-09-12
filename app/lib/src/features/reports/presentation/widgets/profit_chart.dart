import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/core/theme/status_colors.dart';
import 'package:mispar/src/features/reports/domain/cash_trend.dart';
import 'package:mispar/src/features/reports/domain/cash_window.dart';
import 'package:mispar/src/features/reports/presentation/cash_view_model.dart';
import 'package:mispar/src/shared/widgets/screen_title.dart';

/// Altura da metade de cima do gráfico.
const _half = 62.0;

/// Folga acima e abaixo das barras, dentro da área tocável.
const _padding = 4.0;

/// O que sobrou em cada um dos últimos seis meses.
///
/// É o que o número sozinho não responde: *estou melhorando?* Seis barras
/// cabem no celular; trinta barras de dia, não.
///
/// Cada barra é também um atalho — tocar em agosto põe o Caixa inteiro em
/// agosto. O seletor de período continua lá para o resto.
class ProfitChart extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earned = ref.watch(earnedByMonthProvider).value;
    final spent = ref.watch(spentByMonthProvider).value;
    if (earned == null || spent == null) return const SizedBox.shrink();

    final profit = [
      for (var i = 0; i < earned.length; i++) earned[i] - spent[i],
    ];

    // Com um mês só de uso, seis barras seriam cinco buracos e uma barra: não
    // há tendência para mostrar, e o gráfico mentiria sobre o que sabe.
    final moved = profit.where((cents) => cents != 0).length;
    if (moved < 2) return const SizedBox.shrink();

    final starts = monthStarts(now: DateTime.now());
    final biggest = profit
        .map((cents) => cents.abs())
        .reduce((a, b) => a > b ? a : b);
    final hasLoss = profit.any((cents) => cents < 0);
    final chosen = _chosenMonth(ref.watch(cashFilterChoiceProvider));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Sobrou por mês'),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.screenGutter - 3,
          ),
          child: Stack(
            children: [
              // A linha do zero. E ela que da chao a fileira: mes sem nada nao
              // desenha barra nenhuma, fica a linha nua — e barra para baixo so
              // quer dizer prejuizo porque existe um zero de onde descer.
              Positioned(
                left: 3,
                right: 3,
                top: _padding + _half,
                child: Container(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < profit.length; i++)
                    Expanded(
                      child: _Bar(
                        month: starts[i],
                        cents: profit[i],
                        biggest: biggest,
                        hasLoss: hasLoss,
                        isChosen:
                            chosen?.year == starts[i].year &&
                            chosen?.month == starts[i].month,
                        onTap: () => _choose(ref, starts[i]),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// O mes que o filtro esta apontando, quando ele aponta para um mes inteiro.
  DateTime? _chosenMonth(CashFilter filter) {
    final now = DateTime.now();

    return switch (filter.period) {
      CashPeriod.month => DateTime(now.year, now.month),
      CashPeriod.lastMonth => DateTime(now.year, now.month - 1),
      CashPeriod.custom => switch (filter.range) {
        final range? => wholeMonthOf(start: range.start, end: range.end),
        _ => null,
      },
      _ => null,
    };
  }

  void _choose(WidgetRef ref, DateTime month) {
    final now = DateTime.now();
    final filter = ref.read(cashFilterChoiceProvider.notifier);

    // O mes corrente tem nome proprio e comparacao com o de tras; vira "Este
    // mes" em vez de um intervalo que chegaria ate o dia 30 do que ainda nem
    // aconteceu.
    if (month.year == now.year && month.month == now.month) {
      filter.selectPeriod(CashPeriod.month);
      return;
    }

    filter.selectRange(
      DateTimeRange(
        start: month,
        // Dia 0 do mes seguinte e o ultimo deste. O calendario fecha inclusivo.
        end: DateTime(month.year, month.month + 1, 0),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const new({
    required this.month,
    required this.cents,
    required this.biggest,
    required this.hasLoss,
    required this.isChosen,
    required this.onTap,
  });

  final DateTime month;
  final int cents;
  final int biggest;
  final bool hasLoss;
  final bool isChosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Mes fraco tem barra fina, e nao barra nenhuma: sem o minimo, um mes de
    // R$ 20 ao lado de um de R$ 2.000 sumiria e pareceria mes fechado.
    final full = biggest == 0 ? 0.0 : (cents.abs() / biggest) * _half;
    final height = full < 4 ? 4.0 : full;

    final bar = cents == 0
        ? const SizedBox.shrink()
        : Container(
            height: height,
            decoration: BoxDecoration(
              color: cents < 0
                  ? theme.status.alert
                  : isChosen
                  ? colors.onSurface
                  : colors.onSurface.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(3),
            ),
          );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: _padding),
        child: Column(
          children: [
            SizedBox(
              height: hasLoss ? _half * 2 : _half,
              child: Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: cents >= 0 ? bar : const SizedBox.shrink(),
                    ),
                  ),
                  if (hasLoss)
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: cents < 0 ? bar : const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _shortMonth(month),
              style: theme.textTheme.bodySmall?.copyWith(
                color: isChosen ? colors.onSurface : colors.onSurfaceVariant,
                fontWeight: isChosen ? FontWeight.w700 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "ago", "set" — sem o ponto que o `intl` coloca.
String _shortMonth(DateTime month) {
  final name = DateFormat.MMM('pt_BR').format(month);
  return name.endsWith('.') ? name.substring(0, name.length - 1) : name;
}
