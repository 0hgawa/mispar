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
    phone: json['phone'] as String,
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

  Future<void> updateStatus(String id, AppointmentStatus status) async {
    await _client
        .from('appointments')
        .update({'status': status.wireName})
        .eq('id', id);
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
