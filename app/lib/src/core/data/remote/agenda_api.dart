import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mispar/src/features/agenda/domain/appointment_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Linha crua do Postgres, antes de virar tabela local.
///
/// Existe para o [AgendaApi] nao devolver `Map` solto por ai: quem consome sabe
/// exatamente o que chegou.
class RemoteAppointment {
  const new({
    required this.id,
    required this.clientId,
    required this.serviceId,
    required this.startsAt,
    required this.durationMinutes,
    required this.priceCents,
    required this.status,
  });

  factory fromJson(Map<String, dynamic> json) => RemoteAppointment(
    id: json['id'] as String,
    clientId: json['client_id'] as String,
    serviceId: json['service_id'] as String,
    startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
    durationMinutes: json['duration_minutes'] as int,
    priceCents: json['price_cents'] as int,
    status: AppointmentStatus.fromWire(json['status'] as String),
  );

  final String id;
  final String clientId;
  final String serviceId;
  final DateTime startsAt;
  final int durationMinutes;
  final int priceCents;
  final AppointmentStatus status;
}

class RemoteClient {
  const new({
    required this.id,
    required this.name,
    required this.phone,
    required this.createdAt,
    this.note,
  });

  factory fromJson(Map<String, dynamic> json) => RemoteClient(
    id: json['id'] as String,
    name: json['name'] as String,
    // Vazio, e nao nulo: no aparelho a coluna nao aceita nulo, e '' e como
    // a tela ja mostra "sem telefone". O servidor guarda nulo porque la o
    // telefone e unico e dois vazios colidiriam.
    phone: json['phone'] as String? ?? '',
    note: json['note'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  final String id;
  final String name;
  final String phone;
  final String? note;
  final DateTime createdAt;
}

class RemoteService {
  const new({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.priceCents,
    required this.requiresDeposit,
  });

  factory fromJson(Map<String, dynamic> json) => RemoteService(
    id: json['id'] as String,
    name: json['name'] as String,
    durationMinutes: json['duration_minutes'] as int,
    priceCents: json['price_cents'] as int,
    requiresDeposit: json['requires_deposit'] as bool,
  );

  final String id;
  final String name;
  final int durationMinutes;
  final int priceCents;
  final bool requiresDeposit;
}

/// Fala com o Postgres do Supabase. Nao conhece o banco local nem a tela.
/// Uma lápide do servidor: o que sumiu, de onde, e quando.
class RemoteDeletion {
  const new({required this.table, required this.id, required this.at});

  final String table;
  final String id;
  final DateTime at;
}

class AgendaApi {
  const new(this._client);

  final SupabaseClient _client;

  Future<List<RemoteService>> fetchServices() async {
    final rows = await _client.from('services').select();
    return rows.map(RemoteService.fromJson).toList(growable: false);
  }

  Future<List<RemoteClient>> fetchClients() async {
    final rows = await _client.from('clients').select();
    return rows.map(RemoteClient.fromJson).toList(growable: false);
  }

  /// Agendamentos de [from] em diante.
  ///
  /// Nao traz o passado inteiro: o celular do Marcos nao precisa carregar dois
  /// anos de corte para mostrar a semana.
  Future<List<RemoteAppointment>> fetchAppointments(DateTime from) async {
    final rows = await _client
        .from('appointments')
        .select()
        .gte('starts_at', from.toUtc().toIso8601String());
    return rows.map(RemoteAppointment.fromJson).toList(growable: false);
  }

  /// Manda as linhas para o servidor, criando ou sobrescrevendo pelo id.
  ///
  /// Espelho, e nao fila de eventos. O banco inteiro da barbearia cabe em
  /// dezenas de quilobytes: subir tudo a cada passada custa menos que manter
  /// uma fila de mudancas correta, e nao tem o defeito dela — fila que perde
  /// um evento fica errada para sempre, e ninguem descobre.
  ///
  /// `upsert` e nao `insert`: a passada e idempotente, entao rede que cai no
  /// meio so faz repetir, nunca duplicar.
  Future<void> pushRows(String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from(table).upsert(rows);
  }

  /// Apaga no servidor o que foi apagado no aparelho.
  ///
  /// Por id, e nunca por ausencia: o celular so guarda noventa dias de agenda,
  /// entao "o servidor tem e eu nao" quer dizer "e mais antigo que a minha
  /// janela" muito mais vezes do que quer dizer "foi apagado".
  Future<void> deleteRows(String table, List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from(table).delete().inFilter('id', ids);
  }

  /// O que foi apagado no servidor depois de [since].
  ///
  /// Traz a data junto de propósito: é dela que sai a marca da próxima
  /// passada. Nada de perguntar a hora ao servidor nem confiar no relógio do
  /// aparelho — a marca é o carimbo da última lápide que a gente **de fato**
  /// processou, e não um instante que alguém achou que era agora.
  ///
  /// Sem [since] traz o livro inteiro, que é o que um aparelho novo precisa.
  Future<List<RemoteDeletion>> fetchDeletions(DateTime? since) async {
    var query = _client.from('deleted_rows').select();
    if (since != null) {
      query = query.gt('deleted_at', since.toUtc().toIso8601String());
    }

    final rows = await query;
    return [
      for (final row in rows)
        RemoteDeletion(
          table: row['table_name'] as String,
          id: row['row_id'] as String,
          at: DateTime.parse(row['deleted_at'] as String).toLocal(),
        ),
    ];
  }

  /// Avisa a cada mudanca na tabela de agendamentos.
  ///
  /// E o que faz o horario marcado pelo robo aparecer na tela do Marcos sem ele
  /// puxar para atualizar.
  Stream<void> watchChanges() =>
      _client.from('appointments').stream(primaryKey: ['id']).map((_) {});
}

final agendaApiProvider = Provider<AgendaApi>(
  (ref) => AgendaApi(Supabase.instance.client),
);
