import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:marcos_barber/src/core/data/database/app_database.dart';
import 'package:marcos_barber/src/features/agenda/domain/appointment_status.dart';

/// Popula o banco na primeira abertura.
///
/// O catalogo de servicos e real e vai para qualquer build. Clientes e
/// agendamentos de exemplo entram so em debug, para haver o que olhar enquanto
/// o app nao esta ligado no Supabase.
Future<void> seedDatabase(AppDatabase db) async {
  // O horario e conferido a parte: ele nasceu na v2 do banco, depois dos
  // servicos, entao quem ja tinha o app instalado nao passaria pelo seed.
  if (await db.managers.shopHours.count() == 0) await _seedHours(db);

  // A linha unica de ajustes nasceu na v10. O id vai escrito de proposito:
  // coluna integer que e chave primaria no SQLite e apelido do rowid, e omitir
  // o valor faz ele numerar sozinho em vez de usar o default.
  if (await db.managers.shopSettings.count() == 0) {
    await db
        .into(db.shopSettings)
        .insert(const ShopSettingsCompanion(id: Value(1)));
  }

  // Mesmo caso: os tipos de gasto nasceram na v5.
  if (await db.managers.expenseCategories.count() == 0) {
    await _seedExpenseCategories(db);
  }

  final alreadySeeded = await db.managers.services.count() > 0;
  if (alreadySeeded) return;

  await db.batch((batch) {
    batch.insertAll(db.services, const [
      ServicesCompanion(
        id: Value('pezinho'),
        name: Value('Pezinho'),
        durationMinutes: Value(15),
        priceCents: Value(1500),
      ),
      ServicesCompanion(
        id: Value('barba'),
        name: Value('Barba'),
        durationMinutes: Value(30),
        priceCents: Value(3000),
      ),
      ServicesCompanion(
        id: Value('corte'),
        name: Value('Corte'),
        durationMinutes: Value(30),
        priceCents: Value(4000),
      ),
      ServicesCompanion(
        id: Value('degrade'),
        name: Value('Degradê'),
        durationMinutes: Value(45),
        priceCents: Value(4500),
      ),
      ServicesCompanion(
        id: Value('corte-barba'),
        name: Value('Corte + Barba'),
        durationMinutes: Value(50),
        priceCents: Value(6000),
      ),
      ServicesCompanion(
        id: Value('platinado'),
        name: Value('Platinado'),
        durationMinutes: Value(90),
        priceCents: Value(12000),
        requiresDeposit: Value(true),
      ),
    ]);
  });

  if (kDebugMode) await _seedDemoDay(db);
}

/// Horario de funcionamento da Marcos Barber. Os mesmos valores do Postgres —
/// sexta fecha mais tarde, sabado abre mais cedo e nao para para almocar.
Future<void> _seedHours(AppDatabase db) async {
  const h = 60;
  await db.batch((batch) {
    batch.insertAll(db.shopHours, [
      for (var weekday = 1; weekday <= 4; weekday++)
        ShopHoursCompanion.insert(
          weekday: Value(weekday),
          opensMinutes: 9 * h,
          closesMinutes: 19 * h,
          lunchStartMinutes: const Value(12 * h + 10),
          lunchEndMinutes: const Value(13 * h + 30),
        ),
      ShopHoursCompanion.insert(
        weekday: const Value(DateTime.friday),
        opensMinutes: 9 * h,
        closesMinutes: 20 * h,
        lunchStartMinutes: const Value(12 * h + 10),
        lunchEndMinutes: const Value(13 * h + 30),
      ),
      ShopHoursCompanion.insert(
        weekday: const Value(DateTime.saturday),
        opensMinutes: 8 * h,
        closesMinutes: 18 * h,
      ),
      ShopHoursCompanion.insert(
        weekday: const Value(DateTime.sunday),
        isOpen: const Value(false),
        opensMinutes: 9 * h,
        closesMinutes: 19 * h,
      ),
    ]);
  });
}

Future<void> _seedDemoDay(AppDatabase db) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime at(int hour, int minute) =>
      today.add(Duration(hours: hour, minutes: minute));

  const demoClients = [
    (
      'rafael',
      'Rafael Lima',
      '11 98812-4471',
      'Máquina 2 nas laterais, tesoura em cima. Barba na navalha.',
    ),
    (
      'douglas',
      'Douglas Prates',
      '11 99640-2210',
      'Degradê baixo. Não gosta de risca.',
    ),
    ('ney', 'Ney Cardoso', '11 97733-8890', null),
    ('wesley', 'Wesley Tavares', '11 98155-3062', 'Barba toda quinta, 13h30.'),
    (
      'jonas',
      'Jonas Beiral',
      '11 99204-7718',
      'Já faltou duas vezes — cobrar sinal.',
    ),
    ('iuri', 'Iuri Mancuso', '11 98470-1195', null),
  ];

  await db.batch((batch) {
    batch
      ..insertAll(db.clients, [
        for (final (id, name, phone, note) in demoClients)
          ClientsCompanion.insert(
            id: id,
            name: name,
            phone: phone,
            note: Value(note),
            createdAt: today,
          ),
      ])
      ..insertAll(db.appointments, [
        _appt(
          'a1',
          'rafael',
          'corte-barba',
          at(9, 0),
          AppointmentStatus.done,
          50,
          6000,
        ),
        _appt(
          'a2',
          'douglas',
          'degrade',
          at(10, 0),
          AppointmentStatus.done,
          45,
          4500,
        ),
        _appt(
          'a3',
          'ney',
          'corte',
          at(11, 40),
          AppointmentStatus.awaiting,
          30,
          4000,
        ),
        _appt(
          'a4',
          'wesley',
          'barba',
          at(13, 30),
          AppointmentStatus.confirmed,
          30,
          3000,
        ),
        _appt(
          'a5',
          'jonas',
          'platinado',
          at(14, 30),
          AppointmentStatus.depositPaid,
          90,
          12000,
        ),
        _appt(
          'a6',
          'iuri',
          'pezinho',
          at(16, 30),
          AppointmentStatus.confirmed,
          15,
          1500,
        ),
      ]);
  });
}

AppointmentsCompanion _appt(
  String id,
  String clientId,
  String serviceId,
  DateTime startsAt,
  AppointmentStatus status,
  int durationMinutes,
  int priceCents,
) => AppointmentsCompanion.insert(
  id: id,
  durationMinutes: durationMinutes,
  priceCents: priceCents,
  clientId: Value(clientId),
  serviceId: serviceId,
  startsAt: startsAt,
  status: status.wireName,
);

/// Os tipos de gasto que qualquer barbearia tem. Sao ponto de partida: da
/// para renomear, aposentar e criar outros em Ajustes.
Future<void> _seedExpenseCategories(AppDatabase db) {
  return db.batch((batch) {
    batch.insertAll(db.expenseCategories, const [
      ExpenseCategoriesCompanion(
        id: Value('products'),
        name: Value('Produtos'),
      ),
      ExpenseCategoriesCompanion(id: Value('rent'), name: Value('Aluguel')),
      ExpenseCategoriesCompanion(
        id: Value('utilities'),
        name: Value('Água e luz'),
      ),
      ExpenseCategoriesCompanion(
        id: Value('card-fees'),
        name: Value('Maquininha'),
      ),
      ExpenseCategoriesCompanion(
        id: Value('marketing'),
        name: Value('Divulgação'),
      ),
      ExpenseCategoriesCompanion(
        id: Value('tools'),
        name: Value('Equipamento'),
      ),
      ExpenseCategoriesCompanion(id: Value('other'), name: Value('Outros')),
    ]);
  });
}
