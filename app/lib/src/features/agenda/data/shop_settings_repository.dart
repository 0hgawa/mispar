import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mispar/src/core/data/database/app_database.dart';
import 'package:mispar/src/features/agenda/domain/payment_method.dart';
import 'package:mispar/src/features/agenda/domain/shop_hours.dart';
import 'package:mispar/src/features/settings/domain/accepted_payments.dart';
import 'package:mispar/src/features/settings/domain/drifted_rule.dart';
import 'package:mispar/src/features/settings/domain/reminder_settings.dart';
import 'package:mispar/src/features/settings/domain/shop_profile.dart';

/// O que se ajusta uma vez e vale para a barbearia inteira.
///
/// A tabela tem uma linha so, e o id dela **tem que ir escrito**. No SQLite,
/// uma coluna `integer` que e chave primaria vira apelido do rowid: omitir o
/// valor nao aplica o `default 1`, ele numera sozinho. Sem o id explicito,
/// cada gravacao criava uma linha nova em vez de atualizar a existente — e a
/// leitura, que espera uma linha so, parava de responder.
class ShopSettingsRepository {
  const new(this._db);

  final AppDatabase _db;

  /// O id da unica linha que esta tabela pode ter.
  static const _theRow = 1;

  /// De quanto em quanto tempo os horarios sao oferecidos.
  Stream<Duration> watchSlotStep() {
    final query = _db.select(_db.shopSettings)
      ..where((s) => s.id.equals(_theRow));

    return query.watchSingleOrNull().map(
      (row) =>
          row == null ? SlotRules.step : Duration(minutes: row.slotStepMinutes),
    );
  }

  Future<void> saveSlotStep(Duration step) {
    return _db
        .into(_db.shopSettings)
        .insertOnConflictUpdate(
          ShopSettingsCompanion.insert(
            id: const Value(_theRow),
            slotStepMinutes: Value(step.inMinutes),
          ),
        );
  }

  /// O lembrete que sai sozinho antes do horário.
  Stream<ReminderSettings> watchReminder() {
    final query = _db.select(_db.shopSettings)
      ..where((s) => s.id.equals(_theRow));

    return query.watchSingleOrNull().map(
      (row) => row == null
          ? const ReminderSettings.off()
          : ReminderSettings(
              isOn: row.reminderEnabled,
              hoursBefore: row.reminderHoursBefore,
            ),
    );
  }

  /// Grava só as duas colunas do lembrete: o que não está no companion o
  /// SQLite não toca, então isto nunca desfaz o passo dos horários.
  Future<void> saveReminder(ReminderSettings reminder) {
    return _db
        .into(_db.shopSettings)
        .insertOnConflictUpdate(
          ShopSettingsCompanion.insert(
            id: const Value(_theRow),
            reminderEnabled: Value(reminder.isOn),
            reminderHoursBefore: Value(reminder.hoursBefore),
          ),
        );
  }

  /// Quando um cliente conta como sumido.
  Stream<DriftedRule> watchDrifted() {
    final query = _db.select(_db.shopSettings)
      ..where((s) => s.id.equals(_theRow));

    return query.watchSingleOrNull().map(
      (row) => row == null
          ? const DriftedRule.unknown()
          : DriftedRule(isOn: row.driftedEnabled, days: row.driftedDays),
    );
  }

  /// As formas de pagamento que a barbearia aceita.
  Stream<List<PaymentMethod>> watchAcceptedPayments() {
    final query = _db.select(_db.shopSettings)
      ..where((s) => s.id.equals(_theRow));

    return query.watchSingleOrNull().map(
      (row) => AcceptedPayments.read(
        row?.acceptedPayments ?? AcceptedPayments.wireDefault,
      ),
    );
  }

  Future<void> saveAcceptedPayments(List<PaymentMethod> accepted) {
    return _db
        .into(_db.shopSettings)
        .insertOnConflictUpdate(
          ShopSettingsCompanion.insert(
            id: const Value(_theRow),
            acceptedPayments: Value(AcceptedPayments.write(accepted)),
          ),
        );
  }

  /// O cadastro da barbearia.
  Stream<ShopProfile> watchProfile() {
    final query = _db.select(_db.shopSettings)
      ..where((s) => s.id.equals(_theRow));

    return query.watchSingleOrNull().map(
      (row) => row == null
          ? const ShopProfile.unknown()
          : ShopProfile(
              name: row.shopName,
              address: row.shopAddress,
              instagram: row.shopInstagram,
            ),
    );
  }

  Future<void> saveProfile(ShopProfile shop) {
    return _db
        .into(_db.shopSettings)
        .insertOnConflictUpdate(
          ShopSettingsCompanion.insert(
            id: const Value(_theRow),
            shopName: Value(shop.name),
            shopAddress: Value(shop.address),
            shopInstagram: Value(shop.instagram),
          ),
        );
  }

  Future<void> saveDrifted(DriftedRule rule) {
    return _db
        .into(_db.shopSettings)
        .insertOnConflictUpdate(
          ShopSettingsCompanion.insert(
            id: const Value(_theRow),
            driftedEnabled: Value(rule.isOn),
            driftedDays: Value(rule.days),
          ),
        );
  }
}

final shopSettingsRepositoryProvider = Provider<ShopSettingsRepository>(
  (ref) => ShopSettingsRepository(ref.watch(appDatabaseProvider)),
);

/// O passo em uso. Cai no padrao enquanto o banco nao respondeu — a tela de
/// marcar nao pode ficar em branco esperando um numero.
final slotStepProvider = StreamProvider<Duration>((ref) {
  return ref.watch(shopSettingsRepositoryProvider).watchSlotStep();
});

/// Como está o lembrete. Desligado enquanto o banco não respondeu — mostrar
/// "ligado" por um instante seria mentir sobre uma coisa que cobra.
final reminderSettingsProvider = StreamProvider<ReminderSettings>((ref) {
  return ref.watch(shopSettingsRepositoryProvider).watchReminder();
});

/// Quando um cliente conta como sumido. Calado enquanto o banco não respondeu
/// — quem desligou o aviso não pode vê-lo piscar a cada abertura.
final driftedRuleProvider = StreamProvider<DriftedRule>((ref) {
  return ref.watch(shopSettingsRepositoryProvider).watchDrifted();
});

/// O que a barbearia aceita receber. As três enquanto o banco não respondeu:
/// é o valor de fábrica, e esconder uma forma que existe é pior que mostrar
/// uma que já foi desligada por meio segundo.
final acceptedPaymentsProvider = StreamProvider<List<PaymentMethod>>((ref) {
  return ref.watch(shopSettingsRepositoryProvider).watchAcceptedPayments();
});

/// Como a barbearia se chama, onde fica, e o @ dela. Quem lê: o cartaz de
/// divulgar horário e a tela de cadastro.
final shopProfileProvider = StreamProvider<ShopProfile>((ref) {
  return ref.watch(shopSettingsRepositoryProvider).watchProfile();
});
