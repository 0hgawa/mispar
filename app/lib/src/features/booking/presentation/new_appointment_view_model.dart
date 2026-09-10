import 'package:marcos_barber/src/features/agenda/data/agenda_repository.dart';
import 'package:marcos_barber/src/features/agenda/data/shop_hours_repository.dart';
import 'package:marcos_barber/src/features/agenda/data/shop_settings_repository.dart';
import 'package:marcos_barber/src/features/agenda/domain/day_schedule.dart';
import 'package:marcos_barber/src/features/agenda/domain/shop_hours.dart';
import 'package:marcos_barber/src/features/agenda/domain/time_block.dart';
import 'package:marcos_barber/src/features/agenda/presentation/day_view_model.dart';
import 'package:marcos_barber/src/features/clients/data/client_repository.dart';
import 'package:marcos_barber/src/features/clients/domain/client.dart';
import 'package:marcos_barber/src/features/services/data/service_repository.dart';
import 'package:marcos_barber/src/features/services/domain/service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'new_appointment_view_model.g.dart';

/// Quem vai sentar na cadeira: alguem ja cadastrado ou um nome novo.
sealed class BookingClient {
  const new();
}

class ExistingClient extends BookingClient {
  const new(this.client);

  final Client client;
}

class NewClient extends BookingClient {
  const new({required this.name, required this.phone});

  final String name;
  final String phone;

  bool get isValid => name.trim().length >= 2;
}

/// O que ja foi escolhido no formulario.
class BookingDraft {
  const new({
    required this.day,
    this.client,
    this.service,
    this.startsAt,
    this.editingId,
    this.preferredStart,
  });

  /// O dia aberto no formulario. Comeca no dia da agenda e anda sozinho a
  /// partir dai, sem mexer no que esta por tras.
  final DateTime day;
  final BookingClient? client;
  final Service? service;
  final DateTime? startsAt;

  /// Preenchido quando esta remarcando um horario que ja existe.
  final String? editingId;

  /// A hora que o Marcos ja escolheu ao tocar numa vaga na agenda.
  ///
  /// Quando existe, o formulario nao pergunta o dia de novo e ja marca esse
  /// horario assim que o servico couber nele.
  final DateTime? preferredStart;

  /// Veio de uma vaga da agenda, e nao do botao de marcar.
  bool get cameFromSlot => preferredStart != null;

  bool get isEditing => editingId != null;

  bool get isComplete =>
      client != null &&
      service != null &&
      startsAt != null &&
      (client is! NewClient || (client! as NewClient).isValid);

  BookingDraft copyWith({
    DateTime? day,
    BookingClient? client,
    Service? service,
    DateTime? startsAt,
    String? editingId,
    DateTime? preferredStart,
    bool clearStartsAt = false,
    bool clearPreferred = false,
  }) => BookingDraft(
    day: day ?? this.day,
    client: client ?? this.client,
    service: service ?? this.service,
    startsAt: clearStartsAt ? null : (startsAt ?? this.startsAt),
    editingId: editingId ?? this.editingId,
    preferredStart: clearPreferred
        ? null
        : (preferredStart ?? this.preferredStart),
  );
}

/// O rascunho do horario que esta sendo marcado.
///
/// Vive alem da tela de proposito. Quem abre o formulario preenche o rascunho
/// **antes** de navegar; se o provedor morresse junto com a tela anterior, a
/// data escolhida na agenda se perderia no caminho e o formulario abriria
/// sempre em hoje. Cada porta de entrada — [startOnDay], [startAtSlot],
/// [startEditing] — troca o rascunho inteiro, entao nao sobra nada da vez
/// passada.
@Riverpod(keepAlive: true)
class Booking extends _$Booking {
  @override
  BookingDraft build() {
    final now = DateTime.now();
    return BookingDraft(day: DateTime(now.year, now.month, now.day));
  }

  /// Abre o formulario num dia: e o botao redondo da agenda, que marca no dia
  /// que esta na tela.
  void startOnDay(DateTime day) =>
      state = BookingDraft(day: DateTime(day.year, day.month, day.day));

  /// Abre o formulario ja preenchido, para remarcar.
  void startEditing({
    required String appointmentId,
    required Client client,
    required Service service,
    required DateTime startsAt,
  }) {
    state = BookingDraft(
      day: DateTime(startsAt.year, startsAt.month, startsAt.day),
      client: ExistingClient(client),
      service: service,
      startsAt: startsAt,
      editingId: appointmentId,
    );
  }

  /// Abre o formulario a partir de uma vaga da agenda: dia e hora ja vem
  /// escolhidos, e so falta quem e o que.
  void startAtSlot(DateTime start) {
    state = BookingDraft(
      day: DateTime(start.year, start.month, start.day),
      preferredStart: start,
    );
  }

  /// Trocar de dia derruba o horario e a preferencia: o que estava livre ontem
  /// nao diz nada sobre amanha.
  void chooseDay(DateTime day) => state = state.copyWith(
    day: day,
    clearStartsAt: true,
    clearPreferred: true,
  );

  void chooseClient(BookingClient client) =>
      state = state.copyWith(client: client);

  /// Trocar de servico muda a duracao, e o horario escolhido pode nao caber
  /// mais. Limpar e mais honesto que deixar uma escolha invalida na tela.
  void chooseService(Service service) =>
      state = state.copyWith(service: service, clearStartsAt: true);

  void chooseTime(DateTime startsAt) =>
      state = state.copyWith(startsAt: startsAt);
}

@riverpod
Stream<List<Service>> bookableServices(Ref ref) =>
    ref.watch(serviceRepositoryProvider).watchAll();

/// Os horarios em que o servico escolhido cabe no dia aberto na agenda.
@riverpod
Stream<List<DateTime>> bookableTimes(Ref ref) {
  final service = ref.watch(bookingProvider).service;
  if (service == null) return Stream.value(const []);

  final draft = ref.watch(bookingProvider);
  final day = draft.day;
  final hours = ref
      .watch(weekHoursProvider)
      .maybeWhen(
        data: (week) => week.on(day),
        orElse: () => WeekHours.closed().on(day),
      );

  final step = ref
      .watch(slotStepProvider)
      .maybeWhen(data: (value) => value, orElse: () => SlotRules.step);

  // Dia fechado por feriado ou medico nao oferece horario nenhum.
  final blocks = ref
      .watch(dayBlocksProvider(day))
      .maybeWhen(data: (list) => list, orElse: () => const <TimeBlock>[]);

  return ref.watch(agendaRepositoryProvider).watchDay(day).map((appointments) {
    // Ao remarcar, o proprio horario nao pode bloquear a si mesmo.
    final others = draft.editingId == null
        ? appointments
        : appointments.where((a) => a.id != draft.editingId).toList();

    return availableStarts(
      buildDaySchedule(day, others, hours: hours, blocks: blocks),
      service.duration,
      step: step,
      // Nao oferece horario que ja passou.
      notBefore: DateTime.now(),
    );
  });
}

/// Grava o horario. Devolve o nome de quem foi marcado, para a confirmacao.
@riverpod
Future<String> Function(BookingDraft) bookingSubmitter(Ref ref) {
  final agenda = ref.watch(agendaRepositoryProvider);
  final clients = ref.watch(clientRepositoryProvider);

  return (draft) async {
    const uuid = Uuid();
    final client = draft.client!;

    final clientId = switch (client) {
      ExistingClient(:final client) => client.id,
      NewClient(:final name, :final phone) => await () async {
        final id = uuid.v4();
        await clients.create(id: id, name: name, phone: phone);
        return id;
      }(),
    };

    if (draft.isEditing) {
      await agenda.reschedule(
        id: draft.editingId!,
        service: draft.service!,
        startsAt: draft.startsAt!,
      );
    } else {
      await agenda.create(
        id: uuid.v4(),
        clientId: clientId,
        service: draft.service!,
        startsAt: draft.startsAt!,
      );
    }

    return switch (client) {
      ExistingClient(:final client) => client.name,
      NewClient(:final name) => name.trim(),
    };
  };
}
