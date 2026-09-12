import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marcos_barber/src/core/router/app_router.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/agenda/domain/day_slot.dart';
import 'package:marcos_barber/src/features/agenda/presentation/week_view_model.dart';
import 'package:marcos_barber/src/features/agenda/presentation/widgets/appointment_sheet.dart';
import 'package:marcos_barber/src/features/booking/presentation/new_appointment_view_model.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/widgets/app_card.dart';
import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:material_symbols_icons/symbols.dart';

/// A semana inteira numa tela.
///
/// Mesma agenda da visao de Dia, so que resumida. Tres regras seguram a
/// leitura:
///
/// - **Um cartao por dia, e nao um por horario.** Uma semana cheia tinha vinte
///   cartoes soltos, com linha de ponta a ponta entre os dias — parecia
///   planilha. Agora o dia inteiro mora num cartao so, e os horarios sao
///   linhas dentro dele.
/// - **Dia vazio ocupa uma linha, nao um bloco.** Numa semana com tres dias
///   cheios, os outros quatro nao podem gastar metade da tela dizendo que nao
///   aconteceu nada. A altura vira a noticia: grosso e dia cheio, fino e dia
///   livre.
/// - **Brecha nao aparece aqui.** Na visao de Dia o buraco de 40 minutos e a
///   oportunidade; na semana, entre dois nomes, e ruido. O tempo livre da
///   semana esta somado no topo.
///
/// Nada aqui troca de visao: tocar um horario abre a folha dele e continua na
/// semana.
class WeekView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(weekOverviewProvider),
      onRetry: () => ref.invalidate(weekOverviewProvider),
      builder: (week) => ListView(
        // Espaco para o botao redondo nao tapar a ultima linha.
        padding: const EdgeInsets.fromLTRB(
          Dimens.screenGutter,
          0,
          Dimens.screenGutter,
          92,
        ),
        children: [
          _Summary(week: week),
          for (final day in week.days) _Day(day: day),
        ],
      ),
    );
  }
}

/// Uma linha so com o resumo. O numero detalhado mora no Caixa.
class _Summary extends StatelessWidget {
  const new({required this.week});

  final WeekOverview week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.gapSmall),
      child: Text(
        '${(week.occupancy * 100).round()}% da cadeira vendida · '
        '${formatDuration(week.freeTime)} vagas',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const new({required this.day});

  final DayOverview day;

  @override
  Widget build(BuildContext context) {
    // A brecha nao entra na semana: o que sobra e o que ocupa a cadeira.
    final taken = [
      for (final slot in day.slots)
        if (slot is! FreeSlot) slot,
    ];
    if (day.isClosed || taken.isEmpty) return _QuietDay(day: day);

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.gapMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DayHeading(day: day),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < taken.length; i++) ...[
                  // Pelo indice, e nao comparando com o primeiro: dois blocos
                  // sao iguais por valor, e a comparacao comeria o fio.
                  if (i > 0) const _RowDivider(),
                  switch (taken[i]) {
                    BookedSlot(:final appointment) => _BookedRow(
                      appointment: appointment,
                    ),
                    final BlockedSlot blocked => _ClosedRow(slot: blocked),
                    FreeSlot() => const SizedBox.shrink(),
                  },
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dia fechado ou sem ninguem: cabe numa linha.
///
/// Sem cartao de proposito — a diferenca de altura entre esta linha e o bloco
/// de um dia cheio e o desenho da semana.
class _QuietDay extends ConsumerWidget {
  const new({required this.day});

  final DayOverview day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canBook = !day.isClosed && !day.isPast;

    final line = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          _DayLabel(day: day, isQuiet: true),
          const Spacer(),
          Text(
            day.isClosed ? 'fechado' : 'vago',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (!canBook) return line;

    return InkWell(
      onTap: () {
        ref.read(bookingProvider.notifier).startOnDay(day.date);
        unawaited(context.push(Routes.newAppointment));
      },
      child: line,
    );
  }
}

/// O nome do dia, acima do cartao.
///
/// Fora do cartao e no tom de rotulo de secao, como no resto do app: o
/// cabecalho apresenta o bloco, e nao disputa com os nomes de dentro dele.
///
/// Sem o total do dia: dinheiro e assunto do Caixa, e o da semana ja esta na
/// linha de cima. Aqui ele so competia com os nomes.
class _DayHeading extends StatelessWidget {
  const new({required this.day});

  final DayOverview day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, Dimens.gapSmall, 2, 6),
      child: _DayLabel(day: day, isQuiet: false),
    );
  }
}

/// "qui 10", com o ponto de hoje.
class _DayLabel extends StatelessWidget {
  const new({required this.day, required this.isQuiet});

  final DayOverview day;

  /// Dia sem ninguem fica mais apagado: e o que se pula ao ler a semana.
  final bool isQuiet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '${formatShortWeekday(day.date)} ${day.date.day}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: isQuiet ? colors.onSurfaceVariant : colors.onSurface,
          ),
        ),
        if (day.isToday) ...[
          const SizedBox(width: 6),
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: colors.onSurface,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

/// O fio entre dois horarios do mesmo dia.
///
/// Recuado e claro: separa linhas irmas dentro de um cartao, nao um bloco do
/// outro — para isso quem serve e o espaco entre os cartoes.
class _RowDivider extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 54,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

/// Um horario marcado, como linha do cartao do dia.
class _BookedRow extends StatelessWidget {
  const new({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      // Abre a folha do horario. Continua na semana.
      onTap: () => AppointmentSheet.show(context, appointment),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                formatHour(appointment.startsAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                appointment.who,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              appointment.service.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uma faixa fechada — feriado, medico, viagem. Sem toque: nao ha o que fazer
/// com ela aqui.
class _ClosedRow extends StatelessWidget {
  const new({required this.slot});

  final BlockedSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              formatHour(slot.start),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Symbols.block_rounded,
            size: 16,
            weight: 500,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              slot.reason ?? 'Fechado',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
