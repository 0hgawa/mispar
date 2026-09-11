import 'package:flutter/material.dart';
import 'package:marcos_barber/src/shared/widgets/app_card.dart';
import 'package:marcos_barber/src/shared/widgets/initials_avatar.dart';

/// A linha de um cliente: retrato, nome, uma linha de detalhe, e o que vier
/// à direita.
///
/// Duas listas mostram cliente — a aba de Clientes e a de quem sumiu. Elas
/// diferem só no que fica à direita e no que a segunda linha diz; o resto tem
/// que ser idêntico, e uma classe só é o que garante que continue sendo.
class ClientRow extends StatelessWidget {
  const new({
    required this.name,
    required this.detail,
    required this.trailing,
    required this.onTap,
    this.detailLines = 2,
    super.key,
  });

  final String name;
  final String detail;

  /// O que fica à direita: há quanto tempo veio, ou um botão.
  final Widget trailing;
  final VoidCallback onTap;

  /// Anotação de cliente pode ter duas linhas; um detalhe de uma linha só
  /// ficaria com o card alto à toa.
  final int detailLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name: name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: detailLines,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}
