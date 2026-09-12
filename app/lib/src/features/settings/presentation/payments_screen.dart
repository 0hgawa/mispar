import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/data/shop_settings_repository.dart';
import 'package:marcos_barber/src/features/agenda/domain/payment_method.dart';
import 'package:marcos_barber/src/shared/widgets/app_snack.dart';
import 'package:marcos_barber/src/shared/widgets/page_bar.dart';

/// O que a barbearia aceita receber.
///
/// Nem toda barbearia tem maquininha, e ver "Cartão" na hora de fechar o
/// atendimento é uma opção a mais para errar o toque — todo dia, para sempre.
/// Desligada, ela some da folha do horário e do lançamento de receita.
///
/// O que já foi recebido não se apaga: desligar o Cartão hoje não muda o mês
/// passado, e o extrato continua mostrando o que foi.
class PaymentsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accepted =
        ref.watch(acceptedPaymentsProvider).value ?? PaymentMethod.values;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const PageBar(title: 'Pagamento'),
          const SliverToBoxAdapter(
            child: PageSubtitle('o que a barbearia aceita receber'),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
            sliver: SliverList.list(
              children: [
                for (final method in PaymentMethod.values)
                  _Toggle(
                    method: method,
                    accepted: accepted,
                    onChanged: (isOn) => _save(context, ref, [
                      for (final other in PaymentMethod.values)
                        if (other == method ? isOn : accepted.contains(other))
                          other,
                    ]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const new({
    required this.method,
    required this.accepted,
    required this.onChanged,
  });

  final PaymentMethod method;
  final List<PaymentMethod> accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOn = accepted.contains(method);
    // A última não se desliga: sem nenhuma forma, não haveria como fechar um
    // atendimento. Trancar o interruptor diz isso melhor que um aviso depois.
    final isLast = isOn && accepted.length == 1;

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Dimens.screenGutter,
        vertical: 4,
      ),
      value: isOn,
      onChanged: isLast ? null : onChanged,
      title: Text(
        method.label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: isLast
          ? Text(
              'A última não se desliga — é preciso ter como receber',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
    );
  }
}

/// Grava e **mostra** quando não consegue: um ajuste que não muda de estado em
/// silêncio faz o Marcos tocar no mesmo botão sem entender.
Future<void> _save(
  BuildContext context,
  WidgetRef ref,
  List<PaymentMethod> accepted,
) async {
  try {
    await ref
        .read(shopSettingsRepositoryProvider)
        .saveAcceptedPayments(accepted);
  } on Object {
    if (!context.mounted) return;
    showSnack(context, 'Não consegui salvar.');
  }
}
