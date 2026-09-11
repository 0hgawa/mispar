import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/data/database/app_database.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment_status.dart';
import 'package:marcos_barber/src/features/agenda/domain/payment_method.dart';
import 'package:marcos_barber/src/features/clients/domain/client.dart';
import 'package:marcos_barber/src/features/services/domain/catalogue_kind.dart';
import 'package:marcos_barber/src/features/services/domain/service.dart';

/// Unica fonte de verdade dos agendamentos.
///
/// Devolve `Stream` porque o Drift reemite sozinho quando a tabela muda: a tela
/// nunca precisa recarregar na mao.
class AgendaRepository {
  const new(this._db);

  final AppDatabase _db;

  Stream<List<Appointment>> watchDay(DateTime day) {
    final from = DateTime(day.year, day.month, day.day);
    return _watchRange(from, from.add(const Duration(days: 1)));
  }

  /// O intervalo cru. [includeSales] traz junto a venda de produto, que nao
  /// e atendimento: ela nao ocupa horario e por isso nao aparece na agenda,
  /// mas e dinheiro que entrou e por isso conta no Caixa.
  Stream<List<Appointment>> watchRange(
    DateTime from,
    DateTime to, {
    bool includeSales = false,
  }) => _watchRange(from, to, includeSales: includeSales);

  /// Grava um atendimento que nao passou pela agenda.
  ///
  /// Ja nasce concluido, porque so se lanca o que ja aconteceu, e o preco vem
  /// digitado e nao da tabela: quem chega sem marcar costuma pagar outro
  /// valor. Sem cliente quando ninguem foi escolhido.
  Future<void> lance({
    required String id,
    required Service service,
    required DateTime at,
    required int priceCents,
    required PaymentMethod paidWith,
    String? clientId,
  }) {
    return _db
        .into(_db.appointments)
        .insert(
          AppointmentsCompanion.insert(
            id: id,
            clientId: Value(clientId),
            serviceId: service.id,
            startsAt: at,
            durationMinutes: service.duration.inMinutes,
            priceCents: priceCents,
            status: AppointmentStatus.done.wireName,
            paymentMethod: Value(paidWith.name),
          ),
        );
  }

  /// Grava um horario novo.
  ///
  /// Duracao e preco sao copiados do servico agora, de proposito: se o Marcos
  /// subir o preco amanha, o que ja foi combinado continua valendo.
  Future<void> create({
    required String id,
    required String clientId,
    required Service service,
    required DateTime startsAt,
  }) {
    return _db
        .into(_db.appointments)
        .insert(
          AppointmentsCompanion.insert(
            id: id,
            clientId: Value(clientId),
            serviceId: service.id,
            startsAt: startsAt,
            durationMinutes: service.duration.inMinutes,
            priceCents: service.priceCents,
            // Marcado pelo Marcos ja nasce confirmado: a pessoa esta na frente
            // dele ou falou com ele.
            status: AppointmentStatus.confirmed.wireName,
          ),
        );
  }

  /// Move um horario ja marcado. O preco tambem e reescrito: se o servico
  /// mudou, o que vale e o combinado agora.
  Future<void> reschedule({
    required String id,
    required Service service,
    required DateTime startsAt,
  }) {
    return (_db.update(_db.appointments)..where((a) => a.id.equals(id))).write(
      AppointmentsCompanion(
        serviceId: Value(service.id),
        startsAt: Value(startsAt),
        durationMinutes: Value(service.duration.inMinutes),
        priceCents: Value(service.priceCents),
      ),
    );
  }

  /// Fecha, reabre ou marca falta.
  ///
  /// A forma de pagamento so faz sentido em atendimento concluido: reabrir
  /// limpa o que estava anotado, senao o Caixa contaria um Pix que nao houve.
  Future<void> updateStatus(
    String id,
    AppointmentStatus status, {
    PaymentMethod? paidWith,
  }) {
    return (_db.update(_db.appointments)..where((a) => a.id.equals(id))).write(
      AppointmentsCompanion(
        status: Value(status.wireName),
        paymentMethod: Value(
          status == AppointmentStatus.done ? paidWith?.name : null,
        ),
      ),
    );
  }

  Stream<List<Appointment>> _watchRange(
    DateTime from,
    DateTime to, {
    bool includeSales = false,
  }) {
    final query =
        _db.select(_db.appointments).join([
            // A esquerda: sem isto, o que foi lancado sem cliente sumiria da
            // agenda e do caixa.
            leftOuterJoin(
              _db.clients,
              _db.clients.id.equalsExp(_db.appointments.clientId),
            ),
            innerJoin(
              _db.services,
              _db.services.id.equalsExp(_db.appointments.serviceId),
            ),
          ])
          ..where(
            _db.appointments.startsAt.isBiggerOrEqualValue(from) &
                _db.appointments.startsAt.isSmallerThanValue(to) &
                _db.appointments.status.isNotValue(
                  AppointmentStatus.cancelled.wireName,
                ) &
                (includeSales
                    ? const Constant(true)
                    : _db.services.kind.equals(CatalogueKind.service.name)),
          )
          ..orderBy([OrderingTerm.asc(_db.appointments.startsAt)]);

    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  Appointment _toDomain(TypedResult row) {
    final appointment = row.readTable(_db.appointments);
    final client = row.readTableOrNull(_db.clients);
    final service = row.readTable(_db.services);

    return Appointment(
      id: appointment.id,
      startsAt: appointment.startsAt,
      status: AppointmentStatus.fromWire(appointment.status),
      duration: Duration(minutes: appointment.durationMinutes),
      priceCents: appointment.priceCents,
      paidWith: PaymentMethod.parse(appointment.paymentMethod),
      client: client == null
          ? null
          : Client(
              id: client.id,
              name: client.name,
              phone: client.phone,
              note: client.note,
            ),
      service: Service(
        id: service.id,
        name: service.name,
        duration: Duration(minutes: service.durationMinutes),
        priceCents: service.priceCents,
        requiresDeposit: service.requiresDeposit,
        // Sem isto toda venda volta do banco parecendo serviço, e o Caixa
        // conta pomada como atendimento.
        kind: CatalogueKind.fromWire(service.kind),
      ),
    );
  }
}

final agendaRepositoryProvider = Provider<AgendaRepository>(
  (ref) => AgendaRepository(ref.watch(appDatabaseProvider)),
);
