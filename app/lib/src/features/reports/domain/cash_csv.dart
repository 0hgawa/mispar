import 'package:intl/intl.dart';
import 'package:mispar/src/features/agenda/domain/appointment.dart';
import 'package:mispar/src/features/reports/domain/expense.dart';

final _day = DateFormat('dd/MM/yyyy');

/// O periodo inteiro em uma planilha, entradas e saidas na mesma tabela.
///
/// E o que o contador pede: uma linha por movimento, com sinal. Ponto e
/// virgula separa os campos e a virgula fica no decimal — e assim que o Excel
/// em portugues abre o arquivo sem pedir nada.
String cashCsv({
  required List<Appointment> earned,
  required List<Expense> spent,
}) {
  final rows = <({DateTime on, String line})>[
    for (final appointment in earned)
      (
        on: appointment.startsAt,
        line: _row(
          on: appointment.startsAt,
          kind: 'Entrada',
          what: appointment.service.name,
          who: appointment.who,
          detail: appointment.paidWith?.label ?? '',
          cents: appointment.priceCents,
        ),
      ),
    for (final expense in spent)
      (
        on: expense.spentAt,
        line: _row(
          on: expense.spentAt,
          kind: 'Saída',
          what: expense.category.name,
          who: '',
          detail: expense.note ?? '',
          // Saida entra negativa: somar a coluna da o que sobrou.
          cents: -expense.cents,
        ),
      ),
  ]..sort((a, b) => a.on.compareTo(b.on));

  return [
    'Data;Tipo;O quê;Cliente;Detalhe;Valor',
    for (final row in rows) row.line,
  ].join('\n');
}

String _row({
  required DateTime on,
  required String kind,
  required String what,
  required String who,
  required String detail,
  required int cents,
}) {
  final value = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
  return [
    _day.format(on),
    kind,
    _escape(what),
    _escape(who),
    _escape(detail),
    value,
  ].join(';');
}

/// Anotacao com ponto e virgula quebraria a coluna seguinte.
String _escape(String text) {
  if (!text.contains(';') && !text.contains('"') && !text.contains('\n')) {
    return text;
  }
  return '"${text.replaceAll('"', '""')}"';
}
