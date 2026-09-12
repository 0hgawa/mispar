import 'package:mispar/src/features/agenda/domain/appointment.dart';
import 'package:mispar/src/features/agenda/domain/appointment_status.dart';

/// O que a Meta cobra por lembrete entregue no Brasil, em centavos.
///
/// É o preço de mensagem de utilidade, que é a categoria do lembrete, e está
/// **arredondado para cima**: a tabela da Meta é em dólar e muda com o câmbio.
/// Estimativa de gasto que erra tem que errar para cima — quem liga o
/// interruptor esperando pagar menos do que paga desliga com raiva.
///
/// Fica aqui como número, e não escondido dentro de um texto, porque é ele que
/// a tela mostra antes de o Marcos ligar o interruptor.
const reminderCostCents = 5;

/// O lembrete que sai sozinho antes do horário.
///
/// É a única mensagem do robô que custa. Conversa que o cliente começa é de
/// graça; falar com quem não escreveu antes exige modelo aprovado pela Meta e
/// tem preço por envio. Por isso ele nasce desligado, e por isso a tela mostra
/// quanto custaria antes de ligar.
class ReminderSettings {
  const new({required this.isOn, required this.hoursBefore});

  /// Enquanto o banco não respondeu: desligado, que é como ele nasce.
  const new off() : isOn = false, hoursBefore = 24;

  /// As antecedências que a tela oferece.
  ///
  /// Três, e não um campo aberto: 24h é o que a literatura de falta usa, 12h
  /// serve para quem marca de um dia para o outro, e 48h dá tempo de preencher
  /// o buraco se o cliente desmarcar.
  static const hourChoices = [12, 24, 48];

  final bool isOn;
  final int hoursBefore;
}

/// Quantos destes atendimentos gerariam lembrete.
///
/// A mesma regra da função `due_reminders` no Postgres, que é quem decide de
/// verdade na hora de mandar: só o que ainda vai acontecer, e só quem tem
/// cadastro — venda de balcão não tem para quem mandar.
int remindersFor(List<Appointment> appointments) {
  return appointments
      .where(
        (appointment) =>
            appointment.client != null &&
            appointment.status.stillStands &&
            appointment.status != AppointmentStatus.done,
      )
      .length;
}
