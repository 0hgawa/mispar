import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mispar/src/core/data/database/app_database.dart';
import 'package:mispar/src/core/data/remote/agenda_api.dart';
import 'package:mispar/src/shared/formatters/phone.dart';

/// A ponte entre o SQLite do aparelho e o Postgres.
///
/// A tela nunca fala com a rede: ela le o banco local, que o Drift reemite a
/// cada escrita. Assim a agenda abre igual com ou sem sinal, e o horario que o
/// robo marcar aparece sozinho.
///
/// **Desce e sobe, nessa ordem.** Primeiro o que o robo escreveu chega no
/// aparelho; depois o aparelho manda tudo de volta. A ordem importa: ao
/// contrario, uma passada sobreporia com dado velho o horario que o robo
/// acabou de marcar.
///
/// **A subida e espelho, e nao fila.** Manda o banco inteiro a cada passada,
/// criando ou sobrescrevendo pelo id. Parece desperdicio e nao e: a barbearia
/// inteira cabe em dezenas de quilobytes, e manter uma fila de mudancas
/// correta custa mais — fila que perde um evento fica errada para sempre, e
/// ninguem descobre ate precisar do backup.
class AgendaSync {
  new({required this._api, required this._database});

  /// Quanto do passado vale manter no celular.
  static const _historyWindow = Duration(days: 90);

  final AgendaApi _api;
  final AppDatabase _database;

  StreamSubscription<void>? _changes;

  Timer? _relogio;

  /// De quanto em quanto tempo a copia sobe.
  ///
  /// Relogio, e nao gatilho por escrita. O gatilho parecia mais esperto e se
  /// mordia: a descida escreve no banco local, a escrita dispara o gatilho, o
  /// gatilho pede outra passada — e o aparelho ficava subindo o mesmo banco a
  /// cada dois segundos, sem nada ter mudado.
  ///
  /// Um minuto e de sobra para o que isto e: uma copia de seguranca. Perder um
  /// minuto de agenda num celular que caiu na privada nao muda a vida de
  /// ninguem; queimar bateria o dia inteiro, muda.
  static const _intervalo = Duration(minutes: 1);

  /// Uma passada por vez. Duas ao mesmo tempo mandariam o mesmo banco duas
  /// vezes, e a segunda so faria o servidor trabalhar a toa.
  bool _correndo = false;

  /// Uma passada agora, e depois a cada mudanca dos dois lados.
  Future<void> start() async {
    await sync();

    _changes = _api.watchChanges().listen(
      (_) => unawaited(sync()),
      onError: (Object error) => debugPrint('sync interrompido: $error'),
    );

    // E de minuto em minuto, para o que o Marcos escreveu no balcao chegar
    // no servidor sem ele fazer nada.
    _relogio = Timer.periodic(_intervalo, (_) => unawaited(sync()));
  }

  Future<void> dispose() async {
    _relogio?.cancel();
    _relogio = null;
    await _changes?.cancel();
    _changes = null;
  }

  /// Desce o que veio de fora e sobe o que e daqui.
  Future<void> sync() async {
    if (_correndo) return;
    _correndo = true;

    try {
      await pull();
      await _baixarApagados();
      await push();
      await _subirApagados();
    } finally {
      _correndo = false;
    }
  }

  /// Apaga aqui o que foi apagado la.
  ///
  /// Pelo livro dos apagados, e nunca por ausencia: o celular so guarda
  /// noventa dias de agenda, entao "o servidor tem e eu nao" quase sempre quer
  /// dizer "e mais velho que a minha janela".
  Future<void> _baixarApagados() async {
    try {
      final marca = await _marca();
      final apagados = await _api.fetchDeletions(marca);
      if (apagados.isEmpty) return;

      await _database.transaction(() async {
        for (final lapide in apagados) {
          await _apagarLocal(lapide.table, lapide.id);
        }
      });

      // A marca e o carimbo da ultima lapide processada. Se a proxima passada
      // falhar no meio, ela recomeca daqui e nao perde nada.
      final ultima = apagados
          .map((l) => l.at)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      await _guardarMarca(ultima);
    } on Object catch (error) {
      debugPrint('descida de apagados falhou: $error');
    }
  }

  /// Manda para o servidor o que foi apagado aqui, e so entao risca a lapide.
  ///
  /// A ordem importa: riscar antes de o servidor confirmar perderia a noticia
  /// numa queda de rede, e o cliente apagado voltaria na proxima descida.
  Future<void> _subirApagados() async {
    try {
      final lapides = await _database.select(_database.deletedRows).get();
      if (lapides.isEmpty) return;

      final porTabela = <String, List<String>>{};
      for (final lapide in lapides) {
        (porTabela[lapide.sourceTable] ??= []).add(lapide.rowId);
      }

      for (final entrada in porTabela.entries) {
        await _api.deleteRows(entrada.key, entrada.value);
      }

      await _database.delete(_database.deletedRows).go();
    } on Object catch (error) {
      debugPrint('subida de apagados falhou: $error');
    }
  }

  /// Apaga a linha sem deixar lapide: ela ja veio de uma.
  ///
  /// Sem isto o aparelho anotaria a propria exclusao e a devolveria ao
  /// servidor na passada seguinte — ruido de ida e volta para sempre.
  Future<void> _apagarLocal(String tabela, String id) async {
    await customStatement('drop trigger if exists ${tabela}_tombstone');
    try {
      await customStatement('delete from $tabela where id = ?', [id]);
    } finally {
      await _tombstoneTrigger(tabela);
    }
  }

  Future<DateTime?> _marca() async {
    final linha = await (_database.select(
      _database.syncState,
    )..where((s) => s.id.equals(1))).getSingleOrNull();
    return linha?.lastPulledAt;
  }

  Future<void> _guardarMarca(DateTime quando) async {
    await _database
        .into(_database.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion.insert(
            id: const Value(1),
            lastPulledAt: Value(quando),
          ),
        );
  }

  Future<void> customStatement(String sql, [List<Object?>? args]) =>
      _database.customStatement(sql, args);

  Future<void> _tombstoneTrigger(String tabela) => customStatement('''
    create trigger if not exists ${tabela}_tombstone
    after delete on $tabela
    begin
      insert or replace into deleted_rows (table_name, row_id, deleted_at)
      values ('$tabela', old.id, strftime('%s', 'now'));
    end;
  ''');

  /// Manda o banco do aparelho para o servidor.
  ///
  /// Ordem de dependencia: servico e tipo de despesa antes do que aponta para
  /// eles, cliente antes do horario. O Postgres tem chave estrangeira de
  /// verdade, e fora de ordem ele recusa.
  ///
  /// Falha de rede nao derruba nada — a proxima passada manda tudo de novo,
  /// porque e espelho e nao fila.
  Future<void> push() async {
    try {
      await _api.pushRows('services', [
        for (final row in await _database.select(_database.services).get())
          {
            'id': row.id,
            'name': row.name,
            'duration_minutes': row.durationMinutes,
            'price_cents': row.priceCents,
            'requires_deposit': row.requiresDeposit,
            'active': row.active,
            'kind': row.kind,
          },
      ]);

      await _api.pushRows('expense_categories', [
        for (final row
            in await _database.select(_database.expenseCategories).get())
          {'id': row.id, 'name': row.name, 'active': row.active},
      ]);

      await _api.pushRows('clients', [
        for (final row in await _database.select(_database.clients).get())
          {
            'id': row.id,
            'name': row.name,
            // No formato internacional, que e como o robo acha a pessoa no
            // WhatsApp. Nulo quando nao ha numero ou o que foi digitado nao da
            // um telefone — o servidor recusaria a linha, e com ela a lista
            // inteira de clientes.
            'phone': phoneWire(row.phone),
            'note': row.note,
            'created_at': row.createdAt.toUtc().toIso8601String(),
            'active': row.active,
          },
      ]);

      await _api.pushRows('shop_hours', [
        for (final row in await _database.select(_database.shopHours).get())
          {
            'weekday': row.weekday,
            'is_open': row.isOpen,
            'opens_at': _hora(row.opensMinutes),
            'closes_at': _hora(row.closesMinutes),
            'lunch_start': _hora(row.lunchStartMinutes),
            'lunch_end': _hora(row.lunchEndMinutes),
          },
      ]);

      await _api.pushRows('time_blocks', [
        for (final row in await _database.select(_database.timeBlocks).get())
          {
            'id': row.id,
            'starts_at': row.startsAt.toUtc().toIso8601String(),
            'ends_at': row.endsAt.toUtc().toIso8601String(),
            'reason': row.reason,
          },
      ]);

      await _api.pushRows('appointments', [
        for (final row in await _database.select(_database.appointments).get())
          {
            'id': row.id,
            'client_id': row.clientId,
            'service_id': row.serviceId,
            'starts_at': row.startsAt.toUtc().toIso8601String(),
            'duration_minutes': row.durationMinutes,
            'price_cents': row.priceCents,
            'status': row.status,
            'payment_method': row.paymentMethod,
            'walk_in': row.walkIn,
          },
      ]);

      // Os ajustes sao uma linha so, travada no id 1 dos dois lados.
      await _api.pushRows('shop_settings', [
        for (final row in await _database.select(_database.shopSettings).get())
          {
            'id': row.id,
            'slot_step_minutes': row.slotStepMinutes,
            'reminder_enabled': row.reminderEnabled,
            'reminder_hours_before': row.reminderHoursBefore,
            'drifted_enabled': row.driftedEnabled,
            'drifted_days': row.driftedDays,
            'accepted_payments': row.acceptedPayments,
            'shop_name': row.shopName,
            'shop_address': row.shopAddress,
            'shop_instagram': row.shopInstagram,
          },
      ]);

      await _api.pushRows('expenses', [
        for (final row in await _database.select(_database.expenses).get())
          {
            'id': row.id,
            'spent_at': row.spentAt.toUtc().toIso8601String(),
            'category': row.categoryId,
            'cents': row.cents,
            'note': row.note,
            'repeats_monthly': row.repeatsMonthly,
            'series_id': row.seriesId,
          },
      ]);
    } on Object catch (error) {
      // Sem rede, ou linha que o servidor recusou. Fica para a proxima.
      debugPrint('subida falhou: $error');
    }
  }

  /// Dois jeitos de escrever o mesmo telefone.
  static bool _mesmoNumero(String? aqui, String la) =>
      aqui != null && aqui.isNotEmpty && phoneKey(aqui) == phoneKey(la);

  /// Minutos desde a meia-noite viram "HH:MM", que e `time` no Postgres.
  static String? _hora(int? minutes) {
    if (minutes == null) return null;
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
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

      // Como cada telefone esta escrito aqui, para a descida nao reescrever.
      //
      // A subida manda em formato internacional, porque e assim que o robo
      // acha a pessoa no WhatsApp. Se a descida trouxesse isso de volta, o
      // "11 99640-2210" que o Marcos digitou virava "+5511996402210" na tela —
      // o mesmo numero, escrito de um jeito que ele nao escolheu.
      final comoEstaAqui = {
        for (final linha in await _database.select(_database.clients).get())
          linha.id: linha.phone,
      };

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
                  // O mesmo numero mantem a escrita daqui; numero diferente
                  // veio do robo e vale.
                  phone: _mesmoNumero(comoEstaAqui[client.id], client.phone)
                      ? comoEstaAqui[client.id]!
                      : client.phone,
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
                  clientId: Value(appointment.clientId),
                  serviceId: appointment.serviceId,
                  startsAt: appointment.startsAt,
                  durationMinutes: appointment.durationMinutes,
                  priceCents: appointment.priceCents,
                  status: appointment.status.wireName,
                ),
            ]);
        });
      });

      // A passada **nao apaga** o que o servidor nao tem.
      //
      // Ate 12/09/2026 ela apagava: tudo dentro da janela que nao viesse na
      // resposta sumia do celular. A conta so fecha se o aparelho ja tiver
      // mandado tudo para cima — e ele nunca mandou, porque a subida ainda
      // nao existe. Ligado o backend num projeto novo e vazio, a primeira
      // passada limpou a agenda do aparelho. Aconteceu de verdade, aqui, com
      // um horario de teste; com a agenda de uma semana teria sido o mesmo.
      //
      // Ausencia nao e noticia. O que sumiu de verdade vai chegar pelo livro
      // dos apagados (`deleted_rows`, migration 0011), que diz **qual** id
      // morreu e quando — e ai da para apagar sem adivinhar.
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
