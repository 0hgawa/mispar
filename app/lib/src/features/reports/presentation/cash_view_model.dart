import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:marcos_barber/src/features/agenda/data/agenda_repository.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment_status.dart';
import 'package:marcos_barber/src/features/reports/data/expense_repository.dart';
import 'package:marcos_barber/src/features/reports/domain/cash_trend.dart';
import 'package:marcos_barber/src/features/reports/domain/cash_window.dart';
import 'package:marcos_barber/src/features/reports/domain/expense.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/week.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cash_view_model.g.dart';

enum CashPeriod {
  today('Hoje'),
  yesterday('Ontem'),
  week('Esta semana'),
  month('Este mês'),
  lastMonth('Mês passado'),
  year('Este ano'),
  custom('Escolher datas…');

  new(this.label);

  /// Como aparece no cabecalho e na folha de escolha.
  final String label;
}

/// O recorte de tempo que o Marcos esta olhando.
class CashFilter {
  const new({this.period = CashPeriod.month, this.range});

  final CashPeriod period;

  /// Preenchido so quando o periodo e [CashPeriod.custom].
  final DateTimeRange? range;

  /// O que aparece no cabecalho. Intervalo escolhido a mao mostra as datas, e
  /// nao a palavra "Escolher" — depois de escolhido, o que importa e qual.
  String get label {
    final range = this.range;
    if (period != CashPeriod.custom || range == null) return period.label;

    // Mes inteiro, escolhido com um toque no grafico, tem nome. Duas datas no
    // lugar de "Agosto de 2026" obrigariam a ler para descobrir o obvio.
    final month = wholeMonthOf(start: range.start, end: range.end);
    if (month != null) return formatMonthAndYear(month);

    return '${formatShortDate(range.start)} – ${formatShortDate(range.end)}';
  }

  /// Como chamar o periodo de tras. Nulo quando nao ha nome curto para ele —
  /// um intervalo escolhido a mao nao tem "anterior" que se explique sozinho.
  String? get previousLabel {
    final now = DateTime.now();

    final name = switch (period) {
      CashPeriod.today => 'que ontem',
      CashPeriod.yesterday => 'que anteontem',
      CashPeriod.week => 'que a semana passada',
      CashPeriod.month => 'que ${_monthName(now.month - 1, now.year)}',
      CashPeriod.lastMonth => 'que ${_monthName(now.month - 2, now.year)}',
      CashPeriod.year => 'que o ano passado',
      CashPeriod.custom => null,
    };

    if (name == null) return null;

    // Periodo que ainda esta correndo se compara com o mesmo pedaco do
    // anterior, e o rotulo tem que dizer isso.
    if (!now.isBefore(resolve().to)) return name;
    return period == CashPeriod.today
        ? '$name ate esta hora'
        : '$name ate aqui';
  }

  /// As datas de fato consultadas, ja resolvidas. O fim e sempre exclusivo.
  ({DateTime from, DateTime to}) resolve() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = startOfWeek(today);

    return switch (period) {
      CashPeriod.today => (from: today, to: today.add(const Duration(days: 1))),
      CashPeriod.yesterday => (
        from: today.subtract(const Duration(days: 1)),
        to: today,
      ),
      CashPeriod.week => (
        from: monday,
        to: monday.add(const Duration(days: 7)),
      ),
      CashPeriod.month => (
        from: DateTime(now.year, now.month),
        to: DateTime(now.year, now.month + 1),
      ),
      CashPeriod.lastMonth => (
        from: DateTime(now.year, now.month - 1),
        to: DateTime(now.year, now.month),
      ),
      CashPeriod.year => (from: DateTime(now.year), to: DateTime(now.year + 1)),
      CashPeriod.custom => (
        from: range?.start ?? today,
        // O fim escolhido no calendario e inclusivo; a consulta e exclusiva.
        to: (range?.end ?? today).add(const Duration(days: 1)),
      ),
    };
  }

  /// A janela imediatamente anterior, do mesmo tamanho. E com ela que o
  /// periodo atual se compara.
  ({DateTime from, DateTime to})? resolvePrevious() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = startOfWeek(today);
    const day = Duration(days: 1);

    final full = switch (period) {
      CashPeriod.today => (from: today.subtract(day), to: today),
      CashPeriod.yesterday => (
        from: today.subtract(const Duration(days: 2)),
        to: today.subtract(day),
      ),
      CashPeriod.week => (
        from: monday.subtract(const Duration(days: 7)),
        to: monday,
      ),
      CashPeriod.month => (
        from: DateTime(now.year, now.month - 1),
        to: DateTime(now.year, now.month),
      ),
      CashPeriod.lastMonth => (
        from: DateTime(now.year, now.month - 2),
        to: DateTime(now.year, now.month - 1),
      ),
      CashPeriod.year => (from: DateTime(now.year - 1), to: DateTime(now.year)),
      CashPeriod.custom => null,
    };

    if (full == null) return null;
    return sameProgress(previous: full, current: resolve(), now: now);
  }
}

/// "agosto", "dezembro" — aceita mes 0 ou negativo e volta para o ano de tras.
String _monthName(int month, int year) {
  final name = DateFormat.MMMM('pt_BR').format(DateTime(year, month));
  return name;
}

class CashReport {
  const new({
    required this.earnedCents,
    required this.expectedCents,
    required this.lostCents,
    required this.servedCount,
    required this.soldCount,
    required this.bookedCount,
    required this.noShowCount,
    required this.entries,
  });

  /// So o que foi concluido. Horario marcado para daqui a uma hora nao e
  /// faturamento — e promessa.
  final int earnedCents;

  /// Marcado e ainda de pe no periodo. Aparece separado para o numero de cima
  /// nao mentir.
  final int expectedCents;

  final int lostCents;

  /// Quantos atendimentos aconteceram. Venda de produto nao entra: ninguem
  /// sentou na cadeira para comprar pomada.
  final int servedCount;

  final int soldCount;
  final int bookedCount;
  final int noShowCount;

  /// Os atendimentos que formam o total, do mais recente para o mais antigo.
  /// Numero sem lista nao da para conferir.
  final List<Appointment> entries;
}

@riverpod
class CashFilterChoice extends _$CashFilterChoice {
  @override
  CashFilter build() => const CashFilter();

  void selectPeriod(CashPeriod period) => state = CashFilter(period: period);

  void selectRange(DateTimeRange range) =>
      state = CashFilter(period: CashPeriod.custom, range: range);
}

/// O que saiu no mesmo recorte de tempo.
///
/// Relatorio proprio, e nao um campo do outro: sao duas tabelas e dois fluxos,
/// e juntar os dois so para desmontar de novo na tela nao paga o preco de
/// combinar streams.
class SpentReport {
  const new({
    required this.totalCents,
    required this.fixedCents,
    required this.expenses,
  });

  final int totalCents;

  /// O que se repete todo mes. E o piso: quanto a barbearia precisa faturar
  /// antes de comecar a sobrar.
  final int fixedCents;

  int get looseCents => totalCents - fixedCents;

  /// Os lancamentos, do mais recente para o mais antigo.
  final List<Expense> expenses;

  bool get isEmpty => expenses.isEmpty;
}

@riverpod
Stream<SpentReport> spentReport(Ref ref) {
  final window = ref.watch(cashFilterChoiceProvider).resolve();

  return ref
      .watch(expenseRepositoryProvider)
      .watchRange(window.from, window.to)
      .map((expenses) {
        var total = 0;
        var fixed = 0;

        for (final expense in expenses) {
          total += expense.cents;
          if (expense.repeatsMonthly) fixed += expense.cents;
        }

        return SpentReport(
          totalCents: total,
          fixedCents: fixed,
          expenses: expenses,
        );
      });
}

/// Quanto entrou e quanto saiu no periodo de tras.
///
/// Leitura unica, e nao fluxo: e um numero de referencia, nao muda enquanto o
/// Marcos olha a tela.
@riverpod
Future<({int earnedCents, int spentCents})> previousPeriod(Ref ref) async {
  final window = ref.watch(cashFilterChoiceProvider).resolvePrevious();
  if (window == null) return (earnedCents: 0, spentCents: 0);

  final appointments = await ref
      .watch(agendaRepositoryProvider)
      .watchRange(window.from, window.to, includeSales: true)
      .first;
  final expenses = await ref
      .watch(expenseRepositoryProvider)
      .watchRange(window.from, window.to)
      .first;

  var earned = 0;
  for (final appointment in appointments) {
    if (appointment.status == AppointmentStatus.done) {
      earned += appointment.priceCents;
    }
  }

  var spent = 0;
  for (final expense in expenses) {
    spent += expense.cents;
  }

  return (earnedCents: earned, spentCents: spent);
}

/// De quanto por cento [now] mudou em relacao a [before].
///
/// Nulo quando nao ha com o que comparar: sem base, "100% a mais" nao diz
/// nada — a barbearia so nao tinha aberto.
int? percentChange({required int before, required int now}) {
  if (before <= 0) return null;
  return (((now - before) / before) * 100).round();
}

@riverpod
Stream<CashReport> cashReport(Ref ref) {
  final window = ref.watch(cashFilterChoiceProvider).resolve();

  return ref
      .watch(agendaRepositoryProvider)
      .watchRange(window.from, window.to, includeSales: true)
      .map((all) {
        var earned = 0;
        var expected = 0;
        var lost = 0;
        var served = 0;
        var sold = 0;
        var booked = 0;
        var noShows = 0;
        final entries = <Appointment>[];

        for (final appointment in all) {
          final price = appointment.priceCents;

          switch (appointment.status) {
            case AppointmentStatus.done:
              earned += price;
              if (appointment.service.isProduct) {
                sold++;
              } else {
                served++;
              }
              entries.add(appointment);
            case AppointmentStatus.noShow:
              lost += price;
              noShows++;
            case AppointmentStatus.awaiting ||
                AppointmentStatus.confirmed ||
                AppointmentStatus.depositPaid:
              expected += price;
              booked++;
            // Desmarcado a tempo nao e perda: o horario voltou para a agenda.
            case AppointmentStatus.cancelled:
              break;
          }
        }

        return CashReport(
          earnedCents: earned,
          expectedCents: expected,
          lostCents: lost,
          servedCount: served,
          soldCount: sold,
          bookedCount: booked,
          noShowCount: noShows,
          entries: entries.reversed.toList(growable: false),
        );
      });
}

/// Quanto entrou em cada um dos ultimos meses, do mais antigo para o mais novo.
///
/// Serie propria, e nao um pedaco do relatorio do periodo: o grafico mostra
/// seis meses justamente para nao depender do recorte que esta escolhido.
@riverpod
Stream<List<int>> earnedByMonth(Ref ref) {
  final starts = monthStarts(now: DateTime.now());
  final last = starts.last;

  return ref
      .watch(agendaRepositoryProvider)
      .watchRange(
        starts.first,
        DateTime(last.year, last.month + 1),
        includeSales: true,
      )
      .map(
        (all) => byMonth(
          starts: starts,
          moves: [
            for (final appointment in all)
              if (appointment.status == AppointmentStatus.done)
                (at: appointment.startsAt, cents: appointment.priceCents),
          ],
        ),
      );
}

/// Quanto saiu em cada um dos mesmos meses.
@riverpod
Stream<List<int>> spentByMonth(Ref ref) {
  final starts = monthStarts(now: DateTime.now());
  final last = starts.last;

  return ref
      .watch(expenseRepositoryProvider)
      .watchRange(starts.first, DateTime(last.year, last.month + 1))
      .map(
        (all) => byMonth(
          starts: starts,
          moves: [
            for (final expense in all)
              (at: expense.spentAt, cents: expense.cents),
          ],
        ),
      );
}
