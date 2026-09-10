import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/data/database/app_database.dart';
import 'package:marcos_barber/src/core/data/remote/agenda_api.dart';

/// Traz o Postgres para dentro do SQLite.
///
/// A tela nunca fala com a rede: ela le o banco local, que o Drift reemite a
/// cada escrita. Este servico so empurra o que vem de fora para dentro — assim
/// a agenda abre igual com ou sem sinal, e o horario que o robo marcar aparece
/// sozinho.
class AgendaSync {
  new({required this._api, required this._database});

  /// Quanto do passado vale manter no celular.
  static const _historyWindow = Duration(days: 90);

  final AgendaApi _api;
  final AppDatabase _database;

  StreamSubscription<void>? _changes;

  /// Puxa tudo uma vez e passa a ouvir as mudancas.
  Future<void> start() async {
    await pull();
    _changes = _api.watchChanges().listen(
      (_) => unawaited(pull()),
      onError: (Object error) => debugPrint('sync interrompido: $error'),
    );
  }

  Future<void> dispose() async {
    await _changes?.cancel();
    _changes = null;
  }

  /// Uma passada completa. Falha de rede nao derruba nada: fica o que ja tinha.
  Future<void> pull() async {
    try {
      final since = DateTime.now().subtract(_historyWindow);
      final [services, clients, appointments] = await Future.wait([
        _api.fetchServices(),
        _api.fetchClients(),
        _api.fetchAppointments(since),
      ]);

      await _database.transaction(() async {
        await _database.batch((batch) {
          batch
            ..insertAllOnConflictUpdate(_database.services, [
              for (final service in services.cast<RemoteService>())
                ServicesCompanion.insert(
                  id: service.id,
                  name: service.name,
                  durationMinutes: service.durationMinutes,
                  priceCents: service.priceCents,
                  requiresDeposit: Value(service.requiresDeposit),
                ),
            ])
            ..insertAllOnConflictUpdate(_database.clients, [
              for (final client in clients.cast<RemoteClient>())
                ClientsCompanion.insert(
                  id: client.id,
                  name: client.name,
                  phone: client.phone,
                  note: Value(client.note),
                  createdAt: client.createdAt,
                ),
            ])
            // Sem payment_method de proposito: coluna ausente nao entra
            // no DO UPDATE, entao o que foi anotado no balcao sobrevive a
            // sincronia. Quem acrescentar o campo aqui tem que trazer o valor
            // do servidor junto, senao apaga o Pix que o Marcos registrou.
            ..insertAllOnConflictUpdate(_database.appointments, [
              for (final appointment in appointments.cast<RemoteAppointment>())
                AppointmentsCompanion.insert(
                  id: appointment.id,
                  clientId: appointment.clientId,
                  serviceId: appointment.serviceId,
                  startsAt: appointment.startsAt,
                  durationMinutes: appointment.durationMinutes,
                  priceCents: appointment.priceCents,
                  status: appointment.status.wireName,
                ),
            ]);
        });

        // Desmarcado no servidor tem que sumir do celular, nao so parar de
        // atualizar. Sem isto o horario cancelado ficaria preso na tela.
        final alive = appointments
            .cast<RemoteAppointment>()
            .map((a) => a.id)
            .toList(growable: false);

        await (_database.delete(_database.appointments)..where(
              (row) =>
                  row.startsAt.isBiggerOrEqualValue(since) &
                  row.id.isNotIn(alive),
            ))
            .go();
      });
    } on Object catch (error) {
      // Sem rede o app continua com o que ja tem. Nao e erro de tela.
      debugPrint('sync falhou: $error');
    }
  }
}

final agendaSyncProvider = Provider<AgendaSync>((ref) {
  final sync = AgendaSync(
    api: ref.watch(agendaApiProvider),
    database: ref.watch(appDatabaseProvider),
  );
  ref.onDispose(() => unawaited(sync.dispose()));
  return sync;
});
