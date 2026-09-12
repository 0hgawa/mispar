import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mispar/src/core/data/database/app_database.dart';
import 'package:mispar/src/features/agenda/domain/appointment_status.dart';
import 'package:mispar/src/features/clients/domain/client.dart';
import 'package:mispar/src/features/clients/domain/client_summary.dart';
import 'package:mispar/src/shared/formatters/phone.dart';
import 'package:mispar/src/shared/formatters/text.dart';

class ClientRepository {
  const new(this._db);

  final AppDatabase _db;

  /// Cada cliente com o resumo do que ja gastou e do que costuma pedir.
  ///
  /// A juncao devolve uma linha por atendimento; a soma acontece aqui em Dart.
  /// Na escala de uma barbearia isso e uma lista curta, e vale muito mais que
  /// espalhar `GROUP BY` por tres consultas.
  Stream<List<ClientSummary>> watchSummaries() {
    final query = _db.select(_db.clients).join([
      leftOuterJoin(
        _db.appointments,
        _db.appointments.clientId.equalsExp(_db.clients.id),
      ),
      leftOuterJoin(
        _db.services,
        _db.services.id.equalsExp(_db.appointments.serviceId),
      ),
    ]);

    return query.watch().map(_summarize);
  }

  Stream<ClientSummary?> watchSummary(String clientId) => watchSummaries().map(
    (all) => all.where((s) => s.client.id == clientId).firstOrNull,
  );

  /// Os atendimentos de um cliente, do mais recente para o mais antigo.
  Stream<List<ClientVisit>> watchVisits(String clientId) {
    final query =
        _db.select(_db.appointments).join([
            innerJoin(
              _db.services,
              _db.services.id.equalsExp(_db.appointments.serviceId),
            ),
          ])
          ..where(_db.appointments.clientId.equals(clientId))
          ..orderBy([OrderingTerm.desc(_db.appointments.startsAt)]);

    return query.watch().map(
      (rows) => rows
          .map((row) {
            final appointment = row.readTable(_db.appointments);
            return ClientVisit(
              id: appointment.id,
              startsAt: appointment.startsAt,
              serviceName: row.readTable(_db.services).name,
              priceCents: appointment.priceCents,
              status: AppointmentStatus.fromWire(appointment.status),
            );
          })
          .toList(growable: false),
    );
  }

  /// Procura quem ja pode ser esta pessoa.
  ///
  /// Telefone e nome pesam diferente: **numero e identidade** — dois donos do
  /// mesmo numero nao existem —, mas dois "Joao Silva" existem, e barrar por
  /// nome impediria um cadastro legitimo. Por isso um so bloqueia e o outro so
  /// avisa.
  ///
  /// Uma consulta so, os dois responde de uma vez: numa barbearia a tabela de
  /// clientes cabe na memoria com folga.
  Future<({Client? samePhone, Client? sameName})> findExisting({
    required String name,
    required String phone,
    String? ignoring,
  }) async {
    final wanted = normalizeForSearch(name.trim());
    final digits = digitsOf(phone);
    final rows = await _db.select(_db.clients).get();

    ClientRow? samePhone;
    ClientRow? sameName;

    for (final row in rows) {
      if (row.id == ignoring) continue;
      if (digits.isNotEmpty && digitsOf(row.phone) == digits) {
        samePhone ??= row;
      }
      if (normalizeForSearch(row.name) == wanted) sameName ??= row;
    }

    return (samePhone: _toClient(samePhone), sameName: _toClient(sameName));
  }

  Client? _toClient(ClientRow? row) => row == null
      ? null
      : Client(
          id: row.id,
          name: row.name,
          phone: row.phone,
          note: row.note,
          isActive: row.active,
        );

  /// Os telefones ja cadastrados, em forma de chave.
  ///
  /// Consulta so a coluna do telefone: para saber o que ja existe nao e
  /// preciso carregar nome, anotacao e data de cada cliente.
  Future<Set<String>> phoneKeys() async {
    final column = _db.clients.phone;
    final rows = await (_db.selectOnly(
      _db.clients,
    )..addColumns([column])).get();

    return {
      for (final row in rows)
        if (row.read(column) case final phone?) phoneKey(phone),
    };
  }

  /// Grava varios clientes de uma vez.
  ///
  /// Uma transacao so para a agenda inteira: mil inserts separados travariam
  /// a tela por segundos.
  Future<void> importAll(
    Iterable<({String id, String name, String phone})> people,
  ) {
    final now = DateTime.now();

    return _db.batch(
      (batch) => batch.insertAll(_db.clients, [
        for (final person in people)
          ClientsCompanion.insert(
            id: person.id,
            name: person.name,
            phone: person.phone,
            createdAt: now,
          ),
      ]),
    );
  }

  /// Cadastra alguem que chegou sem marcar.
  Future<void> create({
    required String id,
    required String name,
    required String phone,
  }) {
    return _db
        .into(_db.clients)
        .insert(
          ClientsCompanion.insert(
            id: id,
            name: name.trim(),
            phone: phone.trim(),
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Corrige a anotacao do cliente. Nulo apaga.
  Future<void> saveNote(String clientId, String? note) {
    final trimmed = note?.trim();
    return (_db.update(_db.clients)..where((c) => c.id.equals(clientId))).write(
      ClientsCompanion(
        note: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
      ),
    );
  }

  /// Tira ou devolve o cliente a lista de quem aparece ao marcar.
  Future<void> setActive(String clientId, {required bool isActive}) {
    return (_db.update(_db.clients)..where((c) => c.id.equals(clientId))).write(
      ClientsCompanion(active: Value(isActive)),
    );
  }

  /// Apaga de vez. So chame para quem nunca teve atendimento — erro de
  /// digitacao, cadastro repetido.
  ///
  /// Com atendimento atrelado o banco recusa, e e bom que recuse: aquele
  /// atendimento sumiria da agenda e do Caixa, porque a consulta junta pelo
  /// cliente para pegar o nome.
  Future<void> delete(String clientId) =>
      (_db.delete(_db.clients)..where((c) => c.id.equals(clientId))).go();

  Future<void> saveName(String clientId, String name) {
    return (_db.update(_db.clients)..where((c) => c.id.equals(clientId))).write(
      ClientsCompanion(name: Value(name.trim())),
    );
  }

  List<ClientSummary> _summarize(List<TypedResult> rows) {
    final clients = <String, ClientRow>{};
    final counts = <String, int>{};
    final spent = <String, int>{};
    final last = <String, DateTime>{};
    final services = <String, Map<String, int>>{};

    for (final row in rows) {
      final client = row.readTable(_db.clients);
      clients[client.id] = client;

      final appointment = row.readTableOrNull(_db.appointments);
      if (appointment == null) continue;

      // So conta o que virou dinheiro de verdade. Horario marcado para daqui a
      // uma hora ainda nao e visita, e somar isso faria o "ja gastou" mentir.
      final status = AppointmentStatus.fromWire(appointment.status);
      if (status != AppointmentStatus.done) continue;

      counts[client.id] = (counts[client.id] ?? 0) + 1;
      spent[client.id] = (spent[client.id] ?? 0) + appointment.priceCents;

      final previous = last[client.id];
      if (previous == null || appointment.startsAt.isAfter(previous)) {
        last[client.id] = appointment.startsAt;
      }

      final service = row.readTableOrNull(_db.services);
      if (service != null) {
        final tally = services.putIfAbsent(client.id, () => <String, int>{});
        tally[service.name] = (tally[service.name] ?? 0) + 1;
      }
    }

    final summaries = [
      for (final client in clients.values)
        ClientSummary(
          client: Client(
            id: client.id,
            name: client.name,
            phone: client.phone,
            note: client.note,
            isActive: client.active,
          ),
          visitCount: counts[client.id] ?? 0,
          spentCents: spent[client.id] ?? 0,
          lastVisit: last[client.id],
          usualService: _mostFrequent(services[client.id]),
        ),
    ]..sort((a, b) => a.client.name.compareTo(b.client.name));

    return summaries;
  }

  String? _mostFrequent(Map<String, int>? tally) {
    if (tally == null || tally.isEmpty) return null;
    var best = tally.entries.first;
    for (final entry in tally.entries) {
      if (entry.value > best.value) best = entry;
    }
    return best.key;
  }
}

/// Um atendimento na ficha do cliente.
class ClientVisit {
  const new({
    required this.id,
    required this.startsAt,
    required this.serviceName,
    required this.priceCents,
    required this.status,
  });

  final String id;
  final DateTime startsAt;
  final String serviceName;
  final int priceCents;
  final AppointmentStatus status;
}

final clientRepositoryProvider = Provider<ClientRepository>(
  (ref) => ClientRepository(ref.watch(appDatabaseProvider)),
);
