import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:marcos_barber/src/features/agenda/data/agenda_repository.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment_status.dart';
import 'package:marcos_barber/src/features/reports/data/expense_repository.dart';
import 'package:marcos_barber/src/features/reports/domain/expense.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cash_view_model.g.dart';

enum CashPeriod {
  today('Hoje'),
  week('Semana'),
  month('Mês'),
  custom('Escolher');

  new(this.label);

  final String label;
}

/// Os dois lados da conta. Sao coisas diferentes — o que entra tem cliente e
/// servico, o que sai tem categoria — entao cada um tem a sua tela.
enum CashLane {
  earned('Entrou'),
  spent('Saiu');

  new(this.label);

  final String label;
}

/// Como o faturamento se reparte. So vale do lado do que entrou.
enum CashBreakdown {
  service('Serviço'),
  client('Cliente'),
  payment('Pagamento'),
  entries('Atendimentos');

  new(this.label);

  final String label;
}

/// O recorte de tempo que o Marcos esta olhando.
class CashFilter {
  const new({this.period = CashPeriod.month, this.range});

  final CashPeriod period;

  /// Preenchido so quando o periodo e [CashPeriod.custom].
  final DateTimeRange? range;

  /// Como chamar o periodo de tras. Nulo quando nao ha nome curto para ele —
  /// um intervalo escolhido a mao nao tem "anterior" que se explique sozinho.
  String? get previousLabel => switch (period) {
    CashPeriod.today => 'que ontem',
    CashPeriod.week => 'que a semana passada',
    CashPeriod.month => 'que ${_lastMonthName()}',
    CashPeriod.custom => null,
  };

  String _lastMonthName() {
    final now = DateTime.now();
    final name = DateFormat.MMMM('pt_BR')
        .format(DateTime(now.year, now.month - 1));
    return name;
  }

  /// A janela imediatamente anterior, do mesmo tamanho. E com ela que o
  /// periodo atual se compara.
  ({DateTime from, DateTime to})? resolvePrevious() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );

    return switch (period) {
      CashPeriod.today => (
        from: today.subtract(const Duration(days: 1)),
        to: today,
      ),
      CashPeriod.week => (
        from: monday.subtract(const Duration(days: 7)),
        to: monday,
      ),
      CashPeriod.month => (
        from: DateTime(now.year, now.month - 1),
        to: DateTime(now.year, now.month),
      ),
      CashPeriod.custom => null,
    };
  }

  /// As datas de fato consultadas, ja resolvidas.
  ({DateTime from, DateTime to}) resolve() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );

    return switch (period) {
      CashPeriod.today => (from: today, to: today.add(const Duration(days: 1))),
      CashPeriod.week => (
        from: monday,
        to: monday.add(const Duration(days: 7)),
      ),
      CashPeriod.month => (
        from: DateTime(now.year, now.month),
        to: DateTime(now.year, now.month + 1),
      ),
      CashPeriod.custom => (
        from: range?.start ?? today,
        // O fim escolhido no calendario e inclusivo; a consulta e exclusiva.
        to: (range?.end ?? today).add(const Duration(days: 1)),
      ),
    };
  }
}

/// Quanto um nome — servico ou cliente — rendeu no periodo.
class Tally {
  const new({
    required this.name,
    required this.count,
    required this.totalCents,
  });

  final String name;
  final int count;
  final int totalCents;
}

class CashReport {
  const new({
    required this.earnedCents,
    required this.expectedCents,
    required this.lostCents,
    required this.servedCount,
    required this.bookedCount,
    required this.noShowCount,
    required this.byService,
    required this.byClient,
    required this.byPayment,
    required this.entries,
  });

  /// So o que foi concluido. Horario marcado para daqui a uma hora nao e
  /// faturamento — e promessa.
  final int earnedCents;

  /// Marcado e ainda de pe no periodo. Aparece separado para o numero de cima
  /// nao mentir.
  final int expectedCents;

  final int lostCents;
  final int servedCount;
  final int bookedCount;
  final int noShowCount;
  final List<Tally> byService;
  final List<Tally> byClient;

  /// Quanto entrou em dinheiro, em Pix e no cartao. E com isto que o Marcos
  /// confere a maquininha no fim do dia.
  final List<Tally> byPayment;

  /// Os atendimentos que formam o total, do mais recente para o mais antigo.
  /// Numero sem lista nao da para conferir.
  final List<Appointment> entries;

  int get averageTicketCents =>
      servedCount == 0 ? 0 : earnedCents ~/ servedCount;

  bool get isEmpty => entries.isEmpty && expectedCents == 0;

  List<Tally> tallies(CashBreakdown breakdown) => switch (breakdown) {
    CashBreakdown.client => byClient,
    CashBreakdown.payment => byPayment,
    _ => byService,
  };
}

@riverpod
class CashFilterChoice extends _$CashFilterChoice {
  @override
  CashFilter build() => const CashFilter();

  void selectPeriod(CashPeriod period) => state = CashFilter(period: period);

  void selectRange(DateTimeRange range) =>
      state = CashFilter(period: CashPeriod.custom, range: range);
}

@riverpod
class CashBreakdownChoice extends _$CashBreakdownChoice {
  @override
  CashBreakdown build() => CashBreakdown.service;

  void select(CashBreakdown breakdown) => state = breakdown;
}

/// O que saiu no mesmo recorte de tempo.
///
/// Relatorio proprio, e nao um campo do outro: sao duas tabelas e dois fluxos,
/// e juntar os dois so para desmontar de novo na tela nao paga o preco de
/// combinar streams.
class SpentReport {
  const new({
    required this.totalCents,
    required this.byCategory,
    required this.expenses,
  });

  final int totalCents;
  final List<Tally> byCategory;

  /// Os lancamentos, do mais recente para o mais antigo.
  final List<Expense> expenses;

  bool get isEmpty => expenses.isEmpty;
}

@riverpod
class CashLaneChoice extends _$CashLaneChoice {
  @override
  CashLane build() => CashLane.earned;

  void select(CashLane lane) => state = lane;
}

@riverpod
Stream<SpentReport> spentReport(Ref ref) {
  final window = ref.watch(cashFilterChoiceProvider).resolve();

  return ref
      .watch(expenseRepositoryProvider)
      .watchRange(window.from, window.to)
      .map((expenses) {
        var total = 0;
        final byCategory = <String, Tally>{};

        for (final expense in expenses) {
          total += expense.cents;
          _add(byCategory, expense.category.name, expense.cents);
        }

        return SpentReport(
          totalCents: total,
          byCategory: _ranked(byCategory),
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
      .watchRange(window.from, window.to)
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
      .watchRange(window.from, window.to)
      .map((all) {
        var earned = 0;
        var expected = 0;
        var lost = 0;
        var served = 0;
        var booked = 0;
        var noShows = 0;
        final services = <String, Tally>{};
        final clients = <String, Tally>{};
        final payments = <String, Tally>{};
        final entries = <Appointment>[];

        for (final appointment in all) {
          final price = appointment.priceCents;

          switch (appointment.status) {
            case AppointmentStatus.done:
              earned += price;
              served++;
              entries.add(appointment);
              _add(services, appointment.service.name, price);
              _add(clients, appointment.client.name, price);
              // Concluido sem anotar tambem entra: escondido, o total do
              // detalhamento nao bateria com o numero de cima.
              _add(
                payments,
                appointment.paidWith?.label ?? 'Não anotado',
                price,
              );
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
          bookedCount: booked,
          noShowCount: noShows,
          byService: _ranked(services),
          byClient: _ranked(clients),
          byPayment: _ranked(payments),
          entries: entries.reversed.toList(growable: false),
        );
      });
}

void _add(Map<String, Tally> into, String name, int priceCents) {
  final soFar = into[name];
  into[name] = Tally(
    name: name,
    count: (soFar?.count ?? 0) + 1,
    totalCents: (soFar?.totalCents ?? 0) + priceCents,
  );
}

/// Maior primeiro: e de onde o dinheiro vem.
List<Tally> _ranked(Map<String, Tally> tallies) =>
    tallies.values.toList(growable: false)
      ..sort((a, b) => b.totalCents.compareTo(a.totalCents));
