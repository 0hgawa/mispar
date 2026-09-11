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
import 'package:marcos_barber/src/shared/formatters/money.dart';
import 'package:marcos_barber/src/shared/widgets/async_view.dart';
import 'package:material_symbols_icons/symbols.dart';

/// A semana inteira numa tela.
///
/// Mesma agenda da visao de Dia, so que resumida. Duas regras seguram a
/// leitura:
///
/// - **Dia vazio ocupa uma linha, nao um bloco.** Numa semana com tres dias
///   cheios, os outros quatro nao podem gastar metade da tela dizendo que nao
///   aconteceu nada.
/// - **Card branco para quem esta marcado, cinza para o que esta vago.** E a
///   mesma linguagem da visao de Dia, so que mais baixa: buraco na agenda tem
///   que parecer buraco nas duas telas.
/// - **Nada aqui troca de visao.** Tocar um horario abre a folha dele e
///   continua na semana. Quem quer o Dia toca em "Dia" — foi para isso que o
///   segmentado do cabecalho existe.
class WeekView extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(weekOverviewProvider),
      onRetry: () => ref.invalidate(weekOverviewProvider),
      builder: (week) => ListView(
        // Espaco para o botao redondo nao tapar a ultima linha.
        padding: const EdgeInsets.only(bottom: 92),
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
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        0,
        Dimens.screenGutter,
        Dimens.gapSmall,
      ),
      child: Text(
        // "livres" prometeria horario a venda tambem nos dias que ja passaram.
        '${(week.occupancy * 100).round()}% da cadeira vendida · '
        '${formatDuration(week.freeTime)} sem atendimento',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Day extends ConsumerWidget {
  const new({required this.day});

  final DayOverview day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fechado, ou aberto e sem ninguem: nao ha grade para mostrar.
    final hasGrid = !day.isClosed && day.slots.any((slot) => slot is! FreeSlot);
    if (!hasGrid) return _QuietDay(day: day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DayHeader(day: day),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.screenGutter,
            0,
            Dimens.screenGutter,
            Dimens.gapMedium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final slot in day.slots) ...[
                if (slot != day.slots.first)
                  const SizedBox(height: Dimens.cardGap),
                switch (slot) {
                  BookedSlot(:final appointment) => _BookedRow(
                    appointment: appointment,
                  ),
                  FreeSlot() => _GapRow(slot: slot),
                  BlockedSlot() => _ClosedRow(slot: slot),
                },
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Dia sem grade: cabe numa linha.
///
/// Fechado, dia que ja passou sem ninguem, ou dia livre que ainda da para
/// vender — este ultimo e o unico que convida a tocar.
class _QuietDay extends ConsumerWidget {
  const new({required this.day});

  final DayOverview day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canBook = !day.isClosed && !day.isPast;

    final line = Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        Dimens.gapMedium,
        Dimens.screenGutter,
        Dimens.gapMedium,
      ),
      child: Row(
        children: [
          _DayLabel(day: day, isQuiet: true),
          const Spacer(),
          Text(
            switch (day) {
              _ when day.isClosed => 'fechado',
              _ when day.isPast => 'ninguém',
              _ => 'livre o dia todo',
            },
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Rule(),
        if (!canBook)
          line
        else
          InkWell(
            onTap: () {
              ref.read(bookingProvider.notifier).startOnDay(day.date);
              unawaited(context.push(Routes.newAppointment));
            },
            child: line,
          ),
      ],
    );
  }
}

/// O cabecalho do dia que tem grade. So texto: nao leva a lugar nenhum.
class _DayHeader extends StatelessWidget {
  const new({required this.day});

  final DayOverview day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Rule(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.screenGutter,
            Dimens.gapMedium,
            Dimens.screenGutter,
            Dimens.gapSmall,
          ),
          child: Row(
            children: [
              _DayLabel(day: day, isQuiet: false),
              const Spacer(),
              Text(
                day.revenueCents == 0
                    ? '${day.bookedCount} marcado'
                    : formatMoney(day.revenueCents),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "qui 10", com o ponto de hoje.
class _DayLabel extends StatelessWidget {
  const new({required this.day, required this.isQuiet});

  final DayOverview day;

  /// Dia sem grade fica mais apagado: e o que se pula ao ler a semana.
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
          // Peso de titulo: este cabecalho manda nos cards abaixo dele. Com o
          // peso de antes ele pesava menos que os nomes dos clientes, e a
          // semana virava uma lista sem dono.
          '${formatShortWeekday(day.date)} ${day.date.day}',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 17,
            color: isQuiet ? colors.onSurfaceVariant : colors.onSurface,
          ),
        ),
        if (day.isToday) ...[
          const SizedBox(width: 6),
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(bottom: 5),
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

/// A linha que separa um dia do outro. Vai de ponta a ponta, ao contrario das
/// divisorias de dentro do dia — e o que faz o olho ver blocos.
class _Rule extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: Theme.of(context).colorScheme.outline);
  }
}

/// Um horario marcado. Card branco, igual ao da visao de Dia, so que mais
/// baixo: aqui a tela precisa caber sete dias.
class _BookedRow extends StatelessWidget {
  const new({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(Dimens.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Abre a folha do horario. Continua na semana.
        onTap: () => AppointmentSheet.show(context, appointment),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.cardPadding,
            vertical: 13,
          ),
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
                  appointment.client.name,
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
      ),
    );
  }
}

/// Uma brecha. Cinza, como na visao de Dia — buraco tem que parecer buraco.
/// Tocar leva direto para marcar naquela hora.
class _GapRow extends ConsumerWidget {
  const new({required this.slot});

  final FreeSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Vaga que ja terminou nao convida mais: o formulario nao teria horario
    // para oferecer.
    final isGone = slot.end.isBefore(DateTime.now());

    return Material(
      color: colors.secondaryContainer,
      borderRadius: BorderRadius.circular(Dimens.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isGone
            ? null
            : () {
                ref.read(bookingProvider.notifier).startAtSlot(slot.start);
                unawaited(context.push(Routes.newAppointment));
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.cardPadding,
            vertical: 12,
          ),
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
              Expanded(
                child: Text(
                  isGone
                      ? '${formatDuration(slot.end.difference(slot.start))} sem ninguém'
                      : '${formatDuration(slot.end.difference(slot.start))} livre',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurfaceVariant,
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

/// Uma faixa fechada — feriado, medico, viagem. Cinza e sem toque: nao ha o
/// que fazer com ela aqui.
class _ClosedRow extends StatelessWidget {
  const new({required this.slot});

  final BlockedSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(Dimens.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.cardPadding,
          vertical: 12,
        ),
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
      ),
    );
  }
}
